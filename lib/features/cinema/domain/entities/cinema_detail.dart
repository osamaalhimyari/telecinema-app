import 'package:equatable/equatable.dart';

import '../../data/cinema_json.dart';
import 'cinema_season.dart';
import 'cinema_server.dart';

/// Full title page data from `media/detail/{id}` (movie) or `series/show/{id}`
/// (series). A movie carries its [servers] directly; a series carries its
/// [seasons] (episodes — and their servers — are filled in lazily per season).
class CinemaDetail extends Equatable {
  const CinemaDetail({
    required this.id,
    required this.title,
    required this.type,
    this.poster,
    this.background,
    this.overview,
    this.rating,
    this.year,
    this.runtime,
    this.imdbId,
    this.tmdbId,
    this.genres = const [],
    this.servers = const [],
    this.seasons = const [],
  });

  final int id;
  final String title;

  /// `movie` | `series`.
  final String type;
  final String? poster;
  final String? background;
  final String? overview;
  final String? rating;
  final String? year;
  final String? runtime;

  /// IMDB id (`tt…`) — carried into the created room for subtitle search.
  final String? imdbId;
  final int? tmdbId;
  final List<String> genres;

  final List<CinemaServer> servers;
  final List<CinemaSeason> seasons;

  bool get isSeries => type == 'series' || seasons.isNotEmpty;

  factory CinemaDetail.movie(Map<String, dynamic> json) {
    return CinemaDetail(
      id: asInt(json['id']),
      title: asString(json['title'] ?? json['name']) ?? '',
      type: 'movie',
      poster: httpsImage(asString(json['poster_path'])),
      background: httpsImage(asString(json['backdrop_path'])),
      overview: asString(json['overview']),
      rating: asRating(json['vote_average']),
      year: _year(json['release_date']),
      runtime: _runtime(json['runtime']),
      imdbId: asString(json['imdb_external_id']),
      tmdbId: asInt(json['tmdb_id']) == 0 ? null : asInt(json['tmdb_id']),
      genres: asGenres(json['genres'], json['genreslist']),
      servers: CinemaServer.listFrom(json['videos']),
    );
  }

  factory CinemaDetail.series(Map<String, dynamic> json) {
    final seasons = json['seasons'];
    return CinemaDetail(
      id: asInt(json['id']),
      title: asString(json['name'] ?? json['title']) ?? '',
      type: 'series',
      poster: httpsImage(asString(json['poster_path'])),
      background: httpsImage(asString(json['backdrop_path'])),
      overview: asString(json['overview']),
      rating: asRating(json['vote_average']),
      year: _year(json['first_air_date']),
      imdbId: asString(json['imdb_external_id']),
      tmdbId: asInt(json['tmdb_id']) == 0 ? null : asInt(json['tmdb_id']),
      genres: asGenres(json['genres'], json['genreslist']),
      seasons: seasons is List
          ? (seasons
                .whereType<Map>()
                .map((s) => CinemaSeason.fromJson(Map<String, dynamic>.from(s)))
                .toList(growable: false)
              ..sort((a, b) => a.number.compareTo(b.number)))
          : const [],
    );
  }

  static String? _year(dynamic date) {
    final s = asString(date);
    if (s == null || s.length < 4) return null;
    return s.substring(0, 4);
  }

  static String? _runtime(dynamic minutes) {
    final n = asInt(minutes);
    if (n <= 0) return null;
    final h = n ~/ 60, m = n % 60;
    return h > 0 ? '${h}h ${m}m' : '${m}m';
  }

  @override
  List<Object?> get props => [id, title, type, servers, seasons];
}
