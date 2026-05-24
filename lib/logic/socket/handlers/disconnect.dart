part of '../socket_cubit.dart';

extension SocketDisconnect on SocketCubit {
  /// Tears down the socket and closes every per-event stream controller so a
  /// late event can't add to a stream nobody listens to anymore.
  Future<void> disconnect() async {
    _socket?.dispose();
    _socket = null;
    for (final controller in _controllers.values) {
      if (!controller.isClosed) await controller.close();
    }
    _controllers.clear();
    _set(state.copyWith(status: SocketStatus.disconnected, clearError: true));
  }
}
