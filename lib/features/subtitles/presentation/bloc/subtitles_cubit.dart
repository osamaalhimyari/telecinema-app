import 'package:flutter_bloc/flutter_bloc.dart';

import '/features/rooms/domain/usecases/upload_subtitle_usecase.dart';
import '../../data/datasources/opensubtitles_datasource.dart'
    show subtitleSearchTerms, magnetDisplayName;
import '../../domain/entities/subtitle_result.dart';
import '../../domain/usecases/download_subtitle_usecase.dart';
import '../../domain/usecases/search_subtitles_usecase.dart';
import 'subtitles_state.dart';

/// Drives the "Download subtitle" page: searches OpenSubtitles for the room's
/// title in the chosen language, then — when a result is tapped — downloads it
/// and reuses the room's existing subtitle upload so it broadcasts to everyone.
class SubtitlesCubit extends Cubit<SubtitlesState> {
  SubtitlesCubit(this._search, this._download, this._upload) : super(const SubtitlesState());

  final SearchSubtitlesUseCase _search;
  final DownloadSubtitleUseCase _download;
  final UploadSubtitleUseCase _upload;

  late String _slug;
  String? _imdbId;
  String? _query;
  int? _season;
  int? _episode;

  /// Binds the page's room context and runs the first search. [imdbId] is
  /// preferred; otherwise the search term is parsed from the richest name
  /// available — the resolved [release] file name, else the [magnet]'s display
  /// name, else the room [title] — so a TV search targets the exact episode.
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
    final terms = subtitleSearchTerms(source);
    _query = terms.query.isNotEmpty ? terms.query : title;
    _season = terms.season;
    _episode = terms.episode;
    emit(state.copyWith(langId: langId));
    search();
  }

  Future<void> selectLanguage(String langId) async {
    if (langId == state.langId && state.status == SubtitlesStatus.loading) return;
    emit(state.copyWith(langId: langId));
    await search();
  }

  /// Re-search after the user edits the title (fallback path for rooms with no
  /// IMDB id). Re-parses any `SxxExx` the user typed so e.g. "Breaking Bad
  /// S01E07" targets the episode. No-op for empty input.
  Future<void> searchByTitle(String title) async {
    final raw = title.trim();
    if (raw.isEmpty) return;
    final terms = subtitleSearchTerms(raw);
    _query = terms.query.isNotEmpty ? terms.query : raw;
    _season = terms.season;
    _episode = terms.episode;
    // An explicit title search wins over any IMDB id (the datasource prefers an
    // id when present), so drop it — otherwise the typed title would be ignored.
    _imdbId = null;
    await search();
  }

  /// Re-search by a manually-entered IMDB id — for rooms created from an
  /// outside torrent/link that carry no id, where a precise id beats a fuzzy
  /// title match. Accepts `tt1190634`, bare digits, or an IMDB URL (the
  /// datasource extracts the digits). An empty value clears it and falls back
  /// to the title query.
  Future<void> searchByImdb(String imdbId) async {
    final raw = imdbId.trim();
    _imdbId = raw.isEmpty ? null : raw;
    await search();
  }

  Future<void> search() async {
    emit(state.copyWith(status: SubtitlesStatus.loading, results: const [], clearError: true));
    final res = await _search(
      SearchSubtitlesParams(
        imdbId: _imdbId,
        query: _query,
        season: _season,
        episode: _episode,
        langId: state.langId,
      ),
    );
    res.fold(
      (f) => emit(state.copyWith(status: SubtitlesStatus.failure, errorKey: f.message)),
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
