import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '/core/config/app_config.dart';
import '/core/constants/app_constants.dart';
import '/core/localization/translation_keys.dart';
import '/features/rooms/domain/usecases/delete_room_usecase.dart';
import '/features/rooms/domain/usecases/get_room_usecase.dart';
import '/features/rooms/domain/usecases/unlock_room_usecase.dart';
import '/features/rooms/domain/usecases/upload_subtitle_usecase.dart';
import '/features/rooms/domain/entities/room.dart';
import '/logic/storage/key_value_storage.dart';
import '/logic/storage/shared_prefs_storage.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/entities/playback_sync.dart';
import '../../domain/entities/reaction_event.dart';
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
  ) : super(const WatchState());

  final WatchRepository _repo;
  final GetRoomUseCase _getRoom;
  final UnlockRoomUseCase _unlockRoom;
  final DeleteRoomUseCase _deleteRoom;
  final UploadSubtitleUseCase _uploadSubtitle;
  final KeyValueStorage _storage;
  final TorrentEngine _torrentEngine;

  Player? _player;

  /// The render handle for the [Video] widget. Lives as long as the player.
  VideoController? _videoController;
  VideoController? get videoController => _videoController;

  final List<StreamSubscription<dynamic>> _subs = [];
  Timer? _bufferDebounce;
  bool _reportedBuffering = false;
  PlaybackSync? _pendingSync;

  /// Transient floating-reaction feed for the overlay (not part of state).
  final _reactions = StreamController<ReactionEvent>.broadcast();
  Stream<ReactionEvent> get reactions => _reactions.stream;

  /// Transient feed of *incoming* chat for the fullscreen floating overlay.
  /// (Messages are still appended to `state.messages` for the chat panel.)
  final _incomingChat = StreamController<ChatMessage>.broadcast();
  Stream<ChatMessage> get incomingChat => _incomingChat.stream;

  Stream<void> get chatThrottled => _repo.chatThrottled;

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
  /// metadata is fetched, and surfaces a video error if it can't be resolved.
  Future<void> _initTorrentVideo(String magnet) async {
    emit(state.copyWith(preparingTorrent: true, videoError: false));
    try {
      final url = await _torrentEngine.resolve(magnet);
      if (isClosed) return;
      emit(state.copyWith(preparingTorrent: false));
      await _initVideo(url);
    } catch (_) {
      if (isClosed) return;
      emit(state.copyWith(preparingTorrent: false, videoError: true));
    }
  }

  void _subscribe() {
    _subs.addAll([
      _repo.sync.listen(_onSync),
      _repo.forceResync.listen(_onForceResync),
      _repo.chatHistory.listen((msgs) => emit(state.copyWith(messages: _capped(msgs)))),
      _repo.chat.listen(_onChat),
      _repo.viewerCount.listen((n) => emit(state.copyWith(viewerCount: n))),
      _repo.presence.listen((u) => emit(state.copyWith(presence: u))),
      _repo.waitState.listen((u) => emit(state.copyWith(waiting: u))),
      _repo.sourceChanged.listen(_onSourceChanged),
      _repo.subtitleChanged.listen(
        (f) => emit(state.copyWith(subtitleUrl: AppConfig.subtitleUrl(f))),
      ),
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

    _enableCache(player);

    _subs.addAll([
      player.stream.position.listen((p) => emit(state.copyWith(position: p))),
      player.stream.duration.listen((d) {
        if (d > Duration.zero) emit(state.copyWith(duration: d));
      }),
      player.stream.playing.listen((playing) => emit(state.copyWith(isPlaying: playing))),
      player.stream.buffering.listen(_onBuffering),
      player.stream.rate.listen((r) => emit(state.copyWith(playbackRate: r))),
      player.stream.error.listen((_) => emit(state.copyWith(videoError: true))),
    ]);

    try {
      await player.open(Media(url), play: false);
      emit(state.copyWith(videoReady: true, videoError: false));
      if (_pendingSync != null) {
        await _applyToVideo(_pendingSync!);
        _pendingSync = null;
      }
    } catch (_) {
      emit(state.copyWith(videoError: true));
    }
  }

  /// Best-effort: enable libmpv's read cache + a generous back-buffer so
  /// re-seeks within a video don't re-download. No-op on web (no [NativePlayer]).
  Future<void> _enableCache(Player player) async {
    final platform = player.platform;
    if (platform is! NativePlayer) return;
    try {
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
    if (s.playbackRate > 0 && (p.state.rate - s.playbackRate).abs() > 0.01) {
      await p.setRate(s.playbackRate);
    }
    final target = s.effectiveTime();
    final current = p.state.position.inMilliseconds / 1000.0;
    if ((target - current).abs() > AppConstants.hardSeekThresholdSeconds) {
      await p.seek(Duration(milliseconds: (target * 1000).round()));
    }
    if (s.isPlaying && !p.state.playing) {
      await p.play();
    } else if (!s.isPlaying && p.state.playing) {
      await p.pause();
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

  void _onChat(ChatMessage m) {
    emit(state.copyWith(messages: _capped([...state.messages, m])));
    if (!_incomingChat.isClosed) _incomingChat.add(m);
  }

  List<ChatMessage> _capped(List<ChatMessage> msgs) {
    if (msgs.length <= AppConstants.chatHistoryLimit) return msgs;
    return msgs.sublist(msgs.length - AppConstants.chatHistoryLimit);
  }

  void sendChat(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    _repo.sendChat(trimmed);
  }

  void sendReaction(String emoji) {
    _repo.sendReaction(emoji);
    if (!_reactions.isClosed) {
      _reactions.add(ReactionEvent(emoji: emoji, id: 'me', name: ''));
    }
  }

  void requestResync() => _repo.requestResync();

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
    for (final s in _subs) {
      await s.cancel();
    }
    await _player?.dispose();
    _repo.leave();
    await _reactions.close();
    await _incomingChat.close();
    return super.close();
  }
}
