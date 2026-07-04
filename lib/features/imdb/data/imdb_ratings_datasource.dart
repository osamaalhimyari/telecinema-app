import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '/core/config/endpoints.dart';
import '/core/errors/exceptions.dart';
import '../domain/entities/imdb_episode.dart';
import '../domain/entities/imdb_season_result.dart';

/// ISOLATED on-device IMDb ratings source.
///
/// Hits IMDb's public GraphQL API (`api.graphql.imdb.com` — the same endpoint
/// imdb.com itself calls) rather than scraping the HTML pages, which sit behind
/// an AWS WAF bot-challenge no plain HTTP client can clear. One query returns a
/// title's season list, its overall rating and one season's episodes (number,
/// title, IMDb rating, vote count, still image, air date). Runs in the app like
/// the Cinemeta datasource — no backend, no key.
///
/// Throws [ServerException] with a stable key (`imdb_unavailable`) so the UI can
/// translate it; a title with no episodes (e.g. a movie) resolves to an empty
/// list rather than throwing.
abstract class ImdbRatingsDataSource {
  /// Loads [season]'s episodes for [imdbId] (a `tt…` id), plus the season list
  /// and the series rating.
  Future<ImdbSeasonResult> fetchSeason({required String imdbId, required int season});
}

class ImdbRatingsDataSourceImpl implements ImdbRatingsDataSource {
  ImdbRatingsDataSourceImpl([http.Client? client]) : _client = client ?? http.Client();

  final http.Client _client;

  static const _ua =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36';
  static const _timeout = Duration(seconds: 20);

  /// The query the site itself runs, trimmed to the fields the dashboard needs.
  /// Raw string so `$id` / `$season` stay literal GraphQL variables.
  static const _query = r'''
query Eps($id: ID!, $season: [String!]) {
  title(id: $id) {
    ratingsSummary { aggregateRating voteCount }
    episodes {
      seasons { number }
      episodes(first: 250, filter: {includeSeasons: $season}) {
        edges { node {
          series { episodeNumber { episodeNumber seasonNumber } }
          titleText { text }
          ratingsSummary { aggregateRating voteCount }
          primaryImage { url }
          releaseDate { year month day }
        } }
      }
    }
  }
}''';

  @override
  Future<ImdbSeasonResult> fetchSeason({required String imdbId, required int season}) async {
    final json = await _post(imdbId, season);
    final title = json['data']?['title'] as Map<String, dynamic>?;
    if (title == null) {
      // A valid-but-unknown id (or a title IMDb has no data for): show nothing.
      return ImdbSeasonResult(season: season, episodes: const [], seasons: const []);
    }

    final summary = title['ratingsSummary'] as Map<String, dynamic>?;
    final epsRoot = title['episodes'] as Map<String, dynamic>?;

    final seasons = <int>[];
    for (final s in (epsRoot?['seasons'] as List? ?? const [])) {
      final n = _asInt((s as Map)['number']);
      if (n != null) seasons.add(n);
    }
    seasons.sort();

    final episodes = <ImdbEpisode>[];
    for (final e in (epsRoot?['episodes']?['edges'] as List? ?? const [])) {
      final node = (e as Map)['node'] as Map<String, dynamic>?;
      if (node == null) continue;
      final ep = _parseEpisode(node, season);
      if (ep != null) episodes.add(ep);
    }
    episodes.sort((a, b) => a.episode.compareTo(b.episode));

    return ImdbSeasonResult(
      season: season,
      episodes: episodes,
      seasons: seasons,
      seriesRating: _asDouble(summary?['aggregateRating']),
      seriesVotes: _asInt(summary?['voteCount']),
    );
  }

  Future<Map<String, dynamic>> _post(String imdbId, int season) async {
    try {
      final res = await _client
          .post(
            Uri.parse(Endpoints.imdbGraphql),
            headers: {'User-Agent': _ua, 'Content-Type': 'application/json'},
            body: jsonEncode({
              'query': _query,
              'variables': {
                'id': imdbId,
                'season': ['$season'],
              },
            }),
          )
          .timeout(_timeout);
      if (res.statusCode != 200) throw const ServerException('imdb_unavailable');
      final body = jsonDecode(res.body);
      return body is Map<String, dynamic> ? body : <String, dynamic>{};
    } on ServerException {
      rethrow;
    } on TimeoutException {
      throw const ServerException('imdb_unavailable');
    } catch (_) {
      throw const ServerException('imdb_unavailable');
    }
  }

  ImdbEpisode? _parseEpisode(Map<String, dynamic> node, int fallbackSeason) {
    final epNum = node['series']?['episodeNumber'] as Map<String, dynamic>?;
    final episode = _asInt(epNum?['episodeNumber']);
    if (episode == null) return null;
    final summary = node['ratingsSummary'] as Map<String, dynamic>?;
    final image = node['primaryImage'] as Map<String, dynamic>?;
    return ImdbEpisode(
      season: _asInt(epNum?['seasonNumber']) ?? fallbackSeason,
      episode: episode,
      title: node['titleText']?['text'] as String?,
      rating: _asDouble(summary?['aggregateRating']),
      votes: _asInt(summary?['voteCount']),
      imageUrl: _sized(image?['url'] as String?),
      airDate: _date(node['releaseDate'] as Map<String, dynamic>?),
    );
  }

  /// Rewrites an Amazon media url to a card-sized (500px-wide) crop instead of
  /// the full-resolution original. Leaves unrecognised formats untouched.
  static String? _sized(String? url) {
    if (url == null) return null;
    return url.replaceFirst(RegExp(r'@+\._V1_.*?\.jpg$'), '@._V1_QL75_UX500_.jpg');
  }

  static DateTime? _date(Map<String, dynamic>? d) {
    final y = _asInt(d?['year']);
    if (y == null) return null;
    return DateTime(y, _asInt(d?['month']) ?? 1, _asInt(d?['day']) ?? 1);
  }

  static int? _asInt(dynamic v) =>
      v is int ? v : (v is num ? v.toInt() : (v is String ? int.tryParse(v) : null));

  static double? _asDouble(dynamic v) =>
      v is num ? v.toDouble() : (v is String ? double.tryParse(v) : null);
}
