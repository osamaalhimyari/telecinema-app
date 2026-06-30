import 'package:equatable/equatable.dart';

class VoiceState extends Equatable {
  const VoiceState({
    this.micActive = false,
    this.speakers = const {},
    this.permissionDenied = false,
    this.playingId,
  });

  /// True while *we* are holding the talk button and recording.
  final bool micActive;

  /// socketId → display name of viewers currently recording a voice note.
  final Map<String, String> speakers;

  final bool permissionDenied;

  /// `id` of the voice message currently playing back (tap-to-play), or null.
  final String? playingId;

  bool get someoneTalking => speakers.isNotEmpty;

  VoiceState copyWith({
    bool? micActive,
    Map<String, String>? speakers,
    bool? permissionDenied,
    String? playingId,
    bool clearPlaying = false,
  }) {
    return VoiceState(
      micActive: micActive ?? this.micActive,
      speakers: speakers ?? this.speakers,
      permissionDenied: permissionDenied ?? this.permissionDenied,
      playingId: clearPlaying ? null : (playingId ?? this.playingId),
    );
  }

  @override
  List<Object?> get props => [micActive, speakers, permissionDenied, playingId];
}
