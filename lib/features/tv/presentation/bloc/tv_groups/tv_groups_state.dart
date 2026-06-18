import 'package:equatable/equatable.dart';

import '../../../domain/entities/tv_node.dart';

enum TvGroupsStatus { initial, loading, success, failure }

class TvGroupsState extends Equatable {
  const TvGroupsState({
    this.status = TvGroupsStatus.initial,
    this.groups = const [],
    this.errorKey,
  });

  final TvGroupsStatus status;

  /// Top-level category groups (each drills down to its channels).
  final List<TvNode> groups;

  final String? errorKey;

  bool get isLoading => status == TvGroupsStatus.loading;

  TvGroupsState copyWith({
    TvGroupsStatus? status,
    List<TvNode>? groups,
    String? errorKey,
    bool clearError = false,
  }) {
    return TvGroupsState(
      status: status ?? this.status,
      groups: groups ?? this.groups,
      errorKey: clearError ? null : (errorKey ?? this.errorKey),
    );
  }

  @override
  List<Object?> get props => [status, groups, errorKey];
}
