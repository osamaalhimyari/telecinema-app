import 'dart:convert';

import '/core/config/endpoints.dart';

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
  /// The built-in server, used when the user hasn't overridden it. The "Reset
  /// to default" button in Settings restores this.
  static const String defaultBaseUrl = Endpoints.defaultBaseUrl;

  /// The active server origin. Mutable so it can be overridden at runtime from
  /// Settings (persisted, then loaded at startup before the network layer is
  /// built). Everything below — REST, Socket.IO, media URLs — derives from it.
  static String baseUrl = defaultBaseUrl;

  /// Strips surrounding whitespace and any trailing slashes so the derived
  /// `$baseUrl/api`, `$baseUrl/video/...` joins stay clean.
  static String normalizeUrl(String raw) {
    var v = raw.trim();
    while (v.endsWith('/')) {
      v = v.substring(0, v.length - 1);
    }
    return v;
  }

  /// A usable server origin must be an absolute http(s) URL with a host.
  static bool isValidUrl(String raw) {
    final uri = Uri.tryParse(normalizeUrl(raw));
    return uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty;
  }

  /// REST API root. Matches the `/api` prefix registered in `start/routes.ts`.
  static String get baseApiUrl => '$baseUrl/api';

  /// Socket.IO connects to the server root (default namespace, `/socket.io`).
  static String get socketBaseUrl => baseUrl;

  /// Absolute URL of a room's streamable video (`GET /video/:filename`, with
  /// HTTP range support). Empty filename → null (e.g. external rooms).
  static String? videoUrl(String? filename) =>
      (filename == null || filename.isEmpty)
      ? null
      : '$baseUrl/video/$filename';

  /// Absolute URL that streams a torrent room's video from the swarm
  /// (`GET /stream/:slug`, with HTTP range support). The server adds the
  /// magnet on demand, so the app never sees the magnet itself.
  static String? torrentStreamUrl(String? slug) =>
      (slug == null || slug.isEmpty) ? null : '$baseUrl/stream/$slug';

  /// Absolute URL of a room's thumbnail (served statically from `public/`).
  static String? thumbnailUrl(String? filename) =>
      (filename == null || filename.isEmpty)
      ? null
      : '$baseUrl/thumbnails/$filename';

  /// Absolute URL of a room's subtitle track (`GET /subtitles/:filename`).
  static String? subtitleUrl(String? filename) =>
      (filename == null || filename.isEmpty)
      ? null
      : '$baseUrl/subtitles/$filename';

  /// Shareable deep link to a room (`/room/:slug`), matching the go_router
  /// route. Used by the in-room Share action.
  static String roomUrl(String slug) => '$baseUrl/room/$slug';

  static String? tvPreviewUrl({
    required String url,
    Map<String, String> headers = const {},
  }) {
    if (url.isEmpty) return null;
    final u = _b64Url(url);
    final h = _b64Url(jsonEncode(headers));
    return '$baseUrl/livetv/preview?u=$u&h=$h';
  }

  /// base64url without padding (the `=` chars trip URL query parsing; Node's
  /// `Buffer.from(s, 'base64url')` decodes fine without them).
  static String _b64Url(String s) =>
      base64Url.encode(utf8.encode(s)).replaceAll('=', '');
}
