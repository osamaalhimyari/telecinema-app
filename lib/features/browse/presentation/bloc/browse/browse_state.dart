import 'package:equatable/equatable.dart';

import '../../../domain/entities/browse_category.dart';
import '../../../domain/entities/browse_sort.dart';
import '../../../domain/entities/catalog_item.dart';

enum BrowseStatus { initial, loading, success, failure }

class BrowseState extends Equatable {
  const BrowseState({
    this.status = BrowseStatus.initial,
    this.category = BrowseCategory.all,
    this.query = '',
    this.items = const [],
    this.selectedGenre,
    this.sort = BrowseSort.defaultOrder,
    this.skip = 0,
    this.hasMore = true,
    this.loadingMore = false,
    this.errorKey,
  });

  final BrowseStatus status;
  final BrowseCategory category;

  /// Active title search (empty = browse the `top` catalogue).
  final String query;

  /// Everything loaded so far for the active category/query, de-duplicated by id.
  final List<CatalogItem> items;

  /// Active genre chip, or null for "all genres" (a purely local filter).
  final String? selectedGenre;

  /// Local ordering applied to [visibleItems].
  final BrowseSort sort;

  /// Cinemeta `skip` offset for the next page.
  final int skip;

  final bool hasMore;
  final bool loadingMore;
  final String? errorKey;

  bool get isLoading => status == BrowseStatus.loading;

  /// Distinct genres across loaded items — drives the genre chips.
  List<String> get genres {
    final set = <String>{};
    for (final item in items) {
      set.addAll(item.genres);
    }
    final list = set.toList()..sort();
    return list;
  }

  /// Items after the local genre filter and the chosen [sort]. Sorting never
  /// mutates [items] — release/rating return a sorted copy; titles missing the
  /// sort field fall to the end. Applies to everything loaded so far (load more
  /// then re-sorts the larger list).
  List<CatalogItem> get visibleItems {
    final filtered = selectedGenre == null
        ? items
        : items.where((i) => i.genres.contains(selectedGenre)).toList();
    switch (sort) {
      case BrowseSort.defaultOrder:
        return filtered;
      case BrowseSort.releaseDate:
        return [...filtered]..sort((a, b) => _year(b).compareTo(_year(a)));
      case BrowseSort.rating:
        return [...filtered]..sort((a, b) => _rating(b).compareTo(_rating(a)));
    }
  }

  /// Release year parsed from `releaseInfo` (e.g. `2010`, `2010–2014`); -1 when
  /// absent, so unknown years sort last under a newest-first order.
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

  BrowseState copyWith({
    BrowseStatus? status,
    BrowseCategory? category,
    String? query,
    List<CatalogItem>? items,
    String? selectedGenre,
    bool clearGenre = false,
    BrowseSort? sort,
    int? skip,
    bool? hasMore,
    bool? loadingMore,
    String? errorKey,
    bool clearError = false,
  }) {
    return BrowseState(
      status: status ?? this.status,
      category: category ?? this.category,
      query: query ?? this.query,
      items: items ?? this.items,
      selectedGenre: clearGenre ? null : (selectedGenre ?? this.selectedGenre),
      sort: sort ?? this.sort,
      skip: skip ?? this.skip,
      hasMore: hasMore ?? this.hasMore,
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
    skip,
    hasMore,
    loadingMore,
    errorKey,
  ];
}
