import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/entities/torrent_option.dart';
import '../../../domain/usecases/find_torrents_usecase.dart';
import '../../../domain/usecases/get_meta_detail_usecase.dart';
import '../../../domain/usecases/search_torrents_usecase.dart';
import 'detail_state.dart';

/// Loads a title's full metadata and, in parallel, hunts for torrents. The two
/// run independently so the page can render immediately while the (slower)
/// torrent lookup resolves the source picker.
class DetailCubit extends Cubit<DetailState> {
  DetailCubit(this._getDetail, this._findTorrents, this._searchTorrents)
      : super(const DetailState());

  final GetMetaDetailUseCase _getDetail;
  final FindTorrentsUseCase _findTorrents;
  final SearchTorrentsUseCase _searchTorrents;

  Future<void> load({
    required String type,
    required String id,
    required String title,
  }) async {
    emit(DetailState(type: type));

    // Fire both before awaiting either, so they overlap.
    final detailFuture = _getDetail(DetailParams(type: type, id: id));
    final torrentFuture = _findTorrents(FindTorrentsParams(imdbId: id, title: title));

    final detailRes = await detailFuture;
    detailRes.fold(
      (failure) => emit(state.copyWith(status: DetailStatus.failure, errorKey: failure.message)),
      (detail) => emit(state.copyWith(status: DetailStatus.success, detail: detail)),
    );

    final torrentRes = await torrentFuture;
    torrentRes.fold(
      (_) => emit(state.copyWith(torrentStatus: TorrentStatus.failure)),
      (torrents) => emit(
        torrents.isEmpty
            ? state.copyWith(torrentStatus: TorrentStatus.notFound)
            : state.copyWith(torrentStatus: TorrentStatus.found, torrents: torrents),
      ),
    );
  }

  /// Finds the best torrent for a single episode. Prefers a matching `SxxExx`
  /// already in the bulk IMDB-id results; otherwise runs a targeted apibay
  /// search (`<series> SxxExx`) — this is how episodes from seasons that only
  /// exist as packs still resolve to an individual file. Null when none exists.
  Future<TorrentOption?> resolveEpisode({
    required String seriesName,
    required int season,
    required int episode,
  }) async {
    final fromBulk = _bestEpisode(state.torrents, season, episode);
    if (fromBulk != null) return fromBulk;

    final query = '$seriesName S${_pad(season)}E${_pad(episode)}';
    final res = await _searchTorrents(SearchTorrentsParams(query: query));
    return res.fold((_) => null, (list) => _bestEpisode(list, season, episode));
  }

  /// Most-seeded torrent in [list] that is exactly this episode (ignores packs
  /// and other episodes that a free-text search might return).
  TorrentOption? _bestEpisode(List<TorrentOption> list, int season, int episode) {
    final matches = list
        .where((t) => t.episode == episode && t.season == season)
        .toList()
      ..sort((a, b) => b.seeders.compareTo(a.seeders));
    return matches.isEmpty ? null : matches.first;
  }

  static String _pad(int n) => n.toString().padLeft(2, '0');
}
