import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '/core/config/app_config.dart';
import '/core/constants/app_constants.dart';
import '/core/localization/translation_keys.dart';
import '/features/cache/data/cache_manager.dart';
import '/features/rooms/domain/usecases/delete_room_usecase.dart';
import '/features/rooms/domain/usecases/get_room_usecase.dart';
import '/features/rooms/domain/usecases/unlock_room_usecase.dart';
import '/features/rooms/domain/usecases/upload_subtitle_usecase.dart';
import '/features/rooms/domain/entities/room.dart';
import '/logic/favorites/favorites_cubit.dart';
import '/logic/identity/identity_cubit.dart';
import '/logic/storage/key_value_storage.dart';
import '/logic/storage/shared_prefs_storage.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/entities/playback_sync.dart';
import '../../domain/entities/reaction_event.dart';
import '../../domain/entities/subtitle_settings.dart';
import '../../domain/repositories/watch_repository.dart';
import '../../data/datasources/torrent_engine.dart';
import 'watch_state.dart';

/// The synchronized-room brain. Owns the libmpv-backed [Player] for file rooms,
/// applies the server's authoritative `sync` (extrapolated for latency) and
/// reports local buffering so the room's wait-gate can pause everyone. External
/// (embed) rooms have no player — they reload the WebView on resync / source
/// change instead.
class WatchCubit extends Cubit<WatchState> {
  WatchCubit(
    this._repo,
    this._getRoom,
    this._unlockRoom,
    this._deleteRoom,
    this._uploadSubtitle,
    this._storage,
    this._torrentEngine,
    this._favorites,
    this._identity,
    this._cache,
  ) : super(const WatchState());

  final WatchRepository _repo;
  final GetRoomUseCase _getRoom;
  final UnlockRoomUseCase _unlockRoom;
  final DeleteRoomUseCase _deleteRoom;
  final UploadSubtitleUseCase _uploadSubtitle;
  final KeyValueStorage _storage;
  final TorrentEngine _torrentEngine;
  final FavoritesCubit _favorites;
  final IdentityCubit _identity;
  final CacheManager _cache;

  Player? _player;

  /// The render handle for the [Video] widget. Lives as long as the player.
  VideoController? _videoController;
  VideoController? get videoController => _videoController;

  final List<StreamSubscription<dynamic>> _subs = [];

  /// Subscriptions tied to the *current* [Player] only — kept apart from [_subs]
  /// so they can be torn down and re-created when the player is rebuilt (e.g. a
  /// torrent stream that stalls and falls back to the server stream).
  final List<StreamSubscription<dynamic>> _playerSubs = [];

  Timer? _bufferDebounce;
  bool _reportedBuffering = false;
  PlaybackSync? _pendingSync;

  /// True while the player is fed by the on-device torrent stream (not the
  /// server stream or a plain file), so the stall watchdog only watches that.
  bool _onDeviceTorrent = false;

  /// Fires when an on-device torrent stream buffers too long without progress —
  /// the phone can't reach the swarm, so we fall back to the server's copy.
  Timer? _torrentStallTimer;
  static const _torrentStallTimeout = Duration(seconds: 20);

  /// Bumped every time a new [Player] is created. Async work captured against an
  /// older generation (a pending seek, a fired stall timer) checks this and bails
  /// instead of acting on a player that has since been disposed/replaced.
  int _playerGeneration = 0;

  /// Transient floating-reaction feed for the overlay (not part of state).
  final _reactions = StreamController<ReactionEvent>.broadcast();
  Stream<ReactionEvent> get reactions => _reactions.stream;

  /// Transient feed of *incoming* chat for the fullscreen floating overlay.
  /// (Messages are still appended to `state.messages` for the chat panel.)
  final _incomingChat = StreamController<ChatMessage>.broadcast();
  Stream<ChatMessage> get incomingChat => _incomingChat.stream;

  Stream<String?> get chatThrottled => _repo.chatThrottled;

  /// Per-message delivery timers, keyed by `clientId`. A pending send that isn't
  /// confirmed before its timer fires is flagged failed (tap to retry).
  final Map<String, Timer> _sendTimers = {};

  /// Monotonic counter feeding unique `clientId`s for this session.
  int _chatSeq = 0;

  static const _sendTimeout = Duration(seconds: 12);

  // ===========================================================================
  // Lifecycle
  // ===========================================================================

