import 'package:equatable/equatable.dart';

enum VoiceRecordPhase { idle, recording }

/// Local state of the hold-to-record mic in the chat composer.
class VoiceMessageState extends Equatable {
  const VoiceMessageState({
    this.phase = VoiceRecordPhase.idle,
    this.elapsedMs = 0,
    this.cancelling = false,
    this.permissionDenied = false,
  });

  final VoiceRecordPhase phase;

  /// Elapsed recording time, for the live timer.
  final int elapsedMs;

  /// True while the finger has slid into the "cancel" zone — releasing now
  /// discards the clip instead of sending it.
  final bool cancelling;

  /// Set when the mic permission was refused (the UI surfaces a hint).
  final bool permissionDenied;

  bool get isRecording => phase == VoiceRecordPhase.recording;

  VoiceMessageState copyWith({
    VoiceRecordPhase? phase,
    int? elapsedMs,
    bool? cancelling,
    bool? permissionDenied,
  }) {
    return VoiceMessageState(
      phase: phase ?? this.phase,
      elapsedMs: elapsedMs ?? this.elapsedMs,
      cancelling: cancelling ?? this.cancelling,
      permissionDenied: permissionDenied ?? this.permissionDenied,
    );
  }

  @override
  List<Object?> get props => [phase, elapsedMs, cancelling, permissionDenied];
}
