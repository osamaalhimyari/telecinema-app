import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/operations_datasource.dart';
import '../../domain/entities/server_operation.dart';
import 'operations_state.dart';

/// Singleton that keeps the "operations" panel live: it polls the server for
/// this device's transfers (downloads/torrents) and also holds in-app uploads
/// reported to it while they run. The Rooms app-bar button watches it for the
/// active-count badge; the panel sheet lists and cancels operations.
///
/// Polling is adaptive — fast while something is active so progress is smooth,
/// slow otherwise so an idle app isn't chatty. Local uploads update via direct
/// callbacks, not polling.
class OperationsCubit extends Cubit<OperationsState> {
  OperationsCubit(this._ds) : super(const OperationsState());

  final OperationsDataSource _ds;

  Timer? _timer;
  bool _started = false;

  /// Server operations from the last successful poll.
  List<ServerOperation> _server = const [];

  /// In-app uploads currently tracked (id → operation), with the Dio token that
  /// cancels each one's request.
  final Map<String, ServerOperation> _local = {};
  final Map<String, CancelToken> _localCancels = {};

  /// Server-operation ids the user dismissed with the panel's X. The server
  /// keeps returning a finished transfer until its own eviction timer drops it
  /// (there's no "delete operation" endpoint), so we filter these out of every
  /// merge to honor the dismiss immediately. Pruned in [_poll] once the server
  /// stops listing the id, so the set can't grow without bound.
  final Set<String> _dismissed = {};

  static const _fastInterval = Duration(seconds: 3);
  static const _idleInterval = Duration(seconds: 15);

  /// Begin polling. Safe to call more than once (no-op after the first).
  void start() {
    if (_started) return;
    _started = true;
    _poll();
  }

  Duration get _interval => state.hasActive ? _fastInterval : _idleInterval;

  void _schedule() {
    _timer?.cancel();
    _timer = Timer(_interval, _poll);
  }

  Future<void> _poll() async {
    try {
      _server = await _ds.list();
      // Drop dismissed ids the server no longer lists, so the set tracks only
      // currently-served operations.
      _dismissed.removeWhere((id) => !_server.any((o) => o.id == id));
      _emitMerged();
    } catch (_) {
      // A failed poll (offline, server down) just keeps the last known list —
      // the next tick retries. This is exactly the "disconnected for a second"
      // case the panel exists to survive.
    } finally {
      _schedule();
    }
  }

  /// Force an immediate refresh (pull-to-refresh / after creating a room).
  Future<void> refresh() => _poll();

  void _emitMerged() {
    // Local uploads first (they're happening on this screen right now), then the
    // server list (already newest-first), minus any the user dismissed.
    final merged = <ServerOperation>[
      ..._local.values,
      ..._server.where((o) => !_dismissed.contains(o.id)),
    ];
    emit(state.copyWith(operations: merged));
  }

  // ---- In-app upload tracking -------------------------------------------

  /// Registers a starting upload and returns the [CancelToken] the caller must
  /// pass to its multipart request, so the panel's Cancel aborts it.
  CancelToken beginUpload(String id, String name) {
    final token = CancelToken();
    _localCancels[id] = token;
    _local[id] = ServerOperation(
      id: id,
      kind: OperationKind.upload,
      name: name,
      status: OperationStatus.downloading,
      percent: 0,
      isLocal: true,
    );
    _emitMerged();
    start();
    return token;
  }

  void updateUpload(String id, int sent, int total) {
    final op = _local[id];
    if (op == null) return;
    _local[id] = op.copyWith(
      bytesDownloaded: sent,
      totalBytes: total,
      percent: total > 0 ? ((sent / total) * 100).floor().clamp(0, 100) : null,
    );
    _emitMerged();
  }

  void finishUpload(String id, {String? slug}) {
    final op = _local[id];
    if (op == null) return;
    _localCancels.remove(id);
    _local[id] = op.copyWith(status: OperationStatus.done, percent: 100, slug: slug);
    _emitMerged();
  }

  void failUpload(String id, String error) {
    final op = _local[id];
    if (op == null) return;
    _localCancels.remove(id);
    _local[id] = op.copyWith(status: OperationStatus.error, error: error);
    _emitMerged();
  }

  // ---- Cancel + dismiss --------------------------------------------------

  /// Cancels a running operation: a local upload via its Dio token, a server
  /// transfer via the API. Errors are swallowed — the next poll reflects truth.
  Future<void> cancel(ServerOperation op) async {
    if (op.isLocal) {
      _localCancels.remove(op.id)?.cancel('operation_canceled');
      final existing = _local[op.id];
      if (existing != null) {
        _local[op.id] = existing.copyWith(
          status: OperationStatus.error,
          error: 'operation_canceled',
        );
        _emitMerged();
      }
      return;
    }
    try {
      await _ds.cancel(op.id);
    } catch (_) {
      /* next poll reconciles */
    }
    await _poll();
  }

  /// Removes a finished operation from the list. A local upload is dropped
  /// outright; a server transfer is hidden via [_dismissed] (the server still
  /// lists it until its own eviction timer, and it isn't ours to delete).
  void dismiss(ServerOperation op) {
    if (op.isLocal) {
      if (_local.remove(op.id) != null) {
        _localCancels.remove(op.id);
        _emitMerged();
      }
      return;
    }
    _dismissed.add(op.id);
    _emitMerged();
  }

  /// Clears every finished/errored operation at once — local uploads outright,
  /// finished server transfers by hiding them like [dismiss].
  void clearFinished() {
    _local.removeWhere((_, op) => !op.isActive);
    for (final op in _server) {
      if (!op.isActive) _dismissed.add(op.id);
    }
    _emitMerged();
  }

  @override
  Future<void> close() {
    _timer?.cancel();
    return super.close();
  }
}
