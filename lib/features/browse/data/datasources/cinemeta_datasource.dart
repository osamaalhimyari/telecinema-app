import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '/core/errors/exceptions.dart';
import '../../domain/entities/catalog_item.dart';
import '../../domain/entities/episode_info.dart';
import '../../domain/entities/meta_detail.dart';
import '../json_parse.dart';

/// Reads the public Cinemeta catalogue (Stremio's metadata addon). No auth, no
/// `{success,data}` envelope — just JSON over HTTPS — so this talks to
/// `package:http` directly rather than the app's backend [ApiClient].
///
/// Throws [ServerException] with a stable error key; the repository turns those
/// into [Failure]s.
abstract class CinemetaDataSource {
  Future<List<CatalogItem>> catalog({required String type, int skip = 0});
  Future<List<CatalogItem>> search({required String type, required String query});
  Future<MetaDetail> detail({required String type, required String id});
}

class CinemetaDataSourceImpl implements CinemetaDataSource {
  CinemetaDataSourceImpl([http.Client? client]) : _client = client ?? http.Client();

  final http.Client _client;

  static const String _base = 'https://v3-cinemeta.strem.io';
  static const Duration _timeout = Duration(seconds: 20);

  @override
  Future<List<CatalogItem>> catalog({required String type, int skip = 0}) async {
    // `top.json` for the first page, `top/skip=N.json` thereafter.
    final path = skip > 0
        ? '/catalog/$type/top/skip=$skip.json'
        : '/catalog/$type/top.json';
    return _metas('$_base$path', type);
  }

  @override
  Future<List<CatalogItem>> search({required String type, required String query}) {
    final q = Uri.encodeComponent(query);
    return _metas('$_base/catalog/$type/top/search=$q.json', type);
  }

  @override
  Future<MetaDetail> detail({required String type, required String id}) async {
    final json = await _getJson('$_base/meta/$type/${Uri.encodeComponent(id)}.json');
    final meta = json['meta'];
    if (meta is! Map) throw const ServerException('error_not_found');
    final m = Map<String, dynamic>.from(meta);
    return MetaDetail(
      id: asString(m['id'] ?? m['imdb_id']) ?? id,
      name: asString(m['name']) ?? '',
      type: asString(m['type']) ?? type,
      poster: asString(m['poster']),
      background: asString(m['background']),
      description: asString(m['description']),
      imdbRating: asString(m['imdbRating']),
      releaseInfo: asString(m['releaseInfo'] ?? m['year']),
      runtime: asString(m['runtime']),
      genres: asStringList(m['genres'] ?? m['genre']),
      cast: asStringList(m['cast']),
      episodes: _episodes(m['videos']),
    );
  }

  /// Parses Cinemeta's `videos[]` into a sorted episode list. Skips specials
  /// (season 0) and malformed entries, and de-duplicates by season+episode.
  List<EpisodeInfo> _episodes(dynamic videos) {
    if (videos is! List) return const [];
    final seen = <String>{};
    final out = <EpisodeInfo>[];
    for (final raw in videos.whereType<Map>()) {
      final v = Map<String, dynamic>.from(raw);
      final season = asInt(v['season']);
      final episode = asInt(v['episode'] ?? v['number']);
      if (season < 1 || episode < 1) continue;
      if (!seen.add('${season}x$episode')) continue;
      out.add(EpisodeInfo(
        season: season,
        episode: episode,
        name: asString(v['name'] ?? v['title']),
      ));
    }
    out.sort((a, b) =>
        a.season != b.season ? a.season.compareTo(b.season) : a.episode.compareTo(b.episode));
    return out;
  }

  Future<List<CatalogItem>> _metas(String url, String fallbackType) async {
    final json = await _getJson(url);
    final metas = json['metas'];
    if (metas is! List) return const [];
    return metas
        .whereType<Map>()
        .map((raw) => _item(Map<String, dynamic>.from(raw), fallbackType))
        .where((i) => i.id.isNotEmpty && i.name.isNotEmpty)
        .toList(growable: false);
  }

  CatalogItem _item(Map<String, dynamic> m, String fallbackType) => CatalogItem(
    id: asString(m['id'] ?? m['imdb_id']) ?? '',
    name: asString(m['name']) ?? '',
    type: asString(m['type']) ?? fallbackType,
    poster: asString(m['poster']),
    imdbRating: asString(m['imdbRating']),
    releaseInfo: asString(m['releaseInfo'] ?? m['year']),
    genres: asStringList(m['genres'] ?? m['genre']),
  );

  Future<Map<String, dynamic>> _getJson(String url) async {
    try {
      final res = await _client.get(Uri.parse(url)).timeout(_timeout);
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
      throw ServerException('error_unknown', cause: e);
    }
  }
}
