/// How a room's video is sourced. Mirrors the backend `Room.roomType` column.
enum RoomType {
  /// A file uploaded directly to the server.
  upload,

  /// A file the server downloaded from a pasted link.
  download,

  /// A third-party embed URL rendered inside a WebView (no file of our own).
  external,

  /// A magnet link the server streams from a BitTorrent swarm over
  /// `/stream/:slug` — played like an ordinary file room (real player, full
  /// sync/seek), not a WebView embed.
  torrent;

  static RoomType fromString(String? value) => switch (value) {
    'external' => RoomType.external,
    'download' => RoomType.download,
    'torrent' => RoomType.torrent,
    _ => RoomType.upload,
  };

  bool get isExternal => this == RoomType.external;

  bool get isTorrent => this == RoomType.torrent;

  /// Wire value sent to the backend `roomType` field.
  String get wire => name;
}
