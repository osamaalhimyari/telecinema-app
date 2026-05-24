import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/entities/create_room_params.dart';
import '../../../domain/entities/room_type.dart';
import '../../../domain/usecases/create_room_usecase.dart';
import '../../../domain/usecases/download_progress_usecase.dart';
import 'create_room_state.dart';

/// Drives the create-room form across all three source types. For the download
/// flow it polls the server job until the room exists, mirroring the website's
/// progress poll.
class CreateRoomCubit extends Cubit<CreateRoomState> {
  CreateRoomCubit(this._createRoom, this._downloadProgress) : super(const CreateRoomState());

  final CreateRoomUseCase _createRoom;
  final DownloadProgressUseCase _downloadProgress;

  Timer? _pollTimer;

  Future<void> submit(CreateRoomParams params) async {
    if (state.isBusy) return;

    emit(
      state.copyWith(
        status: params.type == RoomType.upload
            ? CreateRoomStatus.uploading
            : CreateRoomStatus.submitting,
        uploadProgress: 0,
        clearError: true,
        clearDownloadPercent: true,
      ),
    );

    _createRoom.onUploadProgress = (sent, total) {
      if (total > 0) emit(state.copyWith(uploadProgress: sent / total));
    };

    final result = await _createRoom(params);
    result.fold(
      (failure) => emit(
        state.copyWith(status: CreateRoomStatus.failure, errorKey: failure.message),
      ),
      (created) {
        if (created.room != null) {
          emit(state.copyWith(status: CreateRoomStatus.success, createdSlug: created.room!.slug));
        } else if (created.jobId != null) {
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
    emit(const CreateRoomState());
  }

  @override
  Future<void> close() {
    _pollTimer?.cancel();
    return super.close();
  }
}
