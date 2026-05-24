part of '../socket_cubit.dart';

extension SocketEmitEvent on SocketCubit {
  /// Fire-and-forget emit. [data] may be a Map, a primitive, or binary
  /// (`List<int>` / `Uint8List`) for the voice relay.
  void emitEvent(String event, [dynamic data]) => _socket?.emit(event, data);
}
