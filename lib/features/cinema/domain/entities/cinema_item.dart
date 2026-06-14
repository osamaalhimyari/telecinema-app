import 'package:equatable/equatable.dart';

import '/features/browse/domain/entities/catalog_item.dart';
import '../../data/cinema_json.dart';

/// One tile in the Cinema grid, parsed from an EgyBest listing/search entry.
///
/// [id] is the EgyBest internal media id (e.g. `54262`) — it is both the grid
/// key and the value passed to `media/detail/{id}` (movies) or
/// `series/show/{id}` (series). [type] is `movie`, `serie` or `anime`.
///
/// Deliberately a *separate* entity from Browse's `CatalogItem` so the feature
/// stays isolated; [toCatalogItem] bridges to the shared favorites system,
/// tagging the saved record with `source: 'egybest'` so the two catalogues can
/// be told apart in the Favorites tab.
class CinemaItem extends Equatable {
  const CinemaItem({
    required this.id,
    required this.title,
    required this.type,
    this.poster,
    this.rating,
    this.subtitle,
    this.imdbId,
    this.genres = const [],
  });

  final int id;
  final String title;

  /// `movie` | `serie` | `anime`.
  final String type;
  final String? poster;

  /// Rating as text (e.g. `8.0`), or null when the listing omits it.
  final String? rating;

  /// The badge text EgyBest ships with the tile — a quality (`1080p WEB-DL`)
  /// for movies, an episode hint for series, or null.
  final String? subtitle;

  /// IMDB id (`tt…`) — present only on search results, carried into the room so
  /// it can later find subtitles.
  final String? imdbId;

  final List<String> genres;

  bool get isSeries => type == 'serie' || type == 'series' || type == 'anime';

  /// `media/detail/{id}` returns `movie`; series go through `series/show/{id}`.
  /// Browse's detail/route expects `movie` | `series`.
  String get routeType => isSeries ? 'series' : 'movie';

  /// EgyBest listings use `title` for movies and `name` for series/anime.
  factory CinemaItem.fromJson(Map<String, dynamic> json) {
    return CinemaItem(
      id: asInt(json['id']),
      title: asString(json['title'] ?? json['name']) ?? '',
      // Listings ship `movie`/`serie`/`anime`; search capitalizes
      // (`Movie`/`Series`) — normalize so the series checks are reliable.
      type: (asString(json['type']) ?? 'movie').toLowerCase(),
      poster: httpsImage(asString(json['poster_path'] ?? json['poster'])),
      rating: asRating(json['vote_average']),
      subtitle: asString(json['subtitle']),
      imdbId: asString(json['imdb_external_id']),
      genres: asGenres(json['genres'], json['genreslist']),
    );
  }

  /// Bridges to the shared favorites list. Stamps `source: 'egybest'` and stores
  /// the id as a string so the heart and the Favorites tab can round-trip it.
  CatalogItem toCatalogItem() => CatalogItem(
    id: id.toString(),
    name: title,
    type: routeType,
    poster: poster,
    imdbRating: rating,
    releaseInfo: subtitle,
    genres: genres,
    source: 'egybest',
  );

  /// Rebuilds a tile from a saved favorite (so the Favorites tab can open the
  /// Cinema detail page for an EgyBest entry).
  factory CinemaItem.fromCatalogItem(CatalogItem item) => CinemaItem(
    id: int.tryParse(item.id) ?? 0,
    title: item.name,
    type: item.type,
    poster: item.poster,
    rating: item.imdbRating,
    subtitle: item.releaseInfo,
    genres: item.genres,
  );

  @override
  List<Object?> get props => [id, title, type, poster, rating, subtitle, imdbId, genres];
}
