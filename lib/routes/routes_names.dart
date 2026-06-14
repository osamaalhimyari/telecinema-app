class RoutesNames {
  RoutesNames._();

  /// Home — the grid of rooms (first bottom-nav tab).
  static const rooms = 'rooms';

  /// Cinema catalogue (EgyBest) — its own bottom-nav tab, beside Browse.
  static const cinema = 'cinema';

  /// A title's detail page in the Cinema catalogue.
  static const cinemaDetail = 'cinema-detail';

  /// Browse catalogue (second bottom-nav tab).
  static const browse = 'browse';

  /// Saved movies/series (third bottom-nav tab).
  static const favorites = 'favorites';

  /// YouTube search → server-download room creation (fourth bottom-nav tab).
  static const youtube = 'youtube';

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
