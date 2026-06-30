import '/core/errors/exceptions.dart';
import '/core/network/api_client.dart';
import '../domain/entities/tv_channel.dart';
import '../domain/entities/tv_node.dart';

/// Fetches and parses the YacineTV live-TV tree from the app's own server
/// (`GET /api/tv/tree`), which fetches + caches it from the provider — so the
/// device never talks to YacineTV directly, exactly like the catalogue/streams/
/// topcinema sources. The server returns the provider's native shape, so the
/// parsing below is unchanged; only the transport moved off-device.
///
/// The parsed tree is cached in memory for the session; [fetchTree] re-fetches
/// (with `?refresh=1`, forcing the server to renew the short-lived per-channel
/// tokens) when [forceRefresh] is set — a manual refresh, or the token-refresh
/// path, gets fresh, playable links.
///
/// Throws [ServerException] with a stable, translatable key on failure.
class TvApi {
  TvApi(this._api);

  final ApiClient _api;

  List<TvNode>? _cache;

  /// The top-level category groups. Cached after the first successful load;
  /// pass [forceRefresh] to bypass the cache and pull fresh stream tokens.
  Future<List<TvNode>> fetchTree({bool forceRefresh = false}) async {
    final cached = _cache;
    if (cached != null && !forceRefresh) return cached;

    final res = await _api.get(
      '/tv/tree',
      queryParameters: {if (forceRefresh) 'refresh': 1},
    );
    if (!res.success) {
      throw ServerException(res.message ?? 'tv_unavailable', statusCode: res.statusCode);
    }
    final data = res.data;
    final cats = data is Map ? data['categories'] : null;
    final tree = (cats is List)
        ? cats
              .whereType<Map>()
              .map((m) => _node(Map<String, dynamic>.from(m)))
              .where((n) => n.isGroup || n.channels.isNotEmpty)
              .toList(growable: false)
        : <TvNode>[];
    _cache = tree;
    return tree;
  }

  // ── parsing ──────────────────────────────────────────────────────────────

  TvNode _node(Map<String, dynamic> json) {
    final rawChildren = json['children'];
    final rawChannels = json['channels'];

    final children = (rawChildren is List)
        ? rawChildren
              .whereType<Map>()
              .map((m) => _node(Map<String, dynamic>.from(m)))
              // Drop branches that ended up empty (every channel filtered out).
              .where((n) => n.isGroup || n.channels.isNotEmpty)
              .toList(growable: false)
        : const <TvNode>[];

    final channels = (rawChannels is List)
        ? rawChannels
              .whereType<Map>()
              .map((m) => _channel(Map<String, dynamic>.from(m)))
              .whereType<TvChannel>()
              .toList(growable: false)
        : const <TvChannel>[];

    return TvNode(
      name: (json['name'] ?? '').toString(),
      logo: _str(json['logo']),
      children: children,
      channels: channels,
    );
  }

  /// Parses one channel, or returns null for entries we can't play — the feed
  /// carries occasional non-HTTP junk (`chrome-extension:` links and the like).
  TvChannel? _channel(Map<String, dynamic> json) {
    final url = (json['url'] ?? '').toString().trim();
    if (!url.startsWith('http')) return null;
    return TvChannel(
      name: (json['name'] ?? '').toString(),
      url: url,
      logo: _str(json['logo']),
      headers: _headersMap(json['headers']),
    );
  }

  Map<String, String> _headersMap(dynamic raw) {
    if (raw is! Map) return const {};
    final out = <String, String>{};
    raw.forEach((k, v) {
      final key = k?.toString();
      final val = v?.toString();
      if (key != null && key.isNotEmpty && val != null && val.isNotEmpty) {
        out[key] = val;
      }
    });
    return out;
  }

  static String? _str(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }
}
