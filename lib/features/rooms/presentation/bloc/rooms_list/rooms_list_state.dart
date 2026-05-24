import 'package:equatable/equatable.dart';

import '../../../domain/entities/room.dart';

enum RoomsListStatus { initial, loading, success, failure }

class RoomsListState extends Equatable {
  const RoomsListState({
    this.status = RoomsListStatus.initial,
    this.rooms = const [],
    this.errorKey,
  });

  final RoomsListStatus status;
  final List<Room> rooms;
  final String? errorKey;

  bool get isLoading => status == RoomsListStatus.loading;

  RoomsListState copyWith({
    RoomsListStatus? status,
    List<Room>? rooms,
    String? errorKey,
    bool clearError = false,
  }) {
    return RoomsListState(
      status: status ?? this.status,
      rooms: rooms ?? this.rooms,
      errorKey: clearError ? null : (errorKey ?? this.errorKey),
    );
  }

  @override
  List<Object?> get props => [status, rooms, errorKey];
}
