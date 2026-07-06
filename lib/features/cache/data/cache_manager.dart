import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';

import '/core/localization/translation_keys.dart';
import '/features/rooms/domain/entities/room.dart';
import '../domain/entities/cached_video.dart';
import 'cache_index_store.dart';
import 'file_downloader.dart';

/// Owns the on-device video cache: starts/pauses/resumes/cancels downloads,
/// persists their state, and resolves a finished local file for playback.
///
/// Every cacheable room exposes a rangeable HTTP source (`/video/:filename` or
/// `/stream/:slug`), so one resumable downloader covers torrent **and** file
/// rooms — the bytes land on disk and the player reads them locally with no
/// buffering. The cache is purely a per-device, client-side optimization; room
/// sync is unaffected and the server never learns about it.
class CacheManager {
  CacheManager({CacheIndexStore? store, FileDownloader? downloader})
    : _injectedStore = store,
      _downloader = downloader ?? FileDownloader();

  final CacheIndexStore? _injectedStore;
  final FileDownloader _downloader;

  late CacheIndexStore _store;
  String? _videosDir;
  bool _disabled = false;

  final _events = StreamController<List<CachedVideo>>.broadcast();
  final Map<String, CancelToken> _tokens = {};
  final Set<String> _deleting = {};

  /// Emits the full cache list whenever anything changes.
  Stream<List<CachedVideo>> get changes => _events.stream;

  /// Per-key view, for the in-room download button.
  Stream<CachedVideo?> watch(String key) =>
      _events.stream.map((_) => _store.get(key));

  /// Newest first.
  List<CachedVideo> list() =>
      _store.all()..sort((a, b) => b.updatedAtMs.compareTo(a.updatedAtMs));

  CachedVideo? get(String key) => _store.get(key);

  Future<void> init() async {
    // A placeholder store so every accessor stays safe even if setup fails
    // below — WatchCubit calls resolvePlayable() on entering *every* room.
    _store = _injectedStore ?? CacheIndexStore(File('cache_index.json'));
    // Web has no app-writable media directory; caching is a native-only feature.
    if (kIsWeb) {
      _disabled = true;
      return;
    }
    try {
      final base = await getApplicationSupportDirectory();
      final cacheDir = '${base.path}/cache';
      _videosDir = '$cacheDir/videos';
      await Directory(_videosDir!).create(recursive: true);
      _store = _injectedStore ?? CacheIndexStore(File('$cacheDir/index.json'));
      await _store.load();
      await _reconcile();
      _emit();
    } catch (_) {
      _disabled = true;
    }
  }

  /// After a cold start: a download interrupted by a process kill can't be live,
  /// so demote it to paused; drop a "done" entry whose file has vanished.
  Future<void> _reconcile() async {
    for (final v in _store.all()) {
      if (v.status == CacheStatus.downloading || v.status == CacheStatus.queued) {
        await _store.put(v.copyWith(status: CacheStatus.paused, updatedAtMs: _now()));
      } else if (v.status == CacheStatus.done) {
        final path = v.localPath;
        if (path == null || !File(path).existsSync()) {
          await _store.remove(v.key);
        }
      }
    }
  }

  /// True when [room] can be cached on this device.
  bool canCache(Room room) =>
      !_disabled &&
      !kIsWeb &&
      !room.isExternal &&
      (room.videoUrl?.isNotEmpty ?? false);

  /// Absolute local file to play instead of streaming, when a finished copy
  /// exists; null otherwise.
  String? resolvePlayable(Room room) {
    final v = _store.get(room.slug);
    if (v == null || v.status != CacheStatus.done) return null;
    final path = v.localPath;
    if (path == null || !File(path).existsSync()) return null;
    return path;
  }

  /// Local subtitle cached with a finished video, if any.
  String? cachedSubtitlePath(String slug) {
    final v = _store.get(slug);
    if (v == null || v.status != CacheStatus.done) return null;
    final s = v.subtitlePath;
    return (s != null && File(s).existsSync()) ? s : null;
  }

