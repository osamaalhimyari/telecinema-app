import 'dart:convert';

/// A playable live stream: a URL plus the per-channel HTTP headers its origin
/// requires (mandatory, and they vary by channel).
class LiveStream {
  const LiveStream({required this.url, this.headers = const {}});

  final String url;
  final Map<String, String> headers;
}

/// A live-TV room's source as stored on the room. Beyond the currently-playable
/// [url] + [headers] it carries the channel's [path] — its name-path in the
/// provider tree (e.g. `["beIN SPORTS (1080P)", "beIN SPORTS 1"]`) — so a client
/// can re-resolve a fresh URL when the signed token expires.
class LiveStreamRef {
  const LiveStreamRef({
    required this.url,
    this.headers = const {},
    this.path = const [],
  });

  final String url;
  final Map<String, String> headers;
  final List<String> path;
}

/// Packs/unpacks a [LiveStreamRef] into a single string stored as the room's
/// `externalUrl` (the only field the backend persists for a `tv` room).
///
/// Format: the real stream URL, then a `#tv=<base64url(json)>` fragment holding
/// the headers + channel path. Keeping the URL up front means `externalUrl`
/// stays a readable, valid URL; the fragment is never sent to the origin in an
/// HTTP request, so it can't disturb the signed token in the query string.
class LiveStreamCodec {
  LiveStreamCodec._();

  static const _sep = '#tv=';

  static String pack({
    required String url,
    required Map<String, String> headers,
    required List<String> path,
  }) {
    final meta = jsonEncode({'h': headers, 'p': path});
    final b64 = base64Url.encode(utf8.encode(meta));
    return '$url$_sep$b64';
  }

  /// Returns null for an empty input. A string without the `#tv=` marker is
  /// treated as a bare URL (no headers/path) so legacy/odd values still play.
  static LiveStreamRef? unpack(String? packed) {
    if (packed == null || packed.isEmpty) return null;
    final i = packed.indexOf(_sep);
    if (i < 0) return LiveStreamRef(url: packed);
    final url = packed.substring(0, i);
    try {
      final meta = jsonDecode(utf8.decode(base64Url.decode(packed.substring(i + _sep.length))));
      final headers = <String, String>{};
      final path = <String>[];
      if (meta is Map) {
        final h = meta['h'];
        if (h is Map) h.forEach((k, v) => headers[k.toString()] = v.toString());
        final p = meta['p'];
        if (p is List) path.addAll(p.map((e) => e.toString()));
      }
      return LiveStreamRef(url: url, headers: headers, path: path);
    } catch (_) {
      return LiveStreamRef(url: url);
    }
  }
}
