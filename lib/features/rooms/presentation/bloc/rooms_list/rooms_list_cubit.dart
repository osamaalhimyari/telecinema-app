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
        emit(state.copyWith(status: RoomsListStatus.success, rooms: rooms, clearError: true));
        _startLiveCounts();
      },
    );
  }

  Future<void> refresh() => load();

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
