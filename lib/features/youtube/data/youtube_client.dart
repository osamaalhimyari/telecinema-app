import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import '/core/errors/exceptions.dart';
import '../domain/entities/youtube_quality.dart';
import '../domain/entities/youtube_stream_option.dart';
import '../domain/entities/youtube_video.dart';

/// On-device YouTube access via `youtube_explode_dart` (no API key).
///
/// Runs on the *device's* network — the same on-device strategy as the
/// topcinema scraper, because the deployed server's IP is blocked by YouTube's
/// bot checks. It is used ONLY to search and to enumerate available qualities;
/// the actual download is done server-side by yt-dlp from the watch URL, so the
/// IP-locked, short-lived CDN stream URLs never leave the device.
class YoutubeClient {
  YoutubeClient([YoutubeExplode? yt]) : _yt = yt ?? YoutubeExplode();

  final YoutubeExplode _yt;

  /// Searches YouTube for [query], OR — when [query] is a YouTube video link or
  /// bare 11-char id — resolves that single video directly (so the user can
  /// paste a link instead of searching). Empty query yields no results.
  Future<List<YoutubeVideo>> search(String query) async {
    final q = query.trim();
    if (q.isEmpty) return const [];

    // A pasted watch/youtu.be/shorts/embed link (or a raw id) → that one video.
    final pastedId = VideoId.parseVideoId(q);
    if (pastedId != null) {
      try {
        final v = await _yt.videos.get(pastedId);
        return [_toVideo(v)];
      } catch (_) {
        throw const ServerException('youtube_unavailable');
      }
    }

    try {
      final results = await _yt.search.search(q);
      return [for (final v in results) _toVideo(v)];
    } catch (_) {
      throw const ServerException('youtube_unavailable');
    }
  }

  YoutubeVideo _toVideo(Video v) => YoutubeVideo(
    id: v.id.value,
    title: v.title,
    author: v.author,
    url: 'https://www.youtube.com/watch?v=${v.id.value}',
    duration: v.duration,
  );

  /// Distinct downloadable heights for [videoId], best size per height, newest
  /// (highest) first. Spans muxed + video-only streams (the server merges audio
  /// itself), so 1080p+ is offered even though muxed progressive caps at 720p.
  ///
  /// The manifest extraction is `youtube_explode`'s most fragile call (YouTube's
  /// signature/JS challenges change often and can stall), so it is time-boxed
  /// and ALWAYS falls back to standard resolution buckets — room creation must
  /// never hang or fail just because the exact list couldn't be fetched. The
  /// server picks the best format ≤ the chosen height regardless.
  Future<List<YoutubeQuality>> qualities(String videoId) async {
    try {
      final manifest = await _yt.videos.streamsClient
          .getManifest(videoId)
          .timeout(const Duration(seconds: 8));
      final byHeight = <int, int>{}; // height -> largest stream size seen
      for (final s in manifest.video) {
        final h = s.videoResolution.height;
        if (h <= 0) continue;
        final bytes = s.size.totalBytes;
        if (bytes > (byHeight[h] ?? 0)) byHeight[h] = bytes;
      }
      final heights = byHeight.keys.toList()..sort((a, b) => b.compareTo(a));
      if (heights.isEmpty) return _fallbackQualities;
      return [
        for (final h in heights) YoutubeQuality(height: h, sizeBytes: byHeight[h]),
      ];
    } catch (_) {
      return _fallbackQualities;
    }
  }

  /// Standard resolution choices used when the live manifest can't be read.
  static const List<YoutubeQuality> _fallbackQualities = [
    YoutubeQuality(height: 1080),
    YoutubeQuality(height: 720),
    YoutubeQuality(height: 480),
    YoutubeQuality(height: 360),
  ];

  /// Resolves [videoIdOrUrl] to the **direct googlevideo download URLs** for each
  /// available height, on-device — so the server can fetch them without yt-dlp.
  ///
  /// Prefers adaptive mp4 video-only streams (paired with the best audio stream
  /// for the server to mux), which is the only way past YouTube's 720p cap on
  /// combined streams. Falls back to muxed (progressive, audio baked in, ≤720p)
  /// when a video has no separate mp4 streams. Highest resolution first.
  ///
  /// Unlike [qualities], this can NOT fall back to fixed resolution buckets — it
  /// must return real URLs — so it throws [ServerException] when the manifest
  /// can't be read or no usable stream exists; the caller surfaces a snack.
  Future<List<YoutubeStreamOption>> resolveStreams(String videoIdOrUrl) async {
    final id = VideoId.parseVideoId(videoIdOrUrl) ?? videoIdOrUrl.trim();
    if (id.isEmpty) throw const ServerException('youtube_unavailable');

    StreamManifest manifest;
    try {
      manifest = await _yt.videos.streamsClient
          .getManifest(id)
          .timeout(const Duration(seconds: 12));
    } catch (_) {
      throw const ServerException('youtube_unavailable');
    }

    // Best audio to mux in: prefer m4a (mp4 container) for a clean download,
    // else the highest-bitrate audio of any container (server re-encodes to aac).
    final audios = manifest.audioOnly.toList()
      ..sort((a, b) => b.bitrate.bitsPerSecond.compareTo(a.bitrate.bitsPerSecond));
    final mp4Audio = audios.where((a) => a.container == StreamContainer.mp4);
    final audio = mp4Audio.isNotEmpty ? mp4Audio.first : (audios.isNotEmpty ? audios.first : null);

    // Adaptive path: one mp4 video-only stream per height (largest = best).
    if (audio != null) {
      final best = <int, VideoOnlyStreamInfo>{};
      for (final v in manifest.videoOnly) {
        if (v.container != StreamContainer.mp4) continue;
        final h = v.videoResolution.height;
        if (h <= 0) continue;
        final cur = best[h];
        if (cur == null || v.size.totalBytes > cur.size.totalBytes) best[h] = v;
      }
      if (best.isNotEmpty) {
        final heights = best.keys.toList()..sort((a, b) => b.compareTo(a));
        return [
          for (final h in heights)
            YoutubeStreamOption(
              height: h,
              videoUrl: best[h]!.url.toString(),
              audioUrl: audio.url.toString(),
              sizeBytes: best[h]!.size.totalBytes + audio.size.totalBytes,
            ),
        ];
      }
    }

    // Muxed fallback: progressive streams already carry audio (≤720p).
    final muxed = <int, MuxedStreamInfo>{};
    for (final m in manifest.muxed) {
      final h = m.videoResolution.height;
      if (h <= 0) continue;
      final cur = muxed[h];
      if (cur == null || m.size.totalBytes > cur.size.totalBytes) muxed[h] = m;
    }
    if (muxed.isEmpty) throw const ServerException('youtube_unavailable');
    final heights = muxed.keys.toList()..sort((a, b) => b.compareTo(a));
    return [
      for (final h in heights)
        YoutubeStreamOption(
          height: h,
          videoUrl: muxed[h]!.url.toString(),
          sizeBytes: muxed[h]!.size.totalBytes,
        ),
    ];
  }
}
