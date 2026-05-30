import 'package:equatable/equatable.dart';

/// One tile in the Browse grid, parsed from a Cinemeta `metas[]` entry.
///
/// [id] is the IMDB id (e.g. `tt1375666`) — it is both the grid key and the
/// query used later to find a torrent. [type] is `movie` or `series`.
class CatalogItem extends Equatable {
  const CatalogItem({
    required this.id,
    required this.name,
    required this.type,
    this.poster,
    this.imdbRating,
    this.releaseInfo,
    this.genres = const [],
  });

  final String id;
  final String name;
  final String type;
  final String? poster;

  /// IMDB rating as text (e.g. `8.8`), or null when the catalogue omits it.
  final String? imdbRating;

  /// Release year as text (e.g. `2010`).
  final String? releaseInfo;

  final List<String> genres;

  bool get isSeries => type == 'series';

  @override
  List<Object?> get props => [id, name, type, poster, imdbRating, releaseInfo, genres];
}
