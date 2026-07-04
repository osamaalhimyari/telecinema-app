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
    this.source = 'cinemeta',
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

  /// Which catalogue this title came from — `cinemeta` (the IMDB/Browse tab,
  /// the default for every legacy favorite) or `egybest` (the Cinema tab). The
  /// Favorites tab uses it to open the right detail page and to separate the two
  /// lists. Stored inside the favorite JSON, so no backend change is needed.
  final String source;

  bool get isSeries => type == 'series';

  /// True for an EgyBest (Cinema-tab) favorite.
  bool get isEgybest => source == 'egybest';

  /// Serializes the tile to the JSON saved as a server favorite (and rebuilt
  /// from it via [CatalogItem.fromJson]). Mirrors the catalogue shape.
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'type': type,
    if (poster != null) 'poster': poster,
    if (imdbRating != null) 'imdbRating': imdbRating,
    if (releaseInfo != null) 'releaseInfo': releaseInfo,
    'genres': genres,
    'source': source,
  };

  /// Rebuilds a tile from saved favorite JSON. Tolerant of missing/loosely
  /// typed fields, matching what the catalogue itself can omit.
  factory CatalogItem.fromJson(Map<String, dynamic> json) {
    String? str(dynamic v) {
      final s = v?.toString().trim();
      return (s == null || s.isEmpty) ? null : s;
    }

    return CatalogItem(
      id: str(json['id'] ?? json['imdb_id']) ?? '',
      name: str(json['name']) ?? '',
      type: str(json['type']) ?? 'movie',
      poster: str(json['poster']),
      imdbRating: str(json['imdbRating']),
      releaseInfo: str(json['releaseInfo'] ?? json['year']),
      genres: json['genres'] is List
          ? (json['genres'] as List)
                .map((e) => e?.toString().trim() ?? '')
                .where((s) => s.isNotEmpty)
                .toList(growable: false)
          : const [],
      // Legacy favorites (saved before the Cinema tab) have no `source` — they
      // are all Cinemeta titles, so default to it.
      source: str(json['source']) ?? 'cinemeta',
    );
  }

  @override
  List<Object?> get props => [id, name, type, poster, imdbRating, releaseInfo, genres, source];
}
