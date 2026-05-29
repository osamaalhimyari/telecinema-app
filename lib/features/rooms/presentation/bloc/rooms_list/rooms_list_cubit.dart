import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '/core/UseCase/usecase.dart';
import '../../../data/datasources/home_socket_datasource.dart';
import '../../../domain/usecases/get_rooms_usecase.dart';
import 'rooms_list_state.dart';

/// Owns the home grid: fetches the room catalogue over HTTP and then overlays
/// live viewer counts from the `home` socket channel, so a card's "watching"
/// badge updates in real time without a refresh.
class RoomsListCubit extends Cubit<RoomsListState> {
  RoomsListCubit(this._getRooms, this._home) : super(const RoomsListState());

  final GetRoomsUseCase _getRooms;
  final HomeSocketDataSource _home;

  StreamSubscription<Map<String, int>>? _countsSub;

  Future<void> load() async {
    if (state.isLoading) return;
    emit(state.copyWith(status: RoomsListStatus.loading, clearError: true));

    final result = await _getRooms(const NoParams());
    result.fold(
      (failure) => emit(
        state.copyWith(status: RoomsListStatus.failure, errorKey: failure.message),
      ),
      (rooms) {
        // Drop a category filter the refreshed catalogue no longer contains,
        // otherwise it would strand the grid empty with no chip to reset it.
        final keepCategory = state.categoryFilter == null ||
            rooms.any((r) => r.category == state.categoryFilter);
        emit(state.copyWith(
          status: RoomsListStatus.success,
          rooms: rooms,
          clearError: true,
          clearCategory: !keepCategory,
        ));
        _startLiveCounts();
      },
    );
  }

  Future<void> refresh() => load();

  /// Updates the free-text search. Filtering happens in [RoomsListState.visibleRooms];
  /// the full [RoomsListState.rooms] list (and its live counts) is untouched.
  void setQuery(String query) => emit(state.copyWith(query: query));

  /// Selects a category key, or null to clear the filter ("all categories").
  void setCategory(String? category) =>
      emit(state.copyWith(categoryFilter: category, clearCategory: category == null));

  void _startLiveCounts() {
    _home.start();
    _countsSub ??= _home.viewerCounts.listen(_applyCounts);
  }

  void _applyCounts(Map<String, int> counts) {
    if (state.rooms.isEmpty) return;
    final updated = [
      for (final room in state.rooms)
        counts.containsKey(room.slug) ? room.copyWith(viewerCount: counts[room.slug]) : room,
    ];
    emit(state.copyWith(rooms: updated));
  }

  @override
  Future<void> close() {
    _countsSub?.cancel();
    return super.close();
  }
}
