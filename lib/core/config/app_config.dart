/// Central configuration for the watch-party client.
///
/// The app talks to the AdonisJS backend two ways:
///   * a JSON REST API under `/api` (room catalogue + lifecycle), and
///   * the Socket.IO endpoint at the server root (realtime sync, chat,
///     presence, reactions, voice) — the *same* protocol the web client uses.
///
/// Both live on the same origin, so a single [baseUrl] drives everything.
class AppConfig {
  AppConfig._();

  // ===========================================================================
  // ⚠️  SET THIS to your deployed watch-party server (the AdonisJS app).
  //
  //   * Deployed server : 'https://your-domain.com'
  //   * Android emulator: 'http://10.0.2.2:3333'   (host machine's localhost)
  //   * Physical device : 'http://192.168.x.x:3333' (the PC's LAN IP)
  //
  // The repo is named "telecinema"; replace the placeholder below with the
  // real public URL. HTTP (not HTTPS) is permitted on Android/iOS via the
  // cleartext flags already set in the native manifests.
  // ===========================================================================
  static const String baseUrl = 'https://telecinema.example.com';

  /// REST API root. Matches the `/api` prefix registered in `start/routes.ts`.
  static String get baseApiUrl => '$baseUrl/api';

  /// Socket.IO connects to the server root (default namespace, `/socket.io`).
  static String get socketBaseUrl => baseUrl;

  /// Absolute URL of a room's streamable video (`GET /video/:filename`, with
  /// HTTP range support). Empty filename → null (e.g. external rooms).
  static String? videoUrl(String? filename) =>
      (filename == null || filename.isEmpty) ? null : '$baseUrl/video/$filename';

  /// Absolute URL of a room's thumbnail (served statically from `public/`).
  static String? thumbnailUrl(String? filename) => (filename == null || filename.isEmpty)
      ? null
      : '$baseUrl/thumbnails/$filename';

  /// Absolute URL of a room's subtitle track (`GET /subtitles/:filename`).
  static String? subtitleUrl(String? filename) => (filename == null || filename.isEmpty)
      ? null
      : '$baseUrl/subtitles/$filename';
}
