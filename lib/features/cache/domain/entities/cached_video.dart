import 'package:equatable/equatable.dart';

/// Lifecycle of an on-device cached video.
enum CacheStatus { queued, downloading, paused, done, error }

CacheStatus _statusFrom(String? v) => switch (v) {
  'downloading' => CacheStatus.downloading,
  'paused' => CacheStatus.paused,
  'done' => CacheStatus.done,
  'error' => CacheStatus.error,
  _ => CacheStatus.queued,
};

/// One entry in the on-device cache: a room's video pulled to local storage so
/// it plays from disk with no buffering, while the room's sync/chat/reactions
/// keep flowing over the socket exactly as for a streamed source.
///
/// Serialized into `cache/index.json`; the large media file lives beside it.
class CachedVideo extends Equatable {
  const CachedVideo({
    required this.key,
    required this.slug,
    required this.title,
    required this.sourceUrl,
    required this.status,
    this.localPath,
    this.subtitleUrl,
    this.subtitlePath,
    this.totalBytes = 0,
    this.downloadedBytes = 0,
    this.errorKey,
    this.updatedAtMs = 0,
  });

  /// Stable cache key — the room slug (one room is one video).
  final String key;
  final String slug;
  final String title;

  /// Rangeable HTTP URL the bytes are pulled from: `/video/:filename` for
  /// upload/download rooms, `/stream/:slug` for torrent rooms. Server-derived,
  /// so it is re-resolvable on resume.
  final String sourceUrl;

  final CacheStatus status;

  /// Absolute path to the finished file — set once [status] is [CacheStatus.done].
  final String? localPath;

  /// The room's subtitle, cached alongside the video so it works offline too.
  final String? subtitleUrl;
  final String? subtitlePath;

  /// Total size in bytes, or 0 while still unknown.
  final int totalBytes;
  final int downloadedBytes;

  /// Translation key describing the last failure (when [status] is error).
  final String? errorKey;
  final int updatedAtMs;

  bool get isDone => status == CacheStatus.done;
  bool get isDownloading => status == CacheStatus.downloading;

  /// 0..1, or null while the total size is still unknown (indeterminate bar).
  double? get progress {
    if (status == CacheStatus.done) return 1;
    if (totalBytes <= 0) return null;
    return (downloadedBytes / totalBytes).clamp(0, 1).toDouble();
  }

  CachedVideo copyWith({
    String? title,
    String? sourceUrl,
    CacheStatus? status,
    String? localPath,
    String? subtitleUrl,
    String? subtitlePath,
    int? totalBytes,
    int? downloadedBytes,
    String? errorKey,
    bool clearError = false,
    int? updatedAtMs,
  }) => CachedVideo(
    key: key,
    slug: slug,
    title: title ?? this.title,
    sourceUrl: sourceUrl ?? this.sourceUrl,
    status: status ?? this.status,
    localPath: localPath ?? this.localPath,
    subtitleUrl: subtitleUrl ?? this.subtitleUrl,
    subtitlePath: subtitlePath ?? this.subtitlePath,
    totalBytes: totalBytes ?? this.totalBytes,
    downloadedBytes: downloadedBytes ?? this.downloadedBytes,
    errorKey: clearError ? null : (errorKey ?? this.errorKey),
    updatedAtMs: updatedAtMs ?? this.updatedAtMs,
  );

  Map<String, dynamic> toJson() => {
    'key': key,
    'slug': slug,
    'title': title,
    'sourceUrl': sourceUrl,
    'status': status.name,
    'localPath': localPath,
    'subtitleUrl': subtitleUrl,
    'subtitlePath': subtitlePath,
    'totalBytes': totalBytes,
    'downloadedBytes': downloadedBytes,
    'errorKey': errorKey,
    'updatedAtMs': updatedAtMs,
  };

  factory CachedVideo.fromJson(Map<String, dynamic> j) => CachedVideo(
    key: j['key'] as String,
    slug: j['slug'] as String? ?? j['key'] as String,
    title: j['title'] as String? ?? '',
    sourceUrl: j['sourceUrl'] as String? ?? '',
    status: _statusFrom(j['status'] as String?),
    localPath: j['localPath'] as String?,
    subtitleUrl: j['subtitleUrl'] as String?,
    subtitlePath: j['subtitlePath'] as String?,
    totalBytes: (j['totalBytes'] as num?)?.toInt() ?? 0,
    downloadedBytes: (j['downloadedBytes'] as num?)?.toInt() ?? 0,
    errorKey: j['errorKey'] as String?,
    updatedAtMs: (j['updatedAtMs'] as num?)?.toInt() ?? 0,
  );

  @override
  List<Object?> get props => [
    key,
    status,
    downloadedBytes,
    totalBytes,
    localPath,
    subtitlePath,
    errorKey,
  ];
}
