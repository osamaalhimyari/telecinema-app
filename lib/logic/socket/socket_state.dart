import 'package:equatable/equatable.dart';

enum SocketStatus { disconnected, connecting, connected, error }

class SocketState extends Equatable {
  final SocketStatus status;
  final String? error;

  const SocketState({this.status = SocketStatus.disconnected, this.error});

  bool get isConnected => status == SocketStatus.connected;
  bool get isConnecting => status == SocketStatus.connecting;
  bool get isDisconnected => status == SocketStatus.disconnected;
  bool get hasError => status == SocketStatus.error;

  SocketState copyWith({SocketStatus? status, String? error, bool clearError = false}) {
    return SocketState(
      status: status ?? this.status,
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  List<Object?> get props => [status, error];
}
