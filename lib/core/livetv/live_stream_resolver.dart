import 'live_stream.dart';

/// Re-resolves a live-TV channel's currently-valid stream when its signed token
/// expires. Declared in core so the watch feature can depend on it without
/// reaching into the TV feature; the implementation (which knows the YacineTV
/// tree) lives in `features/tv` and is bound in DI.
abstract class LiveStreamResolver {
  /// Fetches a fresh stream for the channel identified by [path] (its name-path
  /// in the provider tree) and persists it to room [slug] so the room keeps
  /// working — including for viewers who join after the original token died.
  /// Returns null when the channel can't be re-resolved.
  Future<LiveStream?> refresh({required String slug, required List<String> path});
}
