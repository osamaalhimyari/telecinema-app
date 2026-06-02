part of '../socket_cubit.dart';

extension SocketOff on SocketCubit {
  /// Stop listening to [event] and release its stream controller.
  Future<void> off(String event) async {
    _socket?.off(event);
    final controller = _controllers.remove(event);
    if (controller != null && !controller.isClosed) await controller.close();
  }
}
