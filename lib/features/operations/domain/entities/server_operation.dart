import 'package:equatable/equatable.dart';

/// Lifecycle of a transfer. `downloading` is the only non-terminal state and
/// covers uploads too (the server's job model has no separate "uploading").
enum OperationStatus { downloading, done, error }

/// Which kind of server transfer an operation represents — drives the icon and
/// label in the operations panel.
enum OperationKind { download, magnetDownload, torrent, upload }

/// One server transfer the user can watch and cancel: a link/magnet download or
/// torrent room being created on the server, or a video upload originating from
/// this app. Server operations come from `GET /api/operations` (keyed by the
/// device id); upload operations are tracked locally in the cubit while in
/// flight ([isLocal] = true) and are cancelled via their Dio request, not the
/// server.
class ServerOperation extends Equatable {
  const ServerOperation({
    required this.id,
    required this.kind,
    required this.name,
    required this.status,
    this.percent,
    this.bytesDownloaded = 0,
    this.totalBytes,
    this.error,
    this.slug,
    this.isLocal = false,
  });

  final String id;
  final OperationKind kind;
  final String name;
  final OperationStatus status;

  /// 0–100 when known, else null (chunked/metadata transfers).
  final int? percent;
  final int bytesDownloaded;
  final int? totalBytes;

  /// Translation key or message when [status] is error.
  final String? error;

  /// Set once a download/torrent finishes — the created room's slug.
  final String? slug;

  /// True for an in-app upload tracked locally (cancel via its Dio request).
  final bool isLocal;

  bool get isActive => status == OperationStatus.downloading;

  /// Fraction 0..1 when a percent is known, else null (drives the progress bar).
  double? get fraction => percent == null ? null : (percent! / 100).clamp(0, 1);

  ServerOperation copyWith({
    OperationStatus? status,
    int? percent,
    int? bytesDownloaded,
    int? totalBytes,
    String? error,
    String? slug,
  }) {
    return ServerOperation(
      id: id,
      kind: kind,
      name: name,
      status: status ?? this.status,
      percent: percent ?? this.percent,
      bytesDownloaded: bytesDownloaded ?? this.bytesDownloaded,
      totalBytes: totalBytes ?? this.totalBytes,
      error: error ?? this.error,
      slug: slug ?? this.slug,
      isLocal: isLocal,
    );
  }

  static OperationStatus statusFrom(String? raw) => switch (raw) {
    'done' => OperationStatus.done,
    'error' => OperationStatus.error,
    _ => OperationStatus.downloading,
  };

  static OperationKind kindFrom(String? raw) => switch (raw) {
    'torrent' => OperationKind.torrent,
    'magnet-download' => OperationKind.magnetDownload,
    'upload' => OperationKind.upload,
    _ => OperationKind.download,
  };

  factory ServerOperation.fromJson(Map<String, dynamic> m) {
    return ServerOperation(
      id: m['id'].toString(),
      kind: kindFrom(m['kind']?.toString()),
      name: (m['name'] ?? '').toString(),
      status: statusFrom(m['status']?.toString()),
      percent: m['percent'] is num ? (m['percent'] as num).toInt() : null,
      bytesDownloaded: m['bytesDownloaded'] is num ? (m['bytesDownloaded'] as num).toInt() : 0,
      totalBytes: m['totalBytes'] is num ? (m['totalBytes'] as num).toInt() : null,
      error: m['error']?.toString(),
      slug: m['slug']?.toString(),
    );
  }

  @override
  List<Object?> get props =>
      [id, kind, name, status, percent, bytesDownloaded, totalBytes, error, slug, isLocal];
}
