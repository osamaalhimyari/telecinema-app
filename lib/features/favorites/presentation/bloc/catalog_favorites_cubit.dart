import 'package:flutter_bloc/flutter_bloc.dart';

import '/core/errors/exceptions.dart';
import '../../../browse/domain/entities/catalog_item.dart';
import '../../data/datasources/favorites_remote_datasource.dart';
import 'catalog_favorites_state.dart';

/// Drives the server-backed catalogue favorites — a single account-less global
/// list of saved movies/series. Registered as an app-global singleton so the
/// Browse poster hearts and the Favorites tab share one source of truth.
///
/// Toggling is optimistic: the UI updates immediately and the change is sent to
/// the server in the background; a failed call is rolled back so the heart
/// never lies about what is actually saved.
class CatalogFavoritesCubit extends Cubit<CatalogFavoritesState> {
  CatalogFavoritesCubit(this._remote) : super(const CatalogFavoritesState());

  final FavoritesRemoteDataSource _remote;

  /// Loads the saved list from the server. Called once at startup and on
  /// pull-to-refresh in the Favorites tab.
  Future<void> load() async {
    emit(state.copyWith(status: CatalogFavoritesStatus.loading, clearError: true));
    try {
      final items = await _remote.list();
      emit(
        state.copyWith(
          status: CatalogFavoritesStatus.success,
          items: items,
          clearError: true,
        ),
      );
    } on ServerException catch (e) {
      emit(state.copyWith(status: CatalogFavoritesStatus.failure, errorKey: e.message));
    } catch (_) {
      emit(state.copyWith(status: CatalogFavoritesStatus.failure, errorKey: 'error_unknown'));
    }
  }

  bool isFavorite(String id) => state.isFavorite(id);

  /// Stars or un-stars [item] optimistically, then syncs the server. On failure
  /// the local change is reverted.
  Future<void> toggle(CatalogItem item) async {
    if (item.id.isEmpty) return;
    final wasFavorite = state.isFavorite(item.id);
    final previous = state.items;

    final next = wasFavorite
        ? previous.where((i) => i.id != item.id).toList()
        : [item, ...previous.where((i) => i.id != item.id)];
    emit(state.copyWith(status: CatalogFavoritesStatus.success, items: next));

    try {
      if (wasFavorite) {
        await _remote.remove(item.id);
      } else {
        await _remote.add(item);
      }
    } catch (_) {
      // Roll back to what the server still holds.
      emit(state.copyWith(items: previous));
      rethrow;
    }
  }
}
