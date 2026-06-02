import 'package:flutter_bloc/flutter_bloc.dart';

import '/logic/socket/socket_cubit.dart';
import '/logic/storage/key_value_storage.dart';
import '/logic/storage/shared_prefs_storage.dart';

/// Holds the viewer's chosen display name (the `name` shown in chat, presence
/// and voice). Persisted locally and pushed to the socket via `set_name` so
/// every room the user joins announces them correctly.
class IdentityCubit extends Cubit<String> {
  IdentityCubit(this._storage, this._socket) : super('') {
    final saved = _storage.getString(StorageKeys.displayName);
    if (saved != null && saved.isNotEmpty) emit(saved);
  }

  final KeyValueStorage _storage;
  final SocketCubit _socket;

  bool get hasName => state.trim().isNotEmpty;

  Future<void> setName(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty || trimmed.length > 30) return;
    await _storage.setString(StorageKeys.displayName, trimmed);
    emit(trimmed);
    push();
  }

  /// (Re)announce the current name to the socket. Called on connect and after
  /// a name change. No-op when the socket isn't up yet — `join_room` re-sends.
  void push() {
    if (hasName && _socket.isConnected) {
      _socket.emitEvent('set_name', {'name': state});
    }
  }
}
