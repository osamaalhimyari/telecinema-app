import 'package:equatable/equatable.dart';

import '../../../domain/entities/room.dart';

enum RoomsListStatus { initial, loading, success, failure }

class RoomsListState extends Equatable {
  const RoomsListState({
    this.status = RoomsListStatus.initial,
    this.rooms = const [],
    this.errorKey,
    this.query = '',
    this.categoryFilter,
  });

  final RoomsListStatus status;
  final List<Room> rooms;
  final String? errorKey;

  /// Active free-text search over room names.
  final String query;

  /// Active category filter (a category key), or null for "all categories".
  final String? categoryFilter;

  bool get isLoading => status == RoomsListStatus.loading;

  /// Rooms after the active search query + category filter. Derived (never
  /// stored back into [rooms]) so live viewer-count updates keep flowing across
  /// the full catalogue regardless of what is filtered out.
  List<Room> get visibleRooms {
    final q = query.trim().toLowerCase();
    if (q.isEmpty && categoryFilter == null) return rooms;
    return rooms.where((r) {
      final matchesQuery = q.isEmpty || r.name.toLowerCase().contains(q);
      final matchesCategory = categoryFilter == null || r.category == categoryFilter;
      return matchesQuery && matchesCategory;
    }).toList();
  }

  /// Distinct category keys present across the full catalogue — drives the chips.
  List<String> get categories =>
      rooms.map((r) => r.category).whereType<String>().toSet().toList()..sort();

  RoomsListState copyWith({
    RoomsListStatus? status,
    List<Room>? rooms,
    String? errorKey,
    bool clearError = false,
    String? query,
    String? categoryFilter,
    bool clearCategory = false,
  }) {
    return RoomsListState(
      status: status ?? this.status,
      rooms: rooms ?? this.rooms,
      errorKey: clearError ? null : (errorKey ?? this.errorKey),
      query: query ?? this.query,
      categoryFilter: clearCategory ? null : (categoryFilter ?? this.categoryFilter),
    );
  }

  @override
  List<Object?> get props => [status, rooms, errorKey, query, categoryFilter];
}
