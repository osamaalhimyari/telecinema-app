import 'package:flutter_bloc/flutter_bloc.dart';

import '/logic/storage/key_value_storage.dart';
import '/logic/storage/shared_prefs_storage.dart';
import 'favorites_state.dart';

/// Local-only favorites + recently-watched rooms, keyed by room slug and
/// persisted through [KeyValueStorage]. Registered as an app-global singleton
/// so the home grid, room cards and the watch screen share one source of truth.
class FavoritesCubit extends Cubit<FavoritesState> {
  FavoritesCubit(this._storage)
    : super(
        FavoritesState(
          favorites: (_storage.getStringList(StorageKeys.favorites) ?? const [])
              .toSet(),
          recents: _storage.getStringList(StorageKeys.recentSlugs) ?? const [],
        ),
      );

  final KeyValueStorage _storage;

  /// How many recently-watched rooms to remember.
  static const _maxRecents = 20;

  bool isFavorite(String slug) => state.favorites.contains(slug);

  /// Stars or un-stars [slug] and persists the new set.
  Future<void> toggle(String slug) async {
    if (slug.isEmpty) return;
    final next = Set<String>.of(state.favorites);
    if (!next.add(slug)) next.remove(slug);
    emit(state.copyWith(favorites: next));
    await _storage.setStringList(StorageKeys.favorites, next.toList());
  }

  /// Records a room as recently watched: most-recent first, de-duplicated and
  /// capped at [_maxRecents]. A no-op when the room is already at the front.
  Future<void> recordRecent(String slug) async {
    if (slug.isEmpty) return;
    if (state.recents.isNotEmpty && state.recents.first == slug) return;
    final next = [slug, ...state.recents.where((s) => s != slug)];
    if (next.length > _maxRecents) next.removeRange(_maxRecents, next.length);
    emit(state.copyWith(recents: next));
    await _storage.setStringList(StorageKeys.recentSlugs, next);
  }
}
