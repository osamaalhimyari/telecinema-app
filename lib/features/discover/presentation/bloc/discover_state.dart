import 'package:equatable/equatable.dart';

import '/features/browse/domain/entities/browse_category.dart';
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

  List<CatalogItem> get visibleItems {
    if (selectedGenre == null) return items;
    return items.where((i) => i.genres.contains(selectedGenre)).toList();
  }

  DiscoverState copyWith({
    DiscoverStatus? status,
    BrowseCategory? category,
    String? query,
    List<CatalogItem>? items,
    String? selectedGenre,
    bool clearGenre = false,
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
    cinemetaSkip,
    cinemaPage,
    cinemetaHasMore,
    cinemaHasMore,
    loadingMore,
    errorKey,
  ];
}
