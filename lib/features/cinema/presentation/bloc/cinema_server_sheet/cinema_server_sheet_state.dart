import 'package:equatable/equatable.dart';

import '../../../domain/entities/cinema_server.dart';

/// State for the server picker sheet: the precomputed (reliability-sorted,
/// de-duplicated) list of servers, plus the index currently being resolved.
class CinemaServerSheetState extends Equatable {
  const CinemaServerSheetState({
    this.servers = const [],
    this.resolving,
  });

  /// The precomputed `_ordered` list — most-reliable first.
  final List<CinemaServer> servers;

  /// Index of the server currently being resolved, or null.
  final int? resolving;

  CinemaServerSheetState copyWith({
    List<CinemaServer>? servers,
    int? resolving,
    bool clearResolving = false,
  }) {
    return CinemaServerSheetState(
      servers: servers ?? this.servers,
      resolving: clearResolving ? null : (resolving ?? this.resolving),
    );
  }

  @override
  List<Object?> get props => [servers, resolving];
}
