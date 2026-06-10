import 'package:flutter_bloc/flutter_bloc.dart';

import '/features/browse/data/torrent_classifier.dart' show parseSeasonEpisode;
import '/features/rooms/domain/usecases/upload_subtitle_usecase.dart';
import '../../data/datasources/opensubtitles_datasource.dart' show magnetDisplayName;
import '../../domain/entities/subtitle_result.dart';
import '../../domain/usecases/download_subtitle_usecase.dart';
import '../../domain/usecases/search_subtitles_usecase.dart';
import 'subtitles_state.dart';

/// Drives the "Download subtitle" page: searches OpenSubtitles by the room's
/// IMDB id (plus season/episode for TV) in the chosen language, then — when a
/// result is tapped — downloads it and reuses the room's existing subtitle
/// upload so it broadcasts to everyone.
class SubtitlesCubit extends Cubit<SubtitlesState> {
  SubtitlesCubit(this._search, this._download, this._upload) : super(const SubtitlesState());

  final SearchSubtitlesUseCase _search;
  final DownloadSubtitleUseCase _download;
  final UploadSubtitleUseCase _upload;

  late String _slug;
  String? _imdbId;

  /// Binds the page's room context and runs the first search. The search is by
  /// [imdbId]; any season/episode is seeded from the richest name available —
  /// the resolved [release] file name, else the [magnet]'s display name, else
  /// the room [title] — so a TV search targets the exact episode. The user can
  /// override the id, season, and episode from the page.
  void init({
    required String slug,
    String? imdbId,
    String? title,
    String? release,
    String? magnet,
    required String langId,
  }) {
    _slug = slug;
    _imdbId = imdbId;
    // Prefer the resolved file name (richest), fall back to the magnet's `dn=`
    // name (works for a just-pasted magnet, before the file is named), then the
    // room title (e.g. embed rooms with no file or magnet).
    final release0 = release?.trim() ?? '';
    final source = release0.isNotEmpty
        ? release0
        : (magnetDisplayName(magnet) ?? (title ?? ''));
    final se = parseSeasonEpisode(source);
    emit(state.copyWith(langId: langId, season: se.season, episode: se.episode));
    search();
  }

  Future<void> selectLanguage(String langId) async {
    if (langId == state.langId && state.status == SubtitlesStatus.loading) return;
    emit(state.copyWith(langId: langId));
    await search();
  }

  /// Re-search by a manually-entered IMDB id. Accepts `tt1190634`, bare digits,
  /// or an IMDB URL (the datasource extracts the digits). An empty value clears
  /// it (nothing to search on).
  Future<void> searchByImdb(String imdbId) async {
    final raw = imdbId.trim();
    _imdbId = raw.isEmpty ? null : raw;
    await search();
  }

  /// Re-search after the user edits the season. An empty/non-numeric value
  /// clears it (search the whole title).
  Future<void> searchBySeason(String season) async {
    final n = int.tryParse(season.trim());
    emit(n == null ? state.copyWith(clearSeason: true) : state.copyWith(season: n));
    await search();
  }

  /// Re-search after the user edits the episode. An empty/non-numeric value
  /// clears it.
  Future<void> searchByEpisode(String episode) async {
    final n = int.tryParse(episode.trim());
    emit(n == null ? state.copyWith(clearEpisode: true) : state.copyWith(episode: n));
    await search();
  }

  Future<void> search() async {
    emit(state.copyWith(status: SubtitlesStatus.loading, results: const [], clearError: true));
    final res = await _search(
      SearchSubtitlesParams(
        imdbId: _imdbId,
        season: state.season,
        episode: state.episode,
        langId: state.langId,
      ),
    );
    res.fold(
      (f) => emit(state.copyWith(
        status: SubtitlesStatus.failure,
        errorKey: f.message,
        errorDetail: f.detail,
      )),
      (list) => emit(state.copyWith(status: SubtitlesStatus.success, results: list)),
    );
  }

  /// Downloads [result] and uploads it to the room. On success [appliedOk]
  /// flips true so the page pops back to the video.
  Future<void> apply(SubtitleResult result) async {
    if (state.isApplying) return;
    emit(state.copyWith(applyingId: result.id, clearError: true));

    final dl = await _download(result);
    await dl.fold(
      (f) async => emit(state.copyWith(clearApplying: true, errorKey: f.message)),
      (path) async {
        final up = await _upload(UploadSubtitleParams(slug: _slug, filePath: path));
        up.fold(
          (f) => emit(state.copyWith(clearApplying: true, errorKey: f.message)),
          (_) => emit(state.copyWith(clearApplying: true, appliedOk: true)),
        );
      },
    );
  }
}
