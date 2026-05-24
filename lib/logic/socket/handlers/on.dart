part of '../socket_cubit.dart';

extension SocketOn on SocketCubit {
  /// Subscribe to [event]. Returns a broadcast stream — multiple listeners
  /// share one underlying socket handler. Safe to call before [connect].
  Stream<dynamic> on(String event) {
    final existing = _controllers[event];
    if (existing != null) return existing.stream;

    final controller = StreamController<dynamic>.broadcast();
    _controllers[event] = controller;
    _socket?.on(event, (data) {
      if (!controller.isClosed) controller.add(data);
    });
    return controller.stream;
  }
}