  Future<void> init({Room? room, required String slug}) async {
    var r = room;
    if (r == null) {
      final res = await _getRoom(slug);
      r = res.fold((f) {
        emit(state.copyWith(phase: WatchPhase.error, errorKey: f.message));
        return null;
      }, (room) => room);
      if (r == null) return;
    }

    emit(state.copyWith(room: r, externalUrl: r.externalUrl, subtitleUrl: r.subtitleUrl));

    // Opening a room (even a still-locked one) counts as recently watched.
    _favorites.recordRecent(r.slug);

    final unlocked =
        !r.hasPassword || (_storage.getBool(StorageKeys.roomUnlocked(r.slug)) ?? false);
    if (!unlocked) {
      emit(state.copyWith(phase: WatchPhase.locked));
      return;
    }
    _enterRoom();
  }

  Future<void> unlock(String password) async {
    final slug = state.room!.slug;
    emit(state.copyWith(unlockBusy: true, clearUnlockError: true));
    final res = await _unlockRoom(UnlockRoomParams(slug: slug, password: password));
    res.fold(
      (f) => emit(state.copyWith(unlockBusy: false, unlockErrorKey: f.message)),
      (ok) {
        if (ok) {
          _storage.setBool(StorageKeys.roomUnlocked(slug), true);
          _enterRoom();
        } else {
          emit(
            state.copyWith(unlockBusy: false, unlockErrorKey: TranslationKeys.incorrectPassword),
          );
        }
      },
    );
  }

  void _enterRoom() {
    emit(state.copyWith(phase: WatchPhase.ready, unlockBusy: false, clearUnlockError: true));
    _subscribe();
    final room = state.room!;
    _repo.join(room.slug);
    if (state.isExternal) return;

    // Prefer a finished local copy: play straight from disk so this viewer never
    // buffers (and never trips the room's wait-for-slowest gate), while sync,
    // chat and reactions keep flowing over the socket exactly as for a stream.
    final cachedPath = _cache.resolvePlayable(room);
    if (cachedPath != null) {
      // media_kit/libmpv wants a proper file:// URI (esp. on Windows/desktop),
      // not a bare path.
      final subPath = _cache.cachedSubtitlePath(room.slug);
      if (subPath != null) emit(state.copyWith(subtitleUrl: Uri.file(subPath).toString()));
      _initVideo(Uri.file(cachedPath).toString());
      return;
    }

    // Torrent rooms stream on-device: each client adds the magnet to its own
    // embedded librqbit engine and plays the resulting local 127.0.0.1 URL.
    // Sync (play/pause/seek/chat/reactions) still flows over the server socket
    // exactly like file rooms — only the *source* differs. Web has no native
    // engine, so it falls back to the server stream (room.videoUrl).
    final magnet = room.magnet;
    if (!kIsWeb && room.roomType.isTorrent && magnet != null && magnet.isNotEmpty) {
      _initTorrentVideo(magnet);
      return;
    }
    final videoUrl = room.videoUrl;
    if (videoUrl != null) _initVideo(videoUrl);
  }

  /// Resolves a torrent magnet to a local stream URL via the embedded engine,
  /// then opens the player on it. Shows a "preparing" state while the swarm
  /// metadata is fetched.
  ///
  /// If the on-device engine can't stream the magnet — no reachable local
  /// peers, an unresolved swarm, or simply no native engine on this platform —
  /// it falls back to the server, which streams the same torrent over
  /// `/stream/:slug`. A video error is surfaced only when neither path works.
  Future<void> _initTorrentVideo(String magnet) async {
    emit(state.copyWith(preparingTorrent: true, videoError: false));
    try {
      final url = await _torrentEngine.resolve(magnet);
      if (isClosed) return;
      emit(state.copyWith(preparingTorrent: false));
      _onDeviceTorrent = true;
      await _initVideo(url);
    } catch (_) {
      if (isClosed) return;
      emit(state.copyWith(preparingTorrent: false));
      await _useServerStream();
    }
  }

