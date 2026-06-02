/// Template for `endpoints.dart` (which is git-ignored).
///
/// Copy this file to `endpoints.dart` in the same folder and fill in the real
/// values, then build. Keeping the actual endpoints out of version control
/// means the catalogue / torrent / subtitle providers aren't baked into the
/// public history.
class Endpoints {
  Endpoints._();

  /// apibay (The Pirate Bay JSON API) free-text search endpoint.
  static const String apibay = '';

  /// Cinemeta (Stremio metadata addon) base URL.
  static const String cinemeta = '';

  /// OpenSubtitles legacy REST API base URL.
  static const String openSubtitles = '';

  /// Public trackers appended to every built magnet to seed peer discovery.
  static const List<String> trackers = [
    // 'udp://tracker.example.org:1337/announce',
  ];
}
