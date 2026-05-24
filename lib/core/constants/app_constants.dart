class AppConstants {
  AppConstants._();

  static const String appName = 'Watch Party';

  /// Cap on how many chat messages are kept in memory client-side. The server
  /// keeps a ring buffer of 80 (see `start/socket.ts`); we mirror that so the
  /// list cannot grow unbounded over a long session.
  static const int chatHistoryLimit = 200;

  /// A stall must persist this long before we report `buffer_state: true` to
  /// the room, matching the web client's ~1.5s debounce so a momentary hiccup
  /// doesn't pause everyone.
  static const Duration bufferReportDelay = Duration(milliseconds: 1500);

  /// If our local playback drifts further than this from the room's
  /// authoritative position, we hard-seek instead of nudging the rate.
  static const double hardSeekThresholdSeconds = 1.5;
}
