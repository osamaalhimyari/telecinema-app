import 'package:equatable/equatable.dart';

import '../../data/cinema_json.dart';

/// One downloadable source from an EgyBest `videos[]` entry — what the user sees
/// as a "server" in the detail screen.
///
/// The fields mirror the API verbatim; the resolver
/// ([CinemaResolver.resolve]) turns a server into one or more direct media
/// links. [header]/[userAgent] are the request context many hosts require
/// (they 403 without the right `Referer`).
class CinemaServer extends Equatable {
  const CinemaServer({
    required this.name,
    required this.link,
    this.header = '',
    this.userAgent = '',
    this.hls = false,
    this.embed = false,
    this.downloadOnly = false,
    this.youtubeLink = false,
    this.supportedHosts = false,
    this.drm = false,
  });

  /// e.g. `Server Egy 1080p`, `Uqload`, `VIP Fast`.
  final String name;

  /// The page/CDN url to resolve (or, for direct servers, the `.mp4` itself).
  final String link;

  /// Sent as `Referer` when resolving — verbatim from the API.
  final String header;
  final String userAgent;

  final bool hls;
  final bool embed;
  final bool downloadOnly;
  final bool youtubeLink;
  final bool supportedHosts;
  final bool drm;

  /// True when [link] is already a direct media file (no resolving needed).
  bool get isDirect {
    final l = link.toLowerCase();
    return l.contains('.mp4') || l.contains('.m3u8') || l.contains('.mkv');
  }

  /// A resolution badge pulled from the server name (`1080p`, `720p`, `4K`, …),
  /// used both as the tile badge and, for the yandex/seriesmp4 servers that ship
  /// one entry per quality, as the quality the user is picking.
  String? get qualityLabel {
    final m = RegExp(r'(\d{3,4})\s*[pP]').firstMatch(name) ??
        RegExp(r'(\d{3,4})\s*[pP]').firstMatch(link);
    if (m != null) return '${m.group(1)}p';
    if (RegExp(r'\b4k\b', caseSensitive: false).hasMatch(name)) return '4K';
    return null;
  }

  /// A clean label for the tile when there's no quality token.
  String get displayName => name.trim().isEmpty ? 'Server' : name.trim();

  factory CinemaServer.fromJson(Map<String, dynamic> json) {
    return CinemaServer(
      name: asString(json['server']) ?? 'Server',
      link: asString(json['link']) ?? asString(json['tmp_link']) ?? '',
      header: asString(json['header']) ?? '',
      userAgent: asString(json['useragent']) ?? '',
      hls: asBool(json['hls']),
      embed: asBool(json['embed']),
      downloadOnly: asBool(json['downloadonly']),
      youtubeLink: asBool(json['youtubelink']),
      supportedHosts: asBool(json['supported_hosts']),
      drm: asBool(json['drm']),
    );
  }

  /// Parses a `videos[]` array, dropping DRM and link-less entries (unplayable
  /// for a downloadable room).
  static List<CinemaServer> listFrom(dynamic videos) {
    if (videos is! List) return const [];
    return videos
        .whereType<Map>()
        .map((v) => CinemaServer.fromJson(Map<String, dynamic>.from(v)))
        .where((s) => s.link.isNotEmpty && !s.drm)
        .toList(growable: false);
  }

  @override
  List<Object?> get props => [name, link, header, hls, embed, downloadOnly, youtubeLink];
}
