import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '/features/cache/data/cache_manager.dart';
import '/features/operations/presentation/bloc/operations_cubit.dart';
import '../../../domain/entities/create_room_params.dart';
import '../../../domain/entities/room_type.dart';
import '../../../domain/usecases/create_room_usecase.dart';
import '../../../domain/usecases/download_progress_usecase.dart';
import 'create_room_state.dart';

/// Drives the create-room form across all source types. For the download flow it
/// polls the server job until the room exists, mirroring the website's progress
/// poll. A server transfer (upload, or a local room that also uploads) is
/// mirrored into the [OperationsCubit] so it shows in the global operations panel
/// and can be cancelled from there. For `upload` and `local` rooms the creator's
/// picked file is also copied into the on-device [CacheManager] so they play
/// from disk immediately (and, for a local room, so they don't hit their own
/// "provide file" gate).
class CreateRoomCubit extends Cubit<CreateRoomState> {
  CreateRoomCubit(
    this._createRoom,
    this._downloadProgress,
    this._operations,
    this._cache,
  ) : super(const CreateRoomState());

  final CreateRoomUseCase _createRoom;
  final DownloadProgressUseCase _downloadProgress;
  final OperationsCubit _operations;
  final CacheManager _cache;

  Timer? _pollTimer;

  Future<void> submit(CreateRoomParams params) async {
    if (state.isBusy) return;

    // A real file goes to the server for an upload room, or for a local room
    // whose creator opted to also upload it. A plain local room does no server
    // transfer — its "uploading" phase is just the on-device cache copy.
    final hasServerTransfer =
        params.type == RoomType.upload ||
        (params.type == RoomType.local && params.uploadToServer);
    final isLocal = params.type == RoomType.local;

    emit(
      state.copyWith(
        status: (hasServerTransfer || isLocal)
            ? CreateRoomStatus.uploading
            : CreateRoomStatus.submitting,
        uploadProgress: 0,
        clearError: true,
        clearDownloadPercent: true,
      ),
    );

    // A server transfer is registered in the operations panel (with a cancel
    // token) so it's visible and abortable alongside downloads.
    String? opId;
    if (hasServerTransfer) {
      opId = 'upload_${DateTime.now().microsecondsSinceEpoch}';
      _createRoom.cancelToken = _operations.beginUpload(opId, params.name);
    } else {
      // No server transfer: clear any token left from a prior upload attempt so
      // it can't be handed to an unrelated request.
      _createRoom.cancelToken = null;
    }

    _createRoom.onUploadProgress = (sent, total) {
      if (total > 0) emit(state.copyWith(uploadProgress: sent / total));
      if (opId != null) _operations.updateUpload(opId, sent, total);
    };

    final result = await _createRoom(params);
    final created = result.fold<CreateRoomResult?>(
      (failure) {
        if (opId != null) _operations.failUpload(opId, failure.message);
        emit(
          state.copyWith(status: CreateRoomStatus.failure, errorKey: failure.message),
        );
        return null;
      },
      (c) => c,
    );
    if (created == null) return;

    if (created.room != null) {
      final slug = created.room!.slug;
      await _cacheLocalCopy(params, slug);
      if (opId != null) _operations.finishUpload(opId, slug: slug);
      emit(state.copyWith(status: CreateRoomStatus.success, createdSlug: slug));
    } else if (created.jobId != null) {
      // A server-side download/torrent just started — wake the operations panel
      // so it lists (and can cancel) this device's new transfer.
      _operations.refresh();
      _pollDownload(created.jobId!);
    }
  }

  /// Copies the creator's picked file into the on-device cache so they play from
  /// disk right away. For a `local` room the copy MUST complete before entering
  /// (else the creator would hit their own provide-file gate), so it's awaited
  /// with a progress bar; for an `upload` room it's best-effort and never blocks
  /// navigation.
  Future<void> _cacheLocalCopy(CreateRoomParams params, String slug) async {
    final path = params.localVideoPath;
    if (path == null) return;
    if (params.type == RoomType.local) {
      emit(state.copyWith(status: CreateRoomStatus.uploading, uploadProgress: 0));
      await _cache.importLocalFile(
        slug,
        path,
        title: params.name,
        onProgress: (copied, total) {
          if (total > 0) emit(state.copyWith(uploadProgress: copied / total));
        },
      );
    } else if (params.type == RoomType.upload) {
      unawaited(_cache.importLocalFile(slug, path, title: params.name));
    }
  }

  void _pollDownload(String jobId) {
    emit(state.copyWith(status: CreateRoomStatus.downloading));
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      final result = await _downloadProgress(jobId);
      result.fold(
        (failure) {
          _pollTimer?.cancel();
          emit(state.copyWith(status: CreateRoomStatus.failure, errorKey: failure.message));
        },
        (progress) {
          if (progress.isDone && progress.slug != null) {
            _pollTimer?.cancel();
            emit(
              state.copyWith(status: CreateRoomStatus.success, createdSlug: progress.slug),
            );
          } else if (progress.isError) {
            _pollTimer?.cancel();
            emit(
              state.copyWith(
                status: CreateRoomStatus.failure,
                errorKey: progress.error ?? 'error_unknown',
              ),
            );
          } else {
            emit(
              state.copyWith(
                status: CreateRoomStatus.downloading,
                downloadPercent: progress.percent,
              ),
            );
          }
        },
      );
    });
  }

  /// Resets after a handled error so the form is editable again.
  void reset() {
    _pollTimer?.cancel();
    _createRoom.cancelToken = null;
    emit(const CreateRoomState());
  }

  @override
  Future<void> close() {
    _pollTimer?.cancel();
    return super.close();
  }
}
