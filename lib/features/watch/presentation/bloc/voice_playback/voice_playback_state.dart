import 'package:equatable/equatable.dart';

/// Playback state for chat voice messages. Only one clip plays at a time, keyed
/// by the chat message id.
class VoicePlaybackState extends Equatable {
  const VoicePlaybackState({
    this.activeId,
    this.playing = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
  });

  /// Id of the message currently loaded/playing, or null when nothing is.
  final String? activeId;
  final bool playing;
  final Duration position;
  final Duration duration;

  /// Progress 0..1 of the active clip (0 when unknown).
  double get progress {
    final total = duration.inMilliseconds;
    if (total <= 0) return 0;
    return (position.inMilliseconds / total).clamp(0.0, 1.0);
  }

  VoicePlaybackState copyWith({
    String? activeId,
    bool clearActive = false,
    bool? playing,
    Duration? position,
    Duration? duration,
  }) {
    return VoicePlaybackState(
      activeId: clearActive ? null : (activeId ?? this.activeId),
      playing: playing ?? this.playing,
      position: position ?? this.position,
      duration: duration ?? this.duration,
    );
  }

  @override
  List<Object?> get props => [activeId, playing, position, duration];
}
