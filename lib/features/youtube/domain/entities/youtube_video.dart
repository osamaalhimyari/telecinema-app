/// One YouTube search result, discovered ON-DEVICE via `youtube_explode_dart`
/// (no API key). [url] is the canonical watch link handed to the server, which
/// re-resolves and downloads it with yt-dlp — so nothing here is a direct media
/// URL (those are IP-locked and short-lived).
class YoutubeVideo {
  const YoutubeVideo({
    required this.id,
    required this.title,
    required this.author,
    required this.url,
    this.duration,
  });

  /// The 11-char video id (e.g. `dQw4w9WgXcQ`).
  final String id;
  final String title;

  /// Channel name.
  final String author;

  /// Canonical `https://www.youtube.com/watch?v=<id>` link.
  final String url;
  final Duration? duration;

  /// Medium thumbnail, built straight from the id (no extra network metadata).
  String get thumbnailUrl => 'https://i.ytimg.com/vi/$id/mqdefault.jpg';

  /// The embeddable player URL used for the in-app preview.
  String get embedUrl => 'https://www.youtube.com/embed/$id?playsinline=1&rel=0';

  /// `mm:ss` (or `h:mm:ss`) for the result card; empty when unknown (e.g. live).
  String get durationLabel {
    final d = duration;
    if (d == null) return '';
    String two(int n) => n.toString().padLeft(2, '0');
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    return h > 0 ? '$h:${two(m)}:${two(s)}' : '$m:${two(s)}';
  }
}
