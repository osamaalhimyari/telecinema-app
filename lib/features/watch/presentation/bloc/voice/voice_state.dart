import 'package:equatable/equatable.dart';

class VoiceState extends Equatable {
  const VoiceState({
    this.micActive = false,
    this.speakers = const {},
    this.permissionDenied = false,
  });

  /// True while *we* are holding the talk button and transmitting.
  final bool micActive;

  /// socketId → display name of viewers currently talking.
  final Map<String, String> speakers;

  final bool permissionDenied;

  bool get someoneTalking => speakers.isNotEmpty;

  VoiceState copyWith({bool? micActive, Map<String, String>? speakers, bool? permissionDenied}) {
    return VoiceState(
      micActive: micActive ?? this.micActive,
      speakers: speakers ?? this.speakers,
      permissionDenied: permissionDenied ?? this.permissionDenied,
    );
  }

  @override
  List<Object?> get props => [micActive, speakers, permissionDenied];
}
