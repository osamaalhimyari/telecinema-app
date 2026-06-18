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

  /// A YouTube watch URL. The server resolves it to a direct stream and proxies
  /// it over `/youtube/:slug`, so it plays like an ordinary file room (our own
  /// player + full sync/seek), never the YouTube iframe.
  youtube,

  /// A link to a public Telegram channel post that holds a video. The server
  /// scrapes the post's web preview for the direct CDN URL and downloads it
  /// into an ordinary file room — submitted on the wire as a `download` whose
  /// `videoUrl` is the `t.me/...` link (the server detects and resolves it).
  telegram;

  static RoomType fromString(String? value) => switch (value) {
    'external' => RoomType.external,
    'download' => RoomType.download,
    'torrent' => RoomType.torrent,
    'youtube' => RoomType.youtube,
    'telegram' => RoomType.telegram,
    _ => RoomType.upload,
  };

  bool get isExternal => this == RoomType.external;

  bool get isTorrent => this == RoomType.torrent;

  bool get isYoutube => this == RoomType.youtube;

  bool get isTelegram => this == RoomType.telegram;

  /// Wire value sent to the backend `roomType` field.
  String get wire => name;
}
