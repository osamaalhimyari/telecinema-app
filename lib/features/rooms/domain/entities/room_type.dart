/// How a room's video is sourced. Mirrors the backend `Room.roomType` column.
enum RoomType {
  /// A file uploaded directly to the server.
  upload,

  /// A file the server downloaded from a pasted link.
  download,

  /// A third-party embed URL rendered inside a WebView (no file of our own).
  external;

  static RoomType fromString(String? value) => switch (value) {
    'external' => RoomType.external,
    'download' => RoomType.download,
    _ => RoomType.upload,
  };

  bool get isExternal => this == RoomType.external;
}
