import 'package:equatable/equatable.dart';

import '../../domain/entities/server_operation.dart';

/// The merged, newest-first list of this device's transfers (local uploads on
/// top, then server downloads/torrents).
class OperationsState extends Equatable {
  const OperationsState({this.operations = const []});

  final List<ServerOperation> operations;

  /// Operations still running — drives the app-bar badge count.
  int get activeCount => operations.where((o) => o.isActive).length;

  bool get hasAny => operations.isNotEmpty;
  bool get hasActive => activeCount > 0;

  OperationsState copyWith({List<ServerOperation>? operations}) =>
      OperationsState(operations: operations ?? this.operations);

  @override
  List<Object?> get props => [operations];
}
