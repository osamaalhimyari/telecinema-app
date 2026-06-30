import 'package:equatable/equatable.dart';

/// One direct source of a movie resolved from the iwaatch "direct link" provider
/// (`GET /api/iwaatch/resolve`). [url] is a direct, playable/downloadable video
/// link the server resolved (iwaatch is geo-blocked for the client, so the
/// backend scrapes it). [kind] is `mp4` (a single file) or `hls` (an `.m3u8`).
class IwaatchSource extends Equatable {
  const IwaatchSource({
    required this.quality,
    required this.label,
    required this.url,
    required this.kind,
    this.resolution,
    this.subtitle,
  });

  /// `2160p` … `360p`, or `auto`.
  final String quality;

  /// Human label shown in the picker (an `(HLS)` tag for m3u8).
  final String label;

  /// Direct, playable/downloadable url.
  final String url;

  /// `mp4` (a single downloadable file) or `hls` (an `.m3u8` playlist).
  final String kind;

  final String? resolution;

  /// A subtitle (.vtt/.srt) url found alongside the video, if any.
  final String? subtitle;

  bool get isHls => kind == 'hls';

  /// Short tag for the badge, e.g. `1080p` (or `HLS`/`MP4` when unknown).
  String get shortLabel {
    if (quality != 'auto') return quality;
    return kind.toUpperCase();
  }

  /// Secondary line in the picker.
  String get meta {
    final parts = <String>[
      ?resolution,
      if (isHls) 'HLS stream' else 'MP4 file',
      if (subtitle != null) 'subtitle',
    ];
    return parts.join('  ·  ');
  }

  factory IwaatchSource.fromJson(Map<String, dynamic> json) => IwaatchSource(
    quality: json['quality']?.toString() ?? 'auto',
    label: json['label']?.toString() ?? '',
    url: json['url']?.toString() ?? '',
    kind: json['kind']?.toString() ?? 'mp4',
    resolution: json['resolution']?.toString(),
    subtitle: json['subtitle']?.toString(),
  );

  @override
  List<Object?> get props => [quality, label, url, kind, resolution, subtitle];
}
