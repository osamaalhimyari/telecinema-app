import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/usecases/find_torrents_usecase.dart';
import '../../../domain/usecases/get_meta_detail_usecase.dart';
import 'detail_state.dart';

/// Loads a title's full metadata and, in parallel, hunts for torrents. The two
/// run independently so the page can render immediately while the (slower)
/// torrent lookup resolves the source picker.
class DetailCubit extends Cubit<DetailState> {
  DetailCubit(this._getDetail, this._findTorrents) : super(const DetailState());

  final GetMetaDetailUseCase _getDetail;
  final FindTorrentsUseCase _findTorrents;

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
}
