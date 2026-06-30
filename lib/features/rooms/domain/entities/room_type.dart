/// How a room's video is sourced. Mirrors the backend `Room.roomType` column.
enum RoomType {
  /// A file uploaded directly to the server.
  upload,

  /// A file the server downloaded from a pasted link.
  download,

  /// A third-party embed URL rendered inside a WebView (no file of our own).
  external,

  /// A magnet link. Native clients stream it on-device through the embedded
  /// engine; if that can't reach the swarm (or on web), it falls back to the
  /// server's `/stream/:slug`. Either way it plays like an ordinary file room
  /// (real player, full sync/seek), not a WebView embed.
  torrent,

  /// A live-TV channel. The room's `externalUrl` holds a packed live-stream ref
  /// (stream URL + per-channel headers + provider path); clients play it through
  /// the server's `/livetv/preview` HLS relay — like a file room (real player),
  /// not a WebView embed.
  tv;

  static RoomType fromString(String? value) => switch (value) {
    'external' => RoomType.external,
    'download' => RoomType.download,
    'torrent' => RoomType.torrent,
    'tv' => RoomType.tv,
    _ => RoomType.upload,
  };

  bool get isExternal => this == RoomType.external;

  bool get isTorrent => this == RoomType.torrent;

  bool get isTv => this == RoomType.tv;

  /// Wire value sent to the backend `roomType` field.
  String get wire => name;
}
