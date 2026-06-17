/// One selectable download for a YouTube video, resolved **on-device** to the
/// actual googlevideo CDN URLs — so the server never has to run yt-dlp (its IP
/// is bot-blocked by YouTube's API).
///
/// Two shapes:
///   * adaptive (the usual case) — [videoUrl] is an mp4 video-only stream at
///     [height] and [audioUrl] is the best audio-only stream. The server
///     downloads both and muxes them with ffmpeg (lossless video copy + aac
///     audio), which is the only way to get 1080p+ (YouTube serves nothing
///     combined above 720p).
///   * muxed fallback — [audioUrl] is null and [videoUrl] already carries audio
///     (a progressive stream, ≤720p). The server just downloads the one URL.
class YoutubeStreamOption {
  const YoutubeStreamOption({
    required this.height,
    required this.videoUrl,
    this.audioUrl,
    this.sizeBytes,
  });

  /// Vertical resolution in pixels (e.g. 1080).
  final int height;

  /// Direct googlevideo URL of the (video-only, or muxed) stream.
  final String videoUrl;

  /// Direct googlevideo URL of the audio stream to mux in, or null when
  /// [videoUrl] already contains audio (muxed fallback).
  final String? audioUrl;

  /// Approximate total size of the chosen stream(s); indicative only.
  final int? sizeBytes;

  /// Short badge tag, e.g. `1080p`.
  String get shortLabel => '${height}p';

  /// Full label line, e.g. `1080p`.
  String get label => '${height}p';

  /// Secondary line, e.g. `~120 MB`; empty when the size is unknown.
  String get meta {
    final b = sizeBytes;
    if (b == null || b <= 0) return '';
    final mb = b / (1024 * 1024);
    return mb >= 1024
        ? '~${(mb / 1024).toStringAsFixed(1)} GB'
        : '~${mb.round()} MB';
  }
}
