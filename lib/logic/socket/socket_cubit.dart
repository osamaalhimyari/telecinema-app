import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import 'socket_state.dart';

part 'handlers/connect.dart';
part 'handlers/disconnect.dart';
part 'handlers/on.dart';
part 'handlers/off.dart';
part 'handlers/emit_event.dart';

/// Generic Socket.IO client wrapped in a Cubit.
///
/// Lives in `logic/socket` so any feature (rooms, watch sync, chat, voice…)
/// can listen to or emit events without coupling the transport to a specific
/// domain. Mirrors the rider reference's `SocketCubit`.
///
/// Typical usage:
///   sl<SocketCubit>().connect(url: AppConfig.socketBaseUrl);
///   final sub = sl<SocketCubit>().on('sync').listen((data) {...});
///   sl<SocketCubit>().emitEvent('control', {'action': 'play'});
///
/// Each public/private method lives in its own part file under `handlers/`.
class SocketCubit extends Cubit<SocketState> {
  SocketCubit() : super(const SocketState());

  io.Socket? _socket;
  final Map<String, StreamController<dynamic>> _controllers = {};

  bool get isConnected => _socket?.connected ?? false;
  io.Socket? get rawSocket => _socket;

  /// Internal state forwarder for the part-file handlers. `emit` is
  /// `@protected` and cannot be called from an extension, so handlers route
  /// through this — which also guards against emitting on a closed cubit.
  void _set(SocketState next) {
    if (!isClosed) emit(next);
  }

  @override
  Future<void> close() async {
    await disconnect();
    return super.close();
  }
}
