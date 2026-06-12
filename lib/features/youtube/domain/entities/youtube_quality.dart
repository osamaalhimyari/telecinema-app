/// One selectable download quality for a YouTube video, derived on-device from
/// the stream manifest. [height] is the only value sent to the server (as
/// `maxHeight`): the server's yt-dlp then fetches the best format at or below it
/// — so an exact, ephemeral stream id never has to round-trip.
class YoutubeQuality {
  const YoutubeQuality({required this.height, this.sizeBytes});

  /// Vertical resolution in pixels (e.g. 1080).
  final int height;

  /// Approximate size of the chosen video stream, when the manifest reports it.
  /// Indicative only — the server muxes a separate audio track, so the final
  /// file differs slightly.
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
