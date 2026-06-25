import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '/core/errors/exceptions.dart';
import '../domain/entities/tv_channel.dart';
import '../domain/entities/tv_node.dart';

/// Fetches and parses the YacineTV live-TV tree.
///
/// Talks straight to the provider over `package:http` — its only gate is a fixed
/// `User-Agent` header (no token or API key) — exactly like the Cinema/Browse
/// datasources, so the feature stays independent of the app's backend
/// [ApiClient]. The parsed tree is cached in memory for the session;
/// [fetchTree] re-fetches when [forceRefresh] is set, because the per-channel
/// stream URLs carry short-lived signed tokens — a manual refresh gets fresh,
/// playable links.
///
/// Throws [ServerException] with a stable, translatable key on failure.
class TvApi {
  TvApi([http.Client? client]) : _client = client ?? http.Client();

  final http.Client _client;

  static const String _treeUrl = 'https://ostoraapptv.com/yacine_tree.json';

  /// The app-specific User-Agent the backend gates on; the request is rejected
  /// without it.
  static const Map<String, String> _headers = {
    'User-Agent': 'FlutterApp/1.0 (YacineTV)',
  };
  static const Duration _timeout = Duration(seconds: 25);

  List<TvNode>? _cache;

  /// The top-level category groups. Cached after the first successful load;
  /// pass [forceRefresh] to bypass the cache and pull fresh stream tokens.
  Future<List<TvNode>> fetchTree({bool forceRefresh = false}) async {
    final cached = _cache;
    if (cached != null && !forceRefresh) return cached;

    final json = await _getJson(_treeUrl);
    final cats = json['categories'];
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

  Future<Map<String, dynamic>> _getJson(String url) async {
    try {
      final res =
          await _client.get(Uri.parse(url), headers: _headers).timeout(_timeout);
      if (res.statusCode != 200) {
        throw ServerException('error_request_failed', statusCode: res.statusCode);
      }
      final body = jsonDecode(res.body);
      return body is Map<String, dynamic> ? body : <String, dynamic>{};
    } on ServerException {
      rethrow;
    } on TimeoutException {
      throw const ServerException('error_timeout');
    } catch (e) {
      throw ServerException('error_unknown', cause: e);
    }
  }
}
