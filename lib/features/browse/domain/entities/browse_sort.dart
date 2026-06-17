/// How the Browse grid orders the loaded titles. Applied locally (like the genre
/// filter) over everything fetched so far — the Cinemeta catalogue itself only
/// serves its fixed "top" order, so [defaultOrder] is that as-fetched order.
enum BrowseSort {
  /// As returned by the catalogue (popularity / recency) — the default.
  defaultOrder,

  /// Newest release year first ([CatalogItem.releaseInfo]).
  releaseDate,

  /// Highest IMDB rating first ([CatalogItem.imdbRating]).
  rating,
}
