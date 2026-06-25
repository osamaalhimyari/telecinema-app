import '/core/livetv/live_stream.dart';
import '/core/livetv/live_stream_resolver.dart';
import '/core/network/api_client.dart';
import '../domain/entities/tv_channel.dart';
import '../domain/entities/tv_node.dart';
import 'tv_api.dart';

/// Re-resolves a live-TV channel when its signed token expires, and persists the
/// fresh URL back to the room. Implements the core [LiveStreamResolver] so the
/// watch feature can use it without depending on the TV feature directly.
///
/// Re-resolution runs ON-DEVICE (re-fetching the YacineTV tree), matching the
/// app's pattern for providers that bot-block the server's datacenter IP — the
/// fresh, valid URL is then pushed to the backend so every viewer recovers.
class TvLiveStreamResolver implements LiveStreamResolver {
  TvLiveStreamResolver(this._api, this._client);

  final TvApi _api;
  final ApiClient _client;

  @override
  Future<LiveStream?> refresh({required String slug, required List<String> path}) async {
    if (path.isEmpty) return null;

    final List<TvNode> tree;
    try {
      tree = await _api.fetchTree(forceRefresh: true);
    } catch (_) {
      return null;
    }

    final channel = _walk(tree, path);
    if (channel == null) return null;

    // Persist the fresh stream so other viewers and late joiners keep working.
    // Best-effort: this client already recovers locally even if the save fails.
    try {
      final packed = LiveStreamCodec.pack(
        url: channel.url,
        headers: channel.headers,
        path: path,
      );
      await _client.post('/rooms/$slug/stream', data: {'videoUrl': packed});
    } catch (_) {
      /* ignore — local recovery still proceeds */
    }

    return LiveStream(url: channel.url, headers: channel.headers);
  }

  /// Follows [path] (node names from the root) down to the leaf channel.
  TvChannel? _walk(List<TvNode> nodes, List<String> path) {
    var level = nodes;
    TvNode? node;
    for (final name in path) {
      node = _firstNamed(level, name);
      if (node == null) return null;
      level = node.children;
    }
    return node?.primaryChannel;
  }

  TvNode? _firstNamed(List<TvNode> nodes, String name) {
    for (final n in nodes) {
      if (n.name == name) return n;
    }
    return null;
  }
}
