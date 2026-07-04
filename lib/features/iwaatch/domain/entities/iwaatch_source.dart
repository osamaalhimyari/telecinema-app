import 'package:equatable/equatable.dart';

/// One playable/downloadable quality of a movie resolved from the iwaatch
/// "direct link" source (`GET /api/iwaatch/resolve`). [url] is a direct media
/// link — an `.mp4` file or an `.m3u8` HLS playlist, per [kind] — that the
/// server can fetch through the normal `download` room flow.
class IwaatchSource extends Equatable {
  const IwaatchSource({
    required this.quality,
    required this.label,
    required this.url,
    required this.kind,
    this.resolution,
    this.subtitle,
  });

  /// `2160p` … `360p`, or `auto` when the url carries no resolution hint.
  final String quality;

  /// Human label shown in the picker (carries an `HLS` tag for m3u8).
  final String label;

  /// Direct, playable/downloadable url.
  final String url;

  /// `mp4` (a single downloadable file) or `hls` (an `.m3u8` playlist).
  final String kind;

  final String? resolution;

  /// A subtitle (.vtt/.srt) url found alongside the video, if any.
  final String? subtitle;

  bool get isHls => kind == 'hls';

  /// A short tag for the badge, derived from [label] (e.g. `1080p`).
  String get shortLabel =>
      RegExp(r'\d{3,4}p').firstMatch(label)?.group(0) ?? quality.toUpperCase();

  /// Secondary line in the picker: resolution and/or an `HLS` marker.
  String get meta {
    final parts = <String>[
      ?resolution,
      if (isHls) 'HLS',
    ];
    return parts.join('  ·  ');
  }

  factory IwaatchSource.fromJson(Map<String, dynamic> json) => IwaatchSource(
    quality: json['quality']?.toString() ?? '',
    label: json['label']?.toString() ?? '',
    url: json['url']?.toString() ?? '',
    kind: json['kind']?.toString() ?? 'mp4',
    resolution: json['resolution']?.toString(),
    subtitle: json['subtitle']?.toString(),
  );

  @override
  List<Object?> get props => [quality, label, url, kind, resolution, subtitle];
}