  /// Switches a torrent room from the on-device stream to the server's
  /// `/stream/:slug` copy. Used both when the magnet won't resolve and when the
  /// on-device stream stalls (the phone can't reach the swarm). The server
  /// served this torrent when the room was created, so its copy is the reliable
  /// fallback — this is why a room that played on first visit can hang on
  /// re-entry once the local swarm goes cold. Surfaces a video error only when
  /// there is no server URL to fall back to.
  Future<void> _useServerStream() async {
    _torrentStallTimer?.cancel();
    _torrentStallTimer = null;
    _onDeviceTorrent = false;
    if (isClosed) return;
    final serverUrl = state.room?.videoUrl;
    if (serverUrl == null || serverUrl.isEmpty) {
      emit(state.copyWith(videoError: true));
      return;
    }
    // Re-seek the fresh player to wherever the room is *now*. Use lastSync
    // directly (not `?? _pendingSync`): lastSync is updated on every sync, so a
    // stale _pendingSync from before the swap must not win and snap us backward.
    _pendingSync = state.lastSync;
    await _initVideo(serverUrl);
  }

  void _subscribe() {
    _subs.addAll([
      _repo.sync.listen(_onSync),
      _repo.forceResync.listen(_onForceResync),
      _repo.chatHistory.listen(_onChatHistory),
      _repo.chat.listen(_onChat),
      _repo.chatThrottled.listen(_onChatThrottled),
      // Re-send anything still queued the moment the connection returns.
      _repo.connected.listen((up) {
        if (up) _flushChatOutbox();
      }),
      _repo.viewerCount.listen((n) => emit(state.copyWith(viewerCount: n))),
      _repo.presence.listen((u) => emit(state.copyWith(presence: u))),
      _repo.waitState.listen((u) => emit(state.copyWith(waiting: u))),
      _repo.sourceChanged.listen(_onSourceChanged),
      _repo.subtitleChanged.listen((f) {
        final url = AppConfig.subtitleUrl(f);
        emit(state.copyWith(subtitleUrl: url));
        // External rooms render their own overlay; file rooms hand the track
        // straight to the player.
        if (!state.isExternal) _applySubtitleToPlayer(url);
      }),
      _repo.subtitleSettings.listen(_applyRemoteSubtitleSettings),
      _repo.reaction.listen((r) {
        if (!_reactions.isClosed) _reactions.add(r);
      }),
      _repo.roomDeleted.listen((_) => emit(state.copyWith(phase: WatchPhase.deleted))),
    ]);
  }

  // ===========================================================================
  // Video (file rooms)
  // ===========================================================================

  Future<void> _initVideo(String url) async {
    // Tear down any previous player first — this method is re-entered when a
    // stalled torrent stream falls back to the server stream. Clear the handles
    // and show the loading state before disposing, so the UI never paints a
    // disposed controller during the swap.
    for (final s in _playerSubs) {
      await s.cancel();
    }
    _playerSubs.clear();
    final previous = _player;
    if (previous != null) {
      _player = null;
      _videoController = null;
      emit(state.copyWith(videoReady: false));
      await previous.dispose();
    }

    final player = Player(
      configuration: const PlayerConfiguration(
        // A larger demuxer buffer keeps more of the stream cached, so backward
        // seeks land instantly instead of re-downloading.
        bufferSize: 64 * 1024 * 1024,
      ),
    );
    final controller = VideoController(player);
    _player = player;
    _videoController = controller;
    // New player ⇒ new generation; invalidates any seek/stall-timer captured
    // against the player we just replaced.
    _playerGeneration++;

    _tuneNativePlayer(player);

    _playerSubs.addAll([
      player.stream.position.listen((p) {
        // Forward progress is proof the stream is healthy: clear any stale error
        // flag — libmpv can emit a transient error on a stream that then plays
        // fine (which is why PiP kept playing while the inline view showed an
        // error). Genuine failures never advance, so this never hides them.
        emit(state.copyWith(position: p, videoError: p > Duration.zero ? false : null));
      }),
      player.stream.duration.listen((d) {
        if (d > Duration.zero) emit(state.copyWith(duration: d));
      }),
      player.stream.playing.listen((playing) {
        // A video that is actually playing cannot be "unavailable".
        emit(state.copyWith(isPlaying: playing, videoError: playing ? false : null));
      }),
      player.stream.buffering.listen(_onBuffering),
      player.stream.rate.listen((r) => emit(state.copyWith(playbackRate: r))),
      // A real load failure surfaces as "video unavailable"; the progress
      // signals above clear it again the instant the media actually moves — so a
      // stuck stream is reported honestly instead of spinning forever.
      player.stream.error.listen((_) => emit(state.copyWith(videoError: true))),
    ]);

    try {
      await player.open(Media(url), play: false);
      emit(state.copyWith(videoReady: true, videoError: false));
      if (_pendingSync != null) {
        await _applyToVideo(_pendingSync!);
        _pendingSync = null;
      }
      // A subtitle the room already had (or one uploaded before the player was
      // ready) is loaded once the media is open.
      if (state.subtitleUrl != null) await _applySubtitleToPlayer(state.subtitleUrl);
    } catch (_) {
      // open() failed: tear down this player's listeners so they can't keep
      // emitting against a dead player. Leave _player/_videoController in place
      // — the next _initVideo (or close()) cleans them up; nulling them here
      // would race the playback-control methods that read _player.
      for (final s in _playerSubs) {
        await s.cancel();
      }
      _playerSubs.clear();
      emit(state.copyWith(videoError: true));
    }
  }

