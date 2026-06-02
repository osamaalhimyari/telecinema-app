import 'dart:async';

import '/core/config/app_config.dart';
import '/logic/identity/identity_cubit.dart';
import '/logic/socket/socket_cubit.dart';

/// Subscribes to the `home` channel for live per-room viewer counts — exactly
/// what the website's home page does. Maintains a running `slug → count` map
/// and emits the whole map on each update so the list cubit stays simple.
class HomeSocketDataSource {
  HomeSocketDataSource(this._socket, this._identity);

  final SocketCubit _socket;
  final IdentityCubit _identity;

  final Map<String, int> _counts = {};
  final _controller = StreamController<Map<String, int>>.broadcast();
  StreamSubscription<dynamic>? _snapshotSub;
  StreamSubscription<dynamic>? _singleSub;
  StreamSubscription<dynamic>? _statusSub;

  Stream<Map<String, int>> get viewerCounts => _controller.stream;

  void start() {
    _socket.connect(url: AppConfig.socketBaseUrl);

    _snapshotSub ??= _socket.on('viewer_counts').listen(_onSnapshot);
    _singleSub ??= _socket.on('viewer_count').listen(_onSingle);

    // (Re)join the home channel whenever the connection comes up.
    _statusSub ??= _socket.stream.listen((s) {
      if (s.isConnected) {
        _identity.push();
        _socket.emitEvent('join_home');
      }
    });

    if (_socket.isConnected) {
      _identity.push();
      _socket.emitEvent('join_home');
    }
  }

  void _onSnapshot(dynamic data) {
    if (data is! Map) return;
    final counts = data['counts'];
    if (counts is! Map) return;
    counts.forEach((k, v) {
      if (v is num) _counts[k.toString()] = v.toInt();
    });
    _emit();
  }

  void _onSingle(dynamic data) {
    if (data is! Map) return;
    final slug = data['slug']?.toString();
    final count = data['count'];
    if (slug == null || count is! num) return;
    _counts[slug] = count.toInt();
    _emit();
  }

  void _emit() {
    if (!_controller.isClosed) _controller.add(Map.unmodifiable(_counts));
  }

  Future<void> dispose() async {
    await _snapshotSub?.cancel();
    await _singleSub?.cancel();
    await _statusSub?.cancel();
    await _controller.close();
  }
}
