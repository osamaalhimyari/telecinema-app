import 'package:equatable/equatable.dart';

enum DownloadStatus { downloading, done, error }

/// Progress of a server-side "create a room from a link" job, polled from
/// `GET /api/rooms/download/:jobId`.
class DownloadProgress extends Equatable {
  const DownloadProgress({
    required this.status,
    this.percent,
    this.bytesDownloaded = 0,
    this.totalBytes,
    this.error,
    this.slug,
  });

  final DownloadStatus status;

  /// 0–100 once the total size is known; null for chunked responses.
  final int? percent;
  final int bytesDownloaded;
  final int? totalBytes;
  final String? error;

  /// Slug of the finished room — only set when [status] is [DownloadStatus.done].
  final String? slug;

  bool get isDone => status == DownloadStatus.done;
  bool get isError => status == DownloadStatus.error;

  static DownloadStatus statusFromString(String? value) => switch (value) {
    'done' => DownloadStatus.done,
    'error' => DownloadStatus.error,
    _ => DownloadStatus.downloading,
  };

  @override
  List<Object?> get props => [status, percent, bytesDownloaded, totalBytes, error, slug];
}
