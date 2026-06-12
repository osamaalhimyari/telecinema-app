import 'dart:convert';
import 'dart:io';

import '../domain/entities/cached_video.dart';

/// Persistent JSON-backed index of cached videos. Holds metadata only — the
/// large media files sit beside it on disk. The index is tiny (a handful of
/// entries), so it is rewritten atomically on every change.
class CacheIndexStore {
  CacheIndexStore(this._file);

  final File _file;
  final Map<String, CachedVideo> _items = {};
  bool _loaded = false;

  /// Serializes writes so overlapping throttled progress saves can't race on
  /// the temp file.
  Future<void> _writing = Future<void>.value();

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      if (!await _file.exists()) return;
      final raw = await _file.readAsString();
      if (raw.trim().isEmpty) return;
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        for (final e in decoded) {
          if (e is Map<String, dynamic>) {
            final v = CachedVideo.fromJson(e);
            _items[v.key] = v;
          }
        }
      }
    } catch (_) {
      // A corrupt index must never crash the app — start clean.
      _items.clear();
    }
  }

  List<CachedVideo> all() => _items.values.toList(growable: false);

  CachedVideo? get(String key) => _items[key];

  Future<void> put(CachedVideo v) async {
    _items[v.key] = v;
    await _flush();
  }

  Future<void> remove(String key) async {
    if (_items.remove(key) != null) await _flush();
  }

  /// Serializes writes (see [_writing]); each write goes to a temp file then
  /// renames, so a kill mid-write can't truncate the live index.
  Future<void> _flush() {
    _writing = _writing.then((_) => _doFlush());
    return _writing;
  }

  Future<void> _doFlush() async {
    final data = jsonEncode(_items.values.map((v) => v.toJson()).toList());
    final tmp = File('${_file.path}.tmp');
    await tmp.writeAsString(data, flush: true);
    await tmp.rename(_file.path);
  }
}
