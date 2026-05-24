import 'package:equatable/equatable.dart';

import '/features/rooms/domain/entities/room.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/entities/playback_sync.dart';
import '../../domain/entities/presence_user.dart';

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
    this.viewerCount = 0,
    this.presence = const [],
    this.waiting = const [],
    this.messages = const [],
    this.externalUrl,
    this.resyncTick = 0,
    this.subtitleUrl,
    this.lastSync,
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

  // Social
  final int viewerCount;
  final List<PresenceUser> presence;

  /// Viewers currently holding the room paused (buffer gate).
  final List<PresenceUser> waiting;
  final List<ChatMessage> messages;

  // External (embed) rooms
  final String? externalUrl;

  /// Bumped to ask the WebView to reload at the authoritative position.
  final int resyncTick;
  final String? subtitleUrl;

  /// The last authoritative sync — drives the virtual playhead for the
  /// subtitle overlay on external (embed) rooms, where we can't read the
  /// iframe's real position.
  final PlaybackSync? lastSync;

  bool get isExternal => room?.isExternal ?? false;
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
    int? viewerCount,
    List<PresenceUser>? presence,
    List<PresenceUser>? waiting,
    List<ChatMessage>? messages,
    String? externalUrl,
    int? resyncTick,
    String? subtitleUrl,
    PlaybackSync? lastSync,
  }) {
    return WatchState(
      phase: phase ?? this.phase,
      room: room ?? this.room,
      errorKey: errorKey ?? this.errorKey,
      unlockBusy: unlockBusy ?? this.unlockBusy,
      unlockErrorKey: clearUnlockError ? null : (unlockErrorKey ?? this.unlockErrorKey),
      isPlaying: isPlaying ?? this.isPlaying,
      playbackRate: playbackRate ?? this.playbackRate,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      isBuffering: isBuffering ?? this.isBuffering,
      videoReady: videoReady ?? this.videoReady,
      videoError: videoError ?? this.videoError,
      viewerCount: viewerCount ?? this.viewerCount,
      presence: presence ?? this.presence,
      waiting: waiting ?? this.waiting,
      messages: messages ?? this.messages,
      externalUrl: externalUrl ?? this.externalUrl,
      resyncTick: resyncTick ?? this.resyncTick,
      subtitleUrl: subtitleUrl ?? this.subtitleUrl,
      lastSync: lastSync ?? this.lastSync,
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
    viewerCount,
    presence,
    waiting,
    messages,
    externalUrl,
    resyncTick,
    subtitleUrl,
    lastSync,
  ];
}
