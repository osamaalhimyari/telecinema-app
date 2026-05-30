import 'package:equatable/equatable.dart';

import '../../../domain/entities/browse_category.dart';
import '../../../domain/entities/catalog_item.dart';

enum BrowseStatus { initial, loading, success, failure }

class BrowseState extends Equatable {
  const BrowseState({
    this.status = BrowseStatus.initial,
    this.category = BrowseCategory.all,
    this.query = '',
    this.items = const [],
    this.selectedGenre,
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

  /// Items after the local genre filter.
  List<CatalogItem> get visibleItems {
    if (selectedGenre == null) return items;
    return items.where((i) => i.genres.contains(selectedGenre)).toList();
  }

  BrowseState copyWith({
    BrowseStatus? status,
    BrowseCategory? category,
    String? query,
    List<CatalogItem>? items,
    String? selectedGenre,
    bool clearGenre = false,
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
    skip,
    hasMore,
    loadingMore,
    errorKey,
  ];
}