  /// Loads an external subtitle track into the file-room player (libmpv via
  /// media_kit); a null/empty url clears it. No-op when there is no player
  /// (external/embed rooms render their own overlay instead).
  Future<void> _applySubtitleToPlayer(String? url) async {
    final p = _player;
    if (p == null) return;
    try {
      await p.setSubtitleTrack(
        (url == null || url.isEmpty) ? SubtitleTrack.no() : SubtitleTrack.uri(url),
      );
      // A freshly-loaded track must inherit the room's current timing offset.
      await _applySubtitleOffsetToPlayer(state.subtitleSettings.offset);
    } catch (_) {
      /* platform without external-subtitle support — ignore */
    }
  }

  /// Shifts the file-room player's subtitles by [offset] seconds via libmpv's
  /// `sub-delay` (positive = later, negative = earlier). No-op on web / embed
  /// rooms (no [NativePlayer]); embed rooms shift their own overlay instead.
  Future<void> _applySubtitleOffsetToPlayer(double offset) async {
    final platform = _player?.platform;
    if (platform is! NativePlayer) return;
    try {
      await platform.setProperty('sub-delay', offset.toString());
    } catch (_) {
      /* property unsupported on this backend — ignore */
    }
  }

  /// Applies a settings update that arrived from another client (or the join
  /// seed): reflect it in state and on the player, without rebroadcasting.
  void _applyRemoteSubtitleSettings(SubtitleSettings s) {
    emit(state.copyWith(subtitleSettings: s));
    _applySubtitleOffsetToPlayer(s.offset);
  }

  /// Changes the room's shared subtitle settings. Applies locally right away
  /// (instant feedback for the slider) and, when [broadcast] is true, relays
  /// the change so every other client converges. The drag uses
  /// `broadcast: false`; the release uses the default `true`.
  void setSubtitleSettings(SubtitleSettings s, {bool broadcast = true}) {
    emit(state.copyWith(subtitleSettings: s));
    _applySubtitleOffsetToPlayer(s.offset);
    if (broadcast) {
      _repo.setSubtitleSettings(offset: s.offset, weight: s.weight, size: s.size);
    }
  }

  /// Best-effort libmpv tuning for streamed file/torrent playback. No-op on web
  /// (no [NativePlayer]).
  ///
  /// * `hwdec=auto-safe` — decode on the GPU when a known-safe path exists, so
  ///   heavy codecs (H.265/HEVC) and 4K/2160p play smoothly instead of pegging
  ///   the CPU; libmpv falls back to software decoding automatically when the
  ///   hardware can't handle the stream, rather than surfacing "no video". (A
  ///   device whose decoder truly can't do the format still can't play it — the
  ///   real fix there is a 1080p/H.264 source.)
  /// * `cache` + `demuxer-max-back-bytes` — keep a read cache and a generous
  ///   back-buffer so re-seeks within a video don't re-download.
  Future<void> _tuneNativePlayer(Player player) async {
    final platform = player.platform;
    if (platform is! NativePlayer) return;
    try {
      await platform.setProperty('hwdec', 'auto-safe');
      await platform.setProperty('cache', 'yes');
      await platform.setProperty('demuxer-max-back-bytes', '${48 * 1024 * 1024}');
    } catch (_) {
      /* property unsupported on this backend — ignore */
    }
  }

