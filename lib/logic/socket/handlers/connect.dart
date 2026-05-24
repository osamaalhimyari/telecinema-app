part of '../socket_cubit.dart';

extension SocketConnect on SocketCubit {
  /// Open (or re-open) the connection. Safe to call repeatedly — if a socket
  /// already exists it is reconnected instead of replaced.
  void connect({
    required String url,
    Map<String, dynamic>? auth,
    String? namespace,
    List<String> transports = const ['websocket'],
  }) {
    final fullUrl = namespace == null ? url : '$url/$namespace';

    if (_socket != null) {
      if (auth != null) _socket!.auth = auth;
      if (!_socket!.connected) {
        _set(state.copyWith(status: SocketStatus.connecting, clearError: true));
        _socket!.connect();
      }
      return;
    }

    _set(state.copyWith(status: SocketStatus.connecting, clearError: true));

    _socket = io.io(
      fullUrl,
      io.OptionBuilder()
          .setTransports(transports)
          .disableAutoConnect()
          .setAuth(auth ?? const {})
          .enableReconnection()
          .build(),
    );

    _socket!
      ..onConnect((_) => _set(state.copyWith(status: SocketStatus.connected)))
      ..onDisconnect((_) => _set(state.copyWith(status: SocketStatus.disconnected)))
      ..onReconnectAttempt((_) => _set(state.copyWith(status: SocketStatus.connecting)))
      ..onConnectError(
        (err) => _set(state.copyWith(status: SocketStatus.error, error: err?.toString())),
      )
      ..onError((err) => _set(state.copyWith(status: SocketStatus.error, error: err?.toString())));

    // Re-bind any listeners registered via [on] before connect.
    for (final entry in _controllers.entries) {
      _socket!.on(entry.key, (data) => entry.value.add(data));
    }

    _socket!.connect();
  }
}