  /// Registers an EXISTING on-device file into the cache under [slug] by
  /// stream-copying it into `cache/videos/<slug>.<ext>` and writing a `done`
  /// index entry — so [resolvePlayable] then plays it from disk without any
  /// server download.
  ///
  /// Used by `local` rooms (each viewer supplies the same file themselves) and
  /// by `upload` rooms (the uploader plays their own copy from disk instead of
  /// re-streaming it). Reports progress via [onProgress] so a multi-GB copy can
  /// show a bar. Returns the entry, or null on web/disabled, a missing source,
  /// or any I/O failure (the partial copy is cleaned up).
  Future<CachedVideo?> importLocalFile(
    String slug,
    String sourcePath, {
    String? title,
    String? originalName,
    int? size,
    void Function(int copied, int total)? onProgress,
  }) async {
    if (_disabled || _videosDir == null) return null;

    // Already imported and the file is still present — reuse it (idempotent).
    final existing = _store.get(slug);
    if (existing?.status == CacheStatus.done) {
      final p = existing!.localPath;
      if (p != null && File(p).existsSync()) return existing;
    }

    final src = File(sourcePath);
    if (!await src.exists()) return null;

    final ext = _extFromName(originalName ?? sourcePath);
    final finalPath = '$_videosDir/$slug.$ext';
    final total = size ?? await src.length();

    IOSink? out;
    try {
      // Fresh copy: drop any stale file at the target so bytes never mix.
      await _deleteFile(finalPath);
      out = File(finalPath).openWrite();
      var copied = 0;
      await for (final chunk in src.openRead()) {
        out.add(chunk);
        copied += chunk.length;
        onProgress?.call(copied, total);
      }
      await out.flush();
      await out.close();
      out = null;
    } catch (_) {
      try {
        await out?.close();
      } catch (_) {/* best-effort */}
      await _deleteFile(finalPath);
      return null;
    }

    final len = await _fileLen(finalPath);
    if (len <= 0) {
      await _deleteFile(finalPath);
      return null;
    }
    final entry = CachedVideo(
      key: slug,
      slug: slug,
      title: title ?? originalName ?? slug,
      // A user-supplied local file — never re-downloadable, so no source URL.
      sourceUrl: '',
      status: CacheStatus.done,
      localPath: finalPath,
      totalBytes: len,
      downloadedBytes: len,
      updatedAtMs: _now(),
    );
    await _put(entry);
    return entry;
  }

  // ---- Commands ----------------------------------------------------------

  /// Begin (or resume) caching [room]. No-op if already running or finished.
  Future<void> start(Room room) async {
    if (!canCache(room)) return;
    final existing = _store.get(room.slug);
    if (existing?.status == CacheStatus.done) return; // already cached
    final base =
        (existing ??
                CachedVideo(
                  key: room.slug,
                  slug: room.slug,
                  title: room.name,
                  sourceUrl: room.videoUrl!,
                  status: CacheStatus.queued,
                ))
            .copyWith(
              title: room.name,
              sourceUrl: room.videoUrl,
              subtitleUrl: room.subtitleUrl,
            );
    await _run(base);
  }

  /// Resume a paused/failed download from the stored entry (used by the library
  /// screen, where no [Room] object is at hand).
  Future<void> resume(String key) async {
    final v = _store.get(key);
    if (v == null || v.status == CacheStatus.done) return;
    await _run(v);
  }

  /// Pause a running download; the partial file is kept for resume.
  Future<void> pause(String key) async {
    // Remove the token first so any in-flight progress callback is ignored; the
    // run's cancel handler parks the entry as paused.
    final token = _tokens.remove(key);
    if (token != null) {
      token.cancel('paused');
      return;
    }
    final v = _store.get(key);
    if (v != null && v.status == CacheStatus.downloading) {
      await _put(v.copyWith(status: CacheStatus.paused, updatedAtMs: _now()));
    }
  }

  /// Cancel (if running) and remove the cached video and all its files.
  Future<void> delete(String key) async {
    _deleting.add(key);
    _tokens.remove(key)?.cancel('deleted');
    final v = _store.get(key);
    if (_videosDir != null) await _deleteFile('$_videosDir/$key.part');
    await _deleteFile(v?.localPath);
    await _deleteFile(v?.subtitlePath);
    await _store.remove(key);
    _deleting.remove(key);
    _emit();
  }

  Future<void> deleteAll() async {
    for (final v in _store.all()) {
      await delete(v.key);
    }
  }

  // ---- Core download loop ------------------------------------------------

