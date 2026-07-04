import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '/core/errors/exceptions.dart';
import '../domain/entities/cinema_detail.dart';
import '../domain/entities/cinema_item.dart';
import '../domain/entities/cinema_season.dart';

/// Low-level client for the EgyBest / EasyPlex catalogue API.
///
/// Talks to the provider directly over `package:http` (no `{success,data}`
/// envelope, its own auth) exactly like Browse's Cinemeta datasource — so it
/// stays independent of the app's backend [ApiClient]. Browsing and search are
/// cheap and cached upstream; the fragile link-resolving lives in
/// [CinemaResolver], not here.
///
/// Throws [ServerException] with a stable, translatable key.
class CinemaApi {
  CinemaApi([http.Client? client]) : _client = client ?? http.Client();

  final http.Client _client;

  // ── Provider config (from the documented EgyBest API) ──────────────────
  static const String _base = 'https://abcdef.flech.tn/egybestanto/public/api';
  static const String _code = 'p2lbgWkFrykA4QyUmpHihzmc5BNzIABq';
  static const Map<String, String> _headers = {
    'Accept': 'application/json',
    'packagename': 'com.egyappwatch',
    'Authorization':
        'Bearer AuHLIRR82MvrdTTeaQKUxdA7mlNuk0WD6NnX2ffpn0wqeMP5zwkCClOHClRIbCFf',
    'User-Agent': 'EasyPlex',
  };
  static const Duration _timeout = Duration(seconds: 25);

  /// A page of catalogue tiles plus whether more pages exist (drives infinite
  /// scroll). [listing] is `movies` or `series`; both paginate by `?page=`.
  ///
  /// Uses the **most-watched** feed (`byviews`) rather than `latestadded`: brand-
  /// new titles frequently ship with only a faselhd source (which the on-device
  /// resolver doesn't crack yet), whereas popular titles almost always have a
  /// resolvable server — so the default grid stays actually-downloadable. Search
  /// still reaches everything.
  Future<({List<CinemaItem> items, bool hasMore})> catalog({
    required String listing,
    int page = 1,
  }) async {
    final json = await _getJson('$_base/$listing/byviews/$_code?page=$page');
    final data = json['data'];
    final items = _items(data);
    final current = (json['current_page'] as num?)?.toInt() ?? page;
    final last = (json['last_page'] as num?)?.toInt();
    final hasMore = last != null ? current < last : items.isNotEmpty;
    return (items: items, hasMore: hasMore);
  }

  /// Free-text search across movies + series (`search/{query}`). Single shot —
  /// the endpoint isn't paginated.
  Future<List<CinemaItem>> search(String query) async {
    final q = Uri.encodeComponent(query.trim());
    if (q.isEmpty) return const [];
    final json = await _getJson('$_base/search/$q/$_code');
    return _items(json['search'] ?? json['data']);
  }

  /// Movie detail (`media/detail/{id}`) — the id is the listing's `id`, not a
  /// separate tmdb lookup.
  Future<CinemaDetail> movieDetail(int id) async {
    final json = await _getJson('$_base/media/detail/$id/$_code');
    if (asMapId(json) == 0) throw const ServerException('error_not_found');
    return CinemaDetail.movie(json);
  }

  /// Series detail (`series/show/{id}`) — seasons with (server-less) episode
  /// stubs; [season] fetches the populated episode list.
  Future<CinemaDetail> seriesDetail(int id) async {
    final json = await _getJson('$_base/series/show/$id/$_code');
    if (asMapId(json) == 0) throw const ServerException('error_not_found');
    return CinemaDetail.series(json);
  }

  /// Episodes of one season (`series/season/{seasonId}`) — each episode carries
  /// its `videos[]` (servers) inline.
  Future<List<CinemaEpisode>> season(int seasonId) async {
    final json = await _getJson('$_base/series/season/$seasonId/$_code');
    final eps = json['episodes'];
    if (eps is! List) return const [];
    return eps
        .whereType<Map>()
        .map((e) => CinemaEpisode.fromJson(Map<String, dynamic>.from(e)))
        .toList(growable: false)
      ..sort((a, b) => a.number.compareTo(b.number));
  }

  // ── internals ──────────────────────────────────────────────────────────

  List<CinemaItem> _items(dynamic data) {
    if (data is! List) return const [];
    return data
        .whereType<Map>()
        .map((m) => CinemaItem.fromJson(Map<String, dynamic>.from(m)))
        .where((i) => i.id != 0 && i.title.isNotEmpty)
        .toList(growable: false);
  }

  Future<Map<String, dynamic>> _getJson(String url) async {
    try {
      final res = await _client.get(Uri.parse(url), headers: _headers).timeout(_timeout);
      if (res.statusCode == 404) {
        throw const ServerException('error_not_found', statusCode: 404);
      }
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
      throw ServerException('cinema_unavailable', cause: e);
    }
  }

  /// Detail responses put the title's id at the top level; 0 means "not a real
  /// title" (e.g. an error envelope).
  static int asMapId(Map<String, dynamic> json) {
    final v = json['id'];
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }
}
