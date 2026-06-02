import 'playback_sync.dart';

/// Emitted when an external room switches its embed URL (e.g. next episode).
/// Carries the fresh, reset playback state along with the new URL.
class SourceChange {
  const SourceChange({required this.url, required this.sync});

  final String url;
  final PlaybackSync sync;

  factory SourceChange.fromJson(Map<String, dynamic> json) => SourceChange(
    url: (json['url'] ?? '').toString(),
    sync: PlaybackSync.fromJson(json),
  );
}