  /// Drives the buffer-wait gate from the player's buffering stream.
  void _onBuffering(bool buffering) {
    emit(state.copyWith(isBuffering: buffering));
    final playing = _player?.state.playing ?? false;

    // Report a *sustained* stall so a momentary hiccup doesn't pause the room.
    if (buffering && playing) {
      _bufferDebounce ??= Timer(AppConstants.bufferReportDelay, () {
        if (!_reportedBuffering) {
          _reportedBuffering = true;
          _repo.setBuffering(true);
        }
      });
    } else {
      _bufferDebounce?.cancel();
      _bufferDebounce = null;
      if (_reportedBuffering) {
        _reportedBuffering = false;
        _repo.setBuffering(false);
      }
    }

    _updateTorrentStallWatchdog(buffering);
  }

  /// Runs a one-shot watchdog while an on-device torrent stream is stalled: if
  /// it can't recover within [_torrentStallTimeout], the swarm is unreachable
  /// from this device, so fall back to the server stream. Armed when buffering
  /// begins (and on the paused→playing transition, so a stream that's dead from
  /// the start is still caught once playback is requested). Cancelled the moment
  /// buffering clears — the stream is healthy after all.
  void _armTorrentStallWatchdog() {
    if (!_onDeviceTorrent || _torrentStallTimer != null) return;
    final gen = _playerGeneration;
    _torrentStallTimer = Timer(_torrentStallTimeout, () {
      _torrentStallTimer = null;
      // Only fall back if we're still on the *same* on-device torrent player and
      // it's still stalled — never strand a healthy or already-swapped stream.
      if (gen == _playerGeneration && _onDeviceTorrent && state.isBuffering) {
        _useServerStream();
      }
    });
  }

  void _updateTorrentStallWatchdog(bool buffering) {
    if (buffering) {
      _armTorrentStallWatchdog();
    } else {
      _torrentStallTimer?.cancel();
      _torrentStallTimer = null;
    }
  }

  void _onSync(PlaybackSync s) {
    emit(state.copyWith(lastSync: s));
    if (state.isExternal) {
      // Embed rooms can't be seeked cross-origin; the WebView simply tracks
      // the virtual clock (lastSync) for the subtitle overlay.
      emit(state.copyWith(isPlaying: s.isPlaying, playbackRate: s.playbackRate));
      return;
    }
    _applyToVideo(s);
  }

  void _onForceResync(PlaybackSync s) {
    emit(state.copyWith(lastSync: s));
    if (state.isExternal) {
      emit(
        state.copyWith(
          isPlaying: s.isPlaying,
          playbackRate: s.playbackRate,
          resyncTick: state.resyncTick + 1,
        ),
      );
    } else {
      _applyToVideo(s);
    }
  }

  void _onSourceChanged(dynamic change) {
    final url = change.url as String;
    final s = change.sync as PlaybackSync;
    emit(
      state.copyWith(
        externalUrl: url,
        isPlaying: s.isPlaying,
        playbackRate: s.playbackRate,
        messages: const [],
        resyncTick: state.resyncTick + 1,
        lastSync: s,
      ),
    );
  }

  Future<void> _applyToVideo(PlaybackSync s) async {
    final p = _player;
    if (p == null || !state.videoReady) {
      _pendingSync = s;
      return;
    }
    // If the player is swapped out mid-await (e.g. a torrent→server fallback),
    // bail rather than drive a disposed player.
    final gen = _playerGeneration;
    bool stale() => isClosed || _playerGeneration != gen;

    if (s.playbackRate > 0 && (p.state.rate - s.playbackRate).abs() > 0.01) {
      await p.setRate(s.playbackRate);
      if (stale()) return;
    }
    final target = s.effectiveTime();
    final current = p.state.position.inMilliseconds / 1000.0;
    if ((target - current).abs() > AppConstants.hardSeekThresholdSeconds) {
      await p.seek(Duration(milliseconds: (target * 1000).round()));
      if (stale()) return;
    }
    if (s.isPlaying && !p.state.playing) {
      // Starting playback on an on-device torrent that may already be dead:
      // arm the stall watchdog now so it's caught even if it never buffers.
      if (_onDeviceTorrent) _armTorrentStallWatchdog();
      await p.play();
      if (stale()) return;
    } else if (!s.isPlaying && p.state.playing) {
      await p.pause();
      if (stale()) return;
    }
    emit(state.copyWith(isPlaying: s.isPlaying, playbackRate: s.playbackRate));
  }

