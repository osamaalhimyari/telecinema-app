import 'package:path_provider/path_provider.dart';

import 'package:watch_aprty_app/src/rust/api/torrent.dart' as rust;

/// Thin wrapper over the embedded librqbit engine (Rust / flutter_rust_bridge).
///
/// Each device streams torrent rooms on its own: the engine binds a local HTTP
/// server (`127.0.0.1:<port>`) that serves the torrent file with HTTP range
/// support, and [resolve] returns a ready-to-play URL for the player. Room sync
/// (play/pause/seek/chat/reactions) is unrelated to this — it flows over the
/// app's existing server socket. There is no device-to-device connection here.
///
/// Registered as a process-wide singleton: the underlying engine is a global in
/// Rust, so one instance is started once and reused for the app's lifetime.
class TorrentEngine {
  int? _port;

  /// Starts the engine if needed and returns the local HTTP server port.
  /// Idempotent — later calls return the cached port.
  Future<int> ensureStarted() async {
    final cached = _port;
    if (cached != null) return cached;
    final dir = await getApplicationSupportDirectory();
    final port = await rust.initTorrentEngine(downloadDir: dir.path);
    _port = port;
    return port;
  }

  /// Adds [magnet] to the swarm, resolves metadata, and returns a local
  /// `http://127.0.0.1:<port>/…` URL streaming the torrent's primary (largest)
  /// file — hand this straight to the media player.
  Future<String> resolve(String magnet) async {
    await ensureStarted();
    final added = await rust.addTorrent(magnet: magnet.trim());
    return added.streamUrl;
  }
}
