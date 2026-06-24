import 'package:equatable/equatable.dart';

import '/features/rooms/domain/entities/room.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/entities/playback_sync.dart';
import '../../domain/entities/presence_user.dart';
import '../../domain/entities/subtitle_settings.dart';

enum WatchPhase { initializing, locked, ready, deleted, error }

class WatchState extends Equatable {
  const WatchState({
    this.phase = WatchPhase.initializing,
    this.room,
    this.errorKey,
    this.unlockBusy = false,
    this.unlockErrorKey,
    this.isPlaying = false,
    this.playbackRate = 1.0,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.isBuffering = false,
    this.videoReady = false,
    this.videoError = false,
    this.videoAspectRatio = 16 / 9,
    this.preparingTorrent = false,
    this.viewerCount = 0,
    this.presence = const [],
    this.waiting = const [],
    this.messages = const [],
    this.sessionReactions = const [],
    this.typingUsers = const {},
    this.externalUrl,
    this.resyncTick = 0,
    this.subtitleUrl,
    this.subtitleSettings = const SubtitleSettings.defaults(),
    this.lastSync,
    this.bookmarkVersion = 0,
    this.controlsLocked = false,
  });

  final WatchPhase phase;
  final Room? room;
  final String? errorKey;

  // Password gate
  final bool unlockBusy;
  final String? unlockErrorKey;

  // Playback (file rooms)
  final bool isPlaying;
  final double playbackRate;
  final Duration position;
  final Duration duration;
  final bool isBuffering;
  final bool videoReady;
  final bool videoError;

  /// Real video aspect ratio (width / height) once known, else 16:9. Drives the
  /// portrait player height so the video isn't boxed into a fixed half-screen.
  final double videoAspectRatio;

  /// True while the on-device torrent engine is resolving the magnet (fetching
  /// swarm metadata) before the player can open the local stream URL.
  final bool preparingTorrent;

  // Social
  final int viewerCount;
  final List<PresenceUser> presence;

  /// Viewers currently holding the room paused (buffer gate).
  final List<PresenceUser> waiting;
  final List<ChatMessage> messages;

  /// Custom emoji added via the reaction bar's `+` this session (on top of the
  /// room's server-defined palette). Lives in shared state so the portrait and
  /// fullscreen reaction bars show the same list — adding one in either appears
  /// in both.
  final List<String> sessionReactions;

  /// Other viewers currently typing a chat message, `socketId → display name`.
  /// Each entry auto-expires in the cubit so it can never get stuck on a lost
  /// "stopped typing" signal.
  final Map<String, String> typingUsers;

  // External (embed) rooms
  final String? externalUrl;

  /// Bumped to ask the WebView to reload at the authoritative position.
  final int resyncTick;
  final String? subtitleUrl;

  /// The room's shared subtitle display settings (timing offset, weight, size),
  /// synchronized across every client.
  final SubtitleSettings subtitleSettings;

  /// The last authoritative sync — drives the virtual playhead for the
  /// subtitle overlay on external (embed) rooms, where we can't read the
  /// iframe's real position.
  final PlaybackSync? lastSync;

  /// Incremented each time bookmarks change so UI that depends on them can
  /// rebuild even though bookmarks are stored outside [WatchState].
  final int bookmarkVersion;

  /// Per-user, local-only touch lock. When true, the video's tap layer and
  /// playback controls are disabled (so a faulty screen's ghost-touches can't
  /// play/pause/seek) — emoji, chat and the mic stay fully usable. Never synced
  /// to other viewers.
  final bool controlsLocked;

  bool get isExternal => room?.isExternal ?? false;

  /// Live-TV room — plays a remote HLS stream natively; no scrub/seek timeline.
  bool get isLive => room?.isTv ?? false;

  bool get someoneWaiting => waiting.isNotEmpty;

  WatchState copyWith({
    WatchPhase? phase,
    Room? room,
    String? errorKey,
    bool? unlockBusy,
    String? unlockErrorKey,
    bool clearUnlockError = false,
    bool? isPlaying,
    double? playbackRate,
    Duration? position,
    Duration? duration,
    bool? isBuffering,
    bool? videoReady,
    bool? videoError,
    double? videoAspectRatio,
    bool? preparingTorrent,
    int? viewerCount,
    List<PresenceUser>? presence,
    List<PresenceUser>? waiting,
    List<ChatMessage>? messages,
    List<String>? sessionReactions,
    Map<String, String>? typingUsers,
    String? externalUrl,
    int? resyncTick,
    String? subtitleUrl,
    SubtitleSettings? subtitleSettings,
    PlaybackSync? lastSync,
    int? bookmarkVersion,
    bool? controlsLocked,
  }) {
    return WatchState(
      phase: phase ?? this.phase,
      room: room ?? this.room,
      errorKey: errorKey ?? this.errorKey,
      unlockBusy: unlockBusy ?? this.unlockBusy,
      unlockErrorKey: clearUnlockError
          ? null
          : (unlockErrorKey ?? this.unlockErrorKey),
      isPlaying: isPlaying ?? this.isPlaying,
      playbackRate: playbackRate ?? this.playbackRate,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      isBuffering: isBuffering ?? this.isBuffering,
      videoReady: videoReady ?? this.videoReady,
      videoError: videoError ?? this.videoError,
      videoAspectRatio: videoAspectRatio ?? this.videoAspectRatio,
      preparingTorrent: preparingTorrent ?? this.preparingTorrent,
      viewerCount: viewerCount ?? this.viewerCount,
      presence: presence ?? this.presence,
      waiting: waiting ?? this.waiting,
      messages: messages ?? this.messages,
      sessionReactions: sessionReactions ?? this.sessionReactions,
      typingUsers: typingUsers ?? this.typingUsers,
      externalUrl: externalUrl ?? this.externalUrl,
      resyncTick: resyncTick ?? this.resyncTick,
      subtitleUrl: subtitleUrl ?? this.subtitleUrl,
      subtitleSettings: subtitleSettings ?? this.subtitleSettings,
      lastSync: lastSync ?? this.lastSync,
      bookmarkVersion: bookmarkVersion ?? this.bookmarkVersion,
      controlsLocked: controlsLocked ?? this.controlsLocked,
    );
  }

  @override
  List<Object?> get props => [
    phase,
    room,
    errorKey,
    unlockBusy,
    unlockErrorKey,
    isPlaying,
    playbackRate,
    position,
    duration,
    isBuffering,
    videoReady,
    videoError,
    videoAspectRatio,
    preparingTorrent,
    viewerCount,
    presence,
    waiting,
    messages,
    sessionReactions,
    typingUsers,
    externalUrl,
    resyncTick,
    subtitleUrl,
    subtitleSettings,
    lastSync,
    bookmarkVersion,
    controlsLocked,
  ];
}
