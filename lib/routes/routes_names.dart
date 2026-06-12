class RoutesNames {
  RoutesNames._();

  /// Home — the grid of rooms (first bottom-nav tab).
  static const rooms = 'rooms';

  /// Browse catalogue (second bottom-nav tab).
  static const browse = 'browse';

  /// Saved movies/series (third bottom-nav tab).
  static const favorites = 'favorites';

  /// A title's detail page in the Browse catalogue.
  static const browseDetail = 'browse-detail';

  /// Create-room form.
  static const createRoom = 'create-room';

  /// The synchronized player for a single room. Carries the slug as a path
  /// param so deep links survive a cold start.
  static const room = 'room';

  /// In-room "Download subtitle" search (OpenSubtitles), pushed above the room.
  static const subtitles = 'subtitles';

  /// Library of videos cached on this device (download-for-offline manager).
  static const cached = 'cached';
}
