/// Top-level filter on the Cinema page. [all] merges the movie and series
/// catalogues; the other two scope to a single EgyBest listing type.
///
/// Mirrors Browse's `BrowseCategory` so the two tabs feel identical, but is a
/// separate type so the Cinema feature stays fully isolated.
enum CinemaCategory {
  all,
  movies,
  series;

  /// The EgyBest listing kinds this category spans (`movies` / `series`).
  List<String> get listings => switch (this) {
    CinemaCategory.all => const ['movies', 'series'],
    CinemaCategory.movies => const ['movies'],
    CinemaCategory.series => const ['series'],
  };
}
