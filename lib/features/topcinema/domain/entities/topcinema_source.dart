import 'package:equatable/equatable.dart';

/// One downloadable quality of a title resolved from the topcinema "second way"
/// (`GET /api/topcinema/resolve`). [url] is a direct, time-limited CDN `.mp4`
/// that the server can fetch through the normal `download` room flow.
class TopcinemaSource extends Equatable {
  const TopcinemaSource({
    required this.quality,
    required this.label,
    required this.url,
    this.resolution,
    this.sizeMb,
  });

  /// Vidtube quality key: `x`=1080p, `h`=720p, `n`=480p, `l`=240p.
  final String quality;

  /// Full label from the host, e.g. `1080p FHD 1904x1024, 799.0 MB`.
  final String label;

  /// Direct tokenized CDN `.mp4` url (valid ~24h).
  final String url;

  final String? resolution;
  final double? sizeMb;

  /// A short tag for the badge, derived from [label] (e.g. `1080p`).
  String get shortLabel =>
      RegExp(r'\d{3,4}p').firstMatch(label)?.group(0) ?? quality.toUpperCase();

  /// `1904x1024 · 799.0 MB` — the secondary line in the picker.
  String get meta {
    final parts = <String>[
      ?resolution,
      if (sizeMb != null) '${sizeMb!.toStringAsFixed(0)} MB',
    ];
    return parts.join('  ·  ');
  }

  factory TopcinemaSource.fromJson(Map<String, dynamic> json) => TopcinemaSource(
    quality: json['quality']?.toString() ?? '',
    label: json['label']?.toString() ?? '',
    url: json['url']?.toString() ?? '',
    resolution: json['resolution']?.toString(),
    sizeMb: (json['sizeMb'] is num) ? (json['sizeMb'] as num).toDouble() : null,
  );

  @override
  List<Object?> get props => [quality, label, url, resolution, sizeMb];
}
