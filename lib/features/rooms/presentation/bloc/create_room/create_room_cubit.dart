import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '/features/operations/presentation/bloc/operations_cubit.dart';
import '../../../domain/entities/create_room_params.dart';
import '../../../domain/entities/room_type.dart';
import '../../../domain/usecases/create_room_usecase.dart';
import '../../../domain/usecases/download_progress_usecase.dart';
import 'create_room_state.dart';

/// Drives the create-room form across all three source types. For the download
/// flow it polls the server job until the room exists, mirroring the website's
/// progress poll. An upload is also mirrored into the [OperationsCubit] so it
/// shows in the global operations panel and can be cancelled from there.
class CreateRoomCubit extends Cubit<CreateRoomState> {
  CreateRoomCubit(this._createRoom, this._downloadProgress, this._operations)
    : super(const CreateRoomState());

  final CreateRoomUseCase _createRoom;
  final DownloadProgressUseCase _downloadProgress;
  final OperationsCubit _operations;

  Timer? _pollTimer;

  Future<void> submit(CreateRoomParams params) async {
    if (state.isBusy) return;

    final isUpload = params.type == RoomType.upload;

    emit(
      state.copyWith(
        status: isUpload ? CreateRoomStatus.uploading : CreateRoomStatus.submitting,
        uploadProgress: 0,
        clearError: true,
        clearDownloadPercent: true,
      ),
    );

    // An upload is a server transfer too — register it in the operations panel
    // (with a cancel token) so it's visible and abortable alongside downloads.
    String? opId;
    if (isUpload) {
      opId = 'upload_${DateTime.now().microsecondsSinceEpoch}';
      _createRoom.cancelToken = _operations.beginUpload(opId, params.name);
    } else {
      // Non-upload submit: clear any token left from a prior upload attempt so it
      // can't be handed to an unrelated request.
      _createRoom.cancelToken = null;
    }

    _createRoom.onUploadProgress = (sent, total) {
      if (total > 0) emit(state.copyWith(uploadProgress: sent / total));
      if (opId != null) _operations.updateUpload(opId, sent, total);
    };

    final result = await _createRoom(params);
    result.fold(
      (failure) {
        if (opId != null) _operations.failUpload(opId, failure.message);
        emit(state.copyWith(status: CreateRoomStatus.failure, errorKey: failure.message));
      },
      (created) {
        if (created.room != null) {
          if (opId != null) _operations.finishUpload(opId, slug: created.room!.slug);
          emit(state.copyWith(status: CreateRoomStatus.success, createdSlug: created.room!.slug));
        } else if (created.jobId != null) {
          // A server-side download/torrent just started — wake the operations
          // panel so it lists (and can cancel) this device's new transfer.
          _operations.refresh();
          _pollDownload(created.jobId!);
        }
      },
    );
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
