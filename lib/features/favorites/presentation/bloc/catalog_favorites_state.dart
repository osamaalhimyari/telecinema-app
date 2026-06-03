import 'package:equatable/equatable.dart';

import '../../../browse/domain/entities/catalog_item.dart';

enum CatalogFavoritesStatus { initial, loading, success, failure }

/// State for the server-backed catalogue favorites (saved movies/series). The
/// [ids] set mirrors [items] so a poster's heart can check membership in O(1).
class CatalogFavoritesState extends Equatable {
  const CatalogFavoritesState({
    this.status = CatalogFavoritesStatus.initial,
    this.items = const [],
    this.errorKey,
  });

  final CatalogFavoritesStatus status;

  /// Saved titles, most-recently saved first.
  final List<CatalogItem> items;

  final String? errorKey;

  /// IMDB ids of every saved title — drives the heart's filled/outline state.
  Set<String> get ids => items.map((i) => i.id).toSet();

  bool isFavorite(String id) => items.any((i) => i.id == id);

  CatalogFavoritesState copyWith({
    CatalogFavoritesStatus? status,
    List<CatalogItem>? items,
    String? errorKey,
    bool clearError = false,
  }) {
    return CatalogFavoritesState(
      status: status ?? this.status,
      items: items ?? this.items,
      errorKey: clearError ? null : (errorKey ?? this.errorKey),
    );
  }

  @override
  List<Object?> get props => [status, items, errorKey];
}
