class RoutesNames {
  RoutesNames._();

  /// Home — the grid of rooms.
  static const rooms = 'rooms';

  /// Create-room form.
  static const createRoom = 'create-room';

  /// The synchronized player for a single room. Carries the slug as a path
  /// param so deep links survive a cold start.
  static const room = 'room';
}
