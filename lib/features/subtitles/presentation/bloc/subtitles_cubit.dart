import 'package:flutter_bloc/flutter_bloc.dart';

import '/features/rooms/domain/usecases/upload_subtitle_usecase.dart';
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

  /// Binds the page's room context and runs the first search. [imdbId] is
  /// preferred; [title] is the free-text fallback for rooms without one.
  void init({
    required String slug,
    String? imdbId,
    String? title,
    required String langId,
  }) {
    _slug = slug;
    _imdbId = imdbId;
    _query = title;
    emit(state.copyWith(langId: langId));
    search();
  }

  Future<void> selectLanguage(String langId) async {
    if (langId == state.langId && state.status == SubtitlesStatus.loading) return;
    emit(state.copyWith(langId: langId));
    await search();
  }

  /// Re-search after the user edits the title (fallback path for rooms with no
  /// IMDB id). No-op for empty input.
  Future<void> searchByTitle(String title) async {
    final q = title.trim();
    if (q.isEmpty) return;
    _query = q;
    await search();
  }

  Future<void> search() async {
    emit(state.copyWith(status: SubtitlesStatus.loading, results: const [], clearError: true));
    final res = await _search(
      SearchSubtitlesParams(imdbId: _imdbId, query: _query, langId: state.langId),
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