  Future<void> _run(CachedVideo base) async {
    final key = base.key;
    if (_tokens.containsKey(key)) return; // already running
    final url = base.sourceUrl;
    if (url.isEmpty || _videosDir == null) return;

    final ext = _extFromUrl(url);
    final partPath = '$_videosDir/$key.part';
    final finalPath = '$_videosDir/$key.$ext';
    final startOffset = await _fileLen(partPath);

    var entry = base.copyWith(
      status: CacheStatus.downloading,
      downloadedBytes: startOffset,
      clearError: true,
      updatedAtMs: _now(),
    );
    await _put(entry);

    final token = CancelToken();
    _tokens[key] = token;
    var lastEmit = startOffset;

    try {
      await _downloader.download(
        url: url,
        savePath: partPath,
        startOffset: startOffset,
        cancelToken: token,
        onProgress: (received, total) {
          // Ignore late callbacks from a run that was paused/deleted/replaced —
          // otherwise a queued write could resurrect a removed entry.
          if (!identical(_tokens[key], token)) return;
          final crossed = received - lastEmit >= _emitEvery;
          final learnedTotal = total != null && entry.totalBytes <= 0;
          final finished = total != null && received >= total;
          if (!crossed && !learnedTotal && !finished) return;
          lastEmit = received;
          entry = entry.copyWith(
            downloadedBytes: received,
            totalBytes: total ?? entry.totalBytes,
            updatedAtMs: _now(),
          );
          unawaited(_put(entry));
        },
      );

      // Finished: promote the partial to its final name, grab the subtitle.
      await _moveInto(partPath, finalPath);
      var subPath = entry.subtitlePath;
      if ((entry.subtitleUrl ?? '').isNotEmpty) {
        // Keep the real subtitle extension (.srt/.vtt) so libmpv detects the
        // format correctly — a generic ".sub" would be read as MicroDVD.
        final subExt = _extFromUrl(entry.subtitleUrl!, fallback: 'srt');
        subPath =
            await _tryDownloadSubtitle(entry.subtitleUrl!, '$_videosDir/$key.$subExt') ??
            subPath;
      }
      final size = await _fileLen(finalPath);
      entry = entry.copyWith(
        status: CacheStatus.done,
        localPath: finalPath,
        subtitlePath: subPath,
        downloadedBytes: size,
        totalBytes: size > 0 ? size : entry.totalBytes,
        updatedAtMs: _now(),
      );
      await _put(entry);
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) {
        // A delete cancel is finalised by delete(); a pause cancel parks it.
        if (!_deleting.contains(key)) {
          await _put(entry.copyWith(status: CacheStatus.paused, updatedAtMs: _now()));
        }
      } else {
        await _put(
          entry.copyWith(
            status: CacheStatus.error,
            errorKey: TranslationKeys.downloadFailed,
            updatedAtMs: _now(),
          ),
        );
      }
    } catch (_) {
      await _put(
        entry.copyWith(
          status: CacheStatus.error,
          errorKey: TranslationKeys.downloadFailed,
          updatedAtMs: _now(),
        ),
      );
    } finally {
      _tokens.remove(key);
    }
  }

  /// Best-effort subtitle fetch; returns the local path or null on failure.
  Future<String?> _tryDownloadSubtitle(String url, String savePath) async {
    try {
      await _downloader.download(url: url, savePath: savePath);
      return await _fileLen(savePath) > 0 ? savePath : null;
    } catch (_) {
      return null;
    }
  }

  // ---- Helpers -----------------------------------------------------------

  static const _emitEvery = 2 * 1024 * 1024; // persist/emit ~ every 2 MB

  int _now() => DateTime.now().millisecondsSinceEpoch;

  /// Writes through the store unless the key is mid-delete (so a late progress
  /// callback can't resurrect a just-removed entry), then notifies listeners.
  Future<void> _put(CachedVideo v) async {
    if (_deleting.contains(v.key)) return;
    await _store.put(v);
    _emit();
  }

  void _emit() {
    if (!_events.isClosed) _events.add(list());
  }

  Future<int> _fileLen(String path) async {
    final f = File(path);
    return await f.exists() ? f.length() : 0;
  }

  Future<void> _moveInto(String from, String to) async {
    final src = File(from);
    if (!await src.exists()) return;
    final dst = File(to);
    // Never delete an existing final file — it may be open in the player. A
    // prior complete copy wins; just drop our redundant partial.
    if (await dst.exists()) {
      await src.delete();
      return;
    }
    await src.rename(to);
  }

  Future<void> _deleteFile(String? path) async {
    if (path == null) return;
    try {
      final f = File(path);
      if (await f.exists()) await f.delete();
    } catch (_) {
      /* best-effort */
    }
  }

  /// Extension from a bare filename or filesystem path — handles both `/` and
  /// `\` separators (a picked path may be Windows-style), reusing [_extFromUrl].
  String _extFromName(String name, {String fallback = 'mp4'}) =>
      _extFromUrl(name.split(RegExp(r'[\\/]')).last, fallback: fallback);

  /// Extension from the URL's last path segment, defaulting to [fallback]
  /// (torrent stream URLs like `/stream/:slug` carry none).
  String _extFromUrl(String url, {String fallback = 'mp4'}) {
    final path = Uri.tryParse(url)?.path ?? url;
    final seg = path.split('/').last;
    final dot = seg.lastIndexOf('.');
    if (dot <= 0 || dot == seg.length - 1) return fallback;
    final ext = seg.substring(dot + 1).toLowerCase();
    // Guard against query-laden or absurd "extensions".
    return (ext.length <= 5 && RegExp(r'^[a-z0-9]+$').hasMatch(ext)) ? ext : fallback;
  }

  Future<void> dispose() async {
    for (final t in _tokens.values) {
      t.cancel('disposed');
    }
    _tokens.clear();
    await _events.close();
  }
}