  // ===========================================================================
  // User playback controls (file rooms) — emit `control` to the room
  // ===========================================================================

  double get _seconds => (_player?.state.position.inMilliseconds ?? 0) / 1000.0;

  Future<void> togglePlay() async {
    final p = _player;
    if (p == null) return;
    if (p.state.playing) {
      await p.pause();
      _repo.sendControl(action: 'pause', currentTime: _seconds);
    } else {
      await p.play();
      _repo.sendControl(action: 'play', currentTime: _seconds);
    }
  }

  /// Update only the displayed position while the user drags the slider —
  /// avoids spamming `control` events until the drag ends.
  void emitLocalSeekPreview(Duration position) => emit(state.copyWith(position: position));

  Future<void> seekTo(Duration position) async {
    final p = _player;
    if (p == null) return;
    await p.seek(position);
    _repo.sendControl(action: 'seek', currentTime: position.inMilliseconds / 1000.0);
  }

  /// Skip by [delta] (e.g. ±10s), clamped to the video's bounds. Like a manual
  /// seek, this syncs the whole room via the `control` event.
  Future<void> seekBy(Duration delta) async {
    final p = _player;
    if (p == null) return;
    final dur = p.state.duration;
    var target = p.state.position + delta;
    if (target < Duration.zero) target = Duration.zero;
    if (dur > Duration.zero && target > dur) target = dur;
    await seekTo(target);
  }

  Future<void> setRate(double rate) async {
    final p = _player;
    if (p == null) return;
    await p.setRate(rate);
    emit(state.copyWith(playbackRate: rate));
    _repo.sendControl(action: 'rate', rate: rate);
  }

  // ===========================================================================
  // Social + room ops
  // ===========================================================================

  /// A delivered message from the server (possibly our own, echoed back).
  void _onChat(ChatMessage m) {
    // Our own message coming back: reconcile the optimistic bubble in place
    // (confirm it) instead of appending a duplicate — and don't float it.
    if (m.clientId != null) {
      final idx = state.messages.indexWhere((x) => x.mine && x.clientId == m.clientId);
      if (idx != -1) {
        _sendTimers.remove(m.clientId)?.cancel();
        final updated = [...state.messages];
        updated[idx] = m.copyWith(mine: true, status: ChatStatus.sent);
        emit(state.copyWith(messages: updated));
        return;
      }
    }
    // A re-broadcast of something we already have (by server id): ignore.
    if (state.messages.any((x) => x.id == m.id && !x.isPending)) return;

    emit(state.copyWith(messages: _capped([...state.messages, m])));
    if (!_incomingChat.isClosed) _incomingChat.add(m);
  }

  /// The recent-history backlog (sent on join / re-join). It's authoritative for
  /// delivered messages, but must not wipe optimistic messages we're still
  /// trying to send — so we keep any unconfirmed locals the backlog lacks.
  void _onChatHistory(List<ChatMessage> history) {
    final mine = _identity.state;
    final knownIds = {
      for (final m in history) ...[m.id, if (m.clientId != null) m.clientId!],
    };
    final merged = [for (final m in history) m.copyWith(mine: m.mine || m.name == mine)];
    for (final local in state.messages) {
      final stillUnsent =
          local.mine && local.isPending && !(local.clientId != null && knownIds.contains(local.clientId));
      if (stillUnsent) merged.add(local);
    }
    emit(state.copyWith(messages: _capped(merged)));
  }

  /// A throttled send: flag the matching optimistic message as failed so the
  /// user can retry it (the snackbar warning is shown separately by the UI).
  void _onChatThrottled(String? clientId) {
    if (clientId != null) _markChatStatus(clientId, ChatStatus.failed);
  }

  List<ChatMessage> _capped(List<ChatMessage> msgs) {
    if (msgs.length <= AppConstants.chatHistoryLimit) return msgs;
    return msgs.sublist(msgs.length - AppConstants.chatHistoryLimit);
  }

