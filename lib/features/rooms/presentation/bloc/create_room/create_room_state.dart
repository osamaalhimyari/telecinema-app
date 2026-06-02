import 'package:equatable/equatable.dart';

enum CreateRoomStatus { idle, submitting, uploading, downloading, success, failure }

class CreateRoomState extends Equatable {
  const CreateRoomState({
    this.status = CreateRoomStatus.idle,
    this.uploadProgress = 0,
    this.downloadPercent,
    this.createdSlug,
    this.errorKey,
  });

  final CreateRoomStatus status;

  /// 0..1 during a multipart upload.
  final double uploadProgress;

  /// 0..100 during a server-side download, or null when total size is unknown.
  final int? downloadPercent;

  /// Slug of the finished room — set when [status] is success.
  final String? createdSlug;
  final String? errorKey;

  bool get isBusy =>
      status == CreateRoomStatus.submitting ||
      status == CreateRoomStatus.uploading ||
      status == CreateRoomStatus.downloading;

  CreateRoomState copyWith({
    CreateRoomStatus? status,
    double? uploadProgress,
    int? downloadPercent,
    String? createdSlug,
    String? errorKey,
    bool clearError = false,
    bool clearDownloadPercent = false,
  }) {
    return CreateRoomState(
      status: status ?? this.status,
      uploadProgress: uploadProgress ?? this.uploadProgress,
      downloadPercent: clearDownloadPercent ? null : (downloadPercent ?? this.downloadPercent),
      createdSlug: createdSlug ?? this.createdSlug,
      errorKey: clearError ? null : (errorKey ?? this.errorKey),
    );
  }

  @override
  List<Object?> get props => [status, uploadProgress, downloadPercent, createdSlug, errorKey];
}
