import 'package:equatable/equatable.dart';

/// A single playable live-TV stream: a (usually `.m3u8`) URL plus the per-channel
/// HTTP headers its origin demands. The headers are NOT uniform across the feed
/// (User-Agent and Referer vary channel to channel) and they are mandatory — the
/// same URL fetched without them is rejected by the CDN, so they ride along with
/// every channel and are handed straight to the native player.
class TvChannel extends Equatable {
  const TvChannel({
    required this.name,
    required this.url,
    this.logo,
    this.headers = const {},
  });

  final String name;
  final String url;
  final String? logo;
  final Map<String, String> headers;

  @override
  List<Object?> get props => [name, url, logo, headers];
}