  /// Sends [text], showing it immediately as a "sending" bubble. The bubble is
  /// confirmed when the server echoes it back (matched by `clientId`); if that
  /// doesn't happen it stays queued, is re-sent on reconnect, and flips to
  /// "failed" after a timeout so the user can retry. Nothing is ever lost to a
  /// flaky connection.
  void sendChat(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    final clientId = '${DateTime.now().microsecondsSinceEpoch}-${_chatSeq++}';
    final msg = ChatMessage.local(
      clientId: clientId,
      name: _identity.state,
      text: trimmed,
      ts: DateTime.now().millisecondsSinceEpoch,
    );
    emit(state.copyWith(messages: _capped([...state.messages, msg])));
    _dispatchChat(clientId, trimmed);
  }

  /// Re-sends a failed message (tap-to-retry from the chat UI).
  void retryChat(ChatMessage m) {
    if (!m.mine || m.clientId == null || !m.isPending) return;
    _markChatStatus(m.clientId!, ChatStatus.sending);
    _dispatchChat(m.clientId!, m.text);
  }

  /// Emits a chat send and (re)arms its delivery timeout.
  void _dispatchChat(String clientId, String text) {
    _repo.sendChat(text, clientId: clientId);
    _sendTimers.remove(clientId)?.cancel();
    _sendTimers[clientId] = Timer(_sendTimeout, () {
      _sendTimers.remove(clientId);
      _markChatStatus(clientId, ChatStatus.failed);
    });
  }

  /// Re-sends every still-pending outgoing message — called when the socket
  /// reconnects. The server dedupes by `clientId`, so re-sends are harmless.
  void _flushChatOutbox() {
    final pending =
        state.messages.where((m) => m.mine && m.isPending && m.clientId != null).toList();
    for (final m in pending) {
      _markChatStatus(m.clientId!, ChatStatus.sending);
      _dispatchChat(m.clientId!, m.text);
    }
  }

  /// Updates the delivery [status] of the pending message with [clientId].
  void _markChatStatus(String clientId, ChatStatus status) {
    final idx = state.messages.indexWhere((m) => m.clientId == clientId && m.isPending);
    if (idx == -1) return;
    final updated = [...state.messages];
    updated[idx] = updated[idx].copyWith(status: status);
    emit(state.copyWith(messages: updated));
  }

  void sendReaction(String emoji) {
    _repo.sendReaction(emoji);
    if (!_reactions.isClosed) {
      _reactions.add(ReactionEvent(emoji: emoji, id: 'me', name: ''));
    }
  }

  /// Adds a custom emoji to this session's reaction palette (shared by the
  /// portrait and fullscreen bars). No-op if it's already present. A new list
  /// instance is emitted so both bars rebuild.
  void addSessionReaction(String emoji) {
    final e = emoji.trim();
    if (e.isEmpty || state.sessionReactions.contains(e)) return;
    emit(state.copyWith(sessionReactions: [...state.sessionReactions, e]));
  }

  void requestResync() => _repo.requestResync();

  /// Toggles the per-user touch lock (local only — never sent to the room).
  /// While locked, [VideoSurface] ignores taps on the video and its playback
  /// controls, so a faulty screen can't trigger play/pause/seek.
  void toggleControlsLock() => emit(state.copyWith(controlsLocked: !state.controlsLocked));

  void changeSource(String url) {
    final trimmed = url.trim();
    if (trimmed.isEmpty || !trimmed.startsWith('http')) return;
    _repo.changeSource(trimmed);
  }

  /// Returns null on success, or a translation key on failure.
  Future<String?> uploadSubtitle(String filePath) async {
    final res = await _uploadSubtitle(
      UploadSubtitleParams(slug: state.room!.slug, filePath: filePath),
    );
    return res.fold((f) => f.message, (_) => null);
  }

  /// Returns null on success, or a translation key on failure.
  Future<String?> deleteRoom({String? password}) async {
    final res = await _deleteRoom(
      DeleteRoomParams(slug: state.room!.slug, password: password),
    );
    return res.fold((f) => f.message, (_) {
      emit(state.copyWith(phase: WatchPhase.deleted));
      return null;
    });
  }

  // ===========================================================================
  // Teardown
  // ===========================================================================

  @override
  Future<void> close() async {
    _bufferDebounce?.cancel();
    _torrentStallTimer?.cancel();
    for (final t in _sendTimers.values) {
      t.cancel();
    }
    _sendTimers.clear();
    for (final s in _subs) {
      await s.cancel();
    }
    for (final s in _playerSubs) {
      await s.cancel();
    }
    await _player?.dispose();
    _repo.leave();
    await _reactions.close();
    await _incomingChat.close();
    return super.close();
  }
}
