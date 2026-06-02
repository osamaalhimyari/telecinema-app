/// The top-level filter on the Browse page. [all] merges the movie and series
/// catalogues; the other two scope to a single Cinemeta `type`.
enum BrowseCategory {
  all,
  movies,
  series;

  /// The Cinemeta `type` values this category spans (`movie` / `series`).
  List<String> get types => switch (this) {
    BrowseCategory.all => const ['movie', 'series'],
    BrowseCategory.movies => const ['movie'],
    BrowseCategory.series => const ['series'],
  };
}
