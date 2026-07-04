import 'package:equatable/equatable.dart';

import '/features/browse/domain/entities/browse_category.dart';
import '/features/browse/domain/entities/browse_sort.dart';
import '/features/browse/domain/entities/catalog_item.dart';

enum DiscoverStatus { initial, loading, success, failure }

/// State for the unified Browse grid: one feed merging the Cinemeta (IMDB) and
/// EgyBest (Cinema) catalogues. Each source paginates independently, so two
/// cursors are tracked; items carry a `source` so the card badge and the tap
/// target (which detail page) are known.
class DiscoverState extends Equatable {
  const DiscoverState({
    this.status = DiscoverStatus.initial,
    this.category = BrowseCategory.all,
    this.query = '',
    this.items = const [],
    this.selectedGenre,
    this.sort = BrowseSort.defaultOrder,
    this.sortAscending = false,
    this.cinemetaSkip = 0,
    this.cinemaPage = 1,
    this.cinemetaHasMore = true,
    this.cinemaHasMore = true,
    this.loadingMore = false,
    this.errorKey,
  });

  final DiscoverStatus status;
  final BrowseCategory category;
  final String query;

  /// The merged, de-duplicated, shuffled feed loaded so far.
  final List<CatalogItem> items;
  final String? selectedGenre;

  /// Local ordering applied to [visibleItems].
  final BrowseSort sort;

  /// Sort direction for [sort] (ignored by [BrowseSort.defaultOrder]). Default
  /// false = descending — newest release / highest rating first.
  final bool sortAscending;

  /// Cinemeta `skip` offset and EgyBest `page` for the next page each.
  final int cinemetaSkip;
  final int cinemaPage;
  final bool cinemetaHasMore;
  final bool cinemaHasMore;

  final bool loadingMore;
  final String? errorKey;

  bool get hasMore => cinemetaHasMore || cinemaHasMore;

  List<String> get genres {
    final set = <String>{};
    for (final item in items) {
      set.addAll(item.genres);
    }
    return set.toList()..sort();
  }

  /// Items after the local genre filter and the chosen [sort]. Sorting returns a
  /// copy (never mutates [items]); titles missing the sort field fall to the end.
  /// Applies to everything loaded so far, re-sorting after each "Load more".
  List<CatalogItem> get visibleItems {
    final filtered = selectedGenre == null
        ? items
        : items.where((i) => i.genres.contains(selectedGenre)).toList();
    switch (sort) {
      case BrowseSort.defaultOrder:
        return filtered;
      case BrowseSort.releaseDate:
        final asc = [...filtered]..sort((a, b) => _year(a).compareTo(_year(b)));
        return sortAscending ? asc : asc.reversed.toList();
      case BrowseSort.rating:
        final asc = [...filtered]..sort((a, b) => _rating(a).compareTo(_rating(b)));
        return sortAscending ? asc : asc.reversed.toList();
    }
  }

  /// Release year parsed from `releaseInfo` (e.g. `2010`, `2010–2014`); -1 when
  /// absent, so unknown years sort last under newest-first.
  static int _year(CatalogItem i) {
    final raw = i.releaseInfo;
    if (raw == null) return -1;
    final match = RegExp(r'\d{4}').firstMatch(raw);
    return match == null ? -1 : int.parse(match.group(0)!);
  }

  /// IMDB rating parsed from text (e.g. `8.8`); -1 when absent (sorts last).
  static double _rating(CatalogItem i) {
    final raw = i.imdbRating;
    if (raw == null) return -1;
    return double.tryParse(raw) ?? -1;
  }

  DiscoverState copyWith({
    DiscoverStatus? status,
    BrowseCategory? category,
    String? query,
    List<CatalogItem>? items,
    String? selectedGenre,
    bool clearGenre = false,
    BrowseSort? sort,
    bool? sortAscending,
    int? cinemetaSkip,
    int? cinemaPage,
    bool? cinemetaHasMore,
    bool? cinemaHasMore,
    bool? loadingMore,
    String? errorKey,
    bool clearError = false,
  }) {
    return DiscoverState(
      status: status ?? this.status,
      category: category ?? this.category,
      query: query ?? this.query,
      items: items ?? this.items,
      selectedGenre: clearGenre ? null : (selectedGenre ?? this.selectedGenre),
      sort: sort ?? this.sort,
      sortAscending: sortAscending ?? this.sortAscending,
      cinemetaSkip: cinemetaSkip ?? this.cinemetaSkip,
      cinemaPage: cinemaPage ?? this.cinemaPage,
      cinemetaHasMore: cinemetaHasMore ?? this.cinemetaHasMore,
      cinemaHasMore: cinemaHasMore ?? this.cinemaHasMore,
      loadingMore: loadingMore ?? this.loadingMore,
      errorKey: clearError ? null : (errorKey ?? this.errorKey),
    );
  }

  @override
  List<Object?> get props => [
    status,
    category,
    query,
    items,
    selectedGenre,
    sort,
    sortAscending,
    cinemetaSkip,
    cinemaPage,
    cinemetaHasMore,
    cinemaHasMore,
    loadingMore,
    errorKey,
  ];
}
