class RoutesNames {
  RoutesNames._();

  /// Home — the grid of rooms (first bottom-nav tab).
  static const rooms = 'rooms';

  /// Browse catalogue (second bottom-nav tab).
  static const browse = 'browse';

  /// A title's detail page in the Browse catalogue.
  static const browseDetail = 'browse-detail';

  /// Create-room form.
  static const createRoom = 'create-room';

  /// The synchronized player for a single room. Carries the slug as a path
  /// param so deep links survive a cold start.
  static const room = 'room';

  /// In-room "Download subtitle" search (OpenSubtitles), pushed above the room.
  static const subtitles = 'subtitles';
}
