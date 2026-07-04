import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../watch_cubit.dart';
import 'voice_message_state.dart';

/// Hold-to-record voice messages for the chat composer. Records a clip while the
/// mic button is held; on release it hands the file to [WatchCubit.sendVoiceMessage]
/// (which uploads + sends it), unless the clip was too short or the gesture was
/// cancelled. One instance per composer.
class VoiceMessageCubit extends Cubit<VoiceMessageState> {
  VoiceMessageCubit(this._watch) : super(const VoiceMessageState());

  final WatchCubit _watch;
  final AudioRecorder _recorder = AudioRecorder();

  Timer? _ticker;
  String? _path;
  DateTime? _startedAt;

  /// Clips shorter than this are treated as an accidental tap and dropped.
  static const _minMs = 700;

  /// Hard cap — recording auto-sends when it reaches this length.
  static const _maxMs = 5 * 60 * 1000;

  Future<void> startRecording() async {
    if (state.isRecording) return;
    if (!await _recorder.hasPermission()) {
      emit(state.copyWith(permissionDenied: true));
      return;
    }
    final dir = await getTemporaryDirectory();
    _path = '${dir.path}/vm_${DateTime.now().millisecondsSinceEpoch}.m4a';
    try {
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          numChannels: 1,
          sampleRate: 44100,
          echoCancel: true,
          noiseSuppress: true,
          autoGain: true,
        ),
        path: _path!,
      );
    } catch (_) {
      _path = null;
      emit(state.copyWith(phase: VoiceRecordPhase.idle));
      return;
    }
    _startedAt = DateTime.now();
    HapticFeedback.selectionClick();
    emit(state.copyWith(
      phase: VoiceRecordPhase.recording,
      elapsedMs: 0,
      cancelling: false,
      permissionDenied: false,
    ));
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(milliseconds: 100), (_) {
      final ms = DateTime.now().difference(_startedAt!).inMilliseconds;
      emit(state.copyWith(elapsedMs: ms));
      if (ms >= _maxMs) finishAndSend();
    });
  }

  /// Reflects whether the finger is in the cancel zone (drives the visual cue).
  void setCancelling(bool cancelling) {
    if (state.isRecording && cancelling != state.cancelling) {
      emit(state.copyWith(cancelling: cancelling));
    }
  }

  /// Discards the in-progress recording (slide-to-cancel or pressed while busy).
  Future<void> cancel() async {
    if (!state.isRecording) return;
    await _stopRecorder(deleteFile: true);
    emit(const VoiceMessageState());
  }

  /// Stops recording and, unless cancelled or too short, sends the clip.
  Future<void> finishAndSend() async {
    if (!state.isRecording) return;
    final cancelled = state.cancelling;
    final elapsed = state.elapsedMs;
    final path = await _stopRecorder(deleteFile: false);
    emit(const VoiceMessageState());

    if (cancelled || path == null || elapsed < _minMs) {
      if (path != null) await File(path).delete().catchError((_) => File(path));
      return;
    }
    await _watch.sendVoiceMessage(path, elapsed);
  }

  /// Stops the recorder; returns the produced path (or deletes it when asked).
  Future<String?> _stopRecorder({required bool deleteFile}) async {
    _ticker?.cancel();
    _ticker = null;
    _startedAt = null;
    String? path;
    try {
      path = await _recorder.stop();
    } catch (_) {
      path = null;
    }
    path ??= _path;
    _path = null;
    if (deleteFile && path != null) {
      try {
        await File(path).delete();
      } catch (_) {
        /* already gone */
      }
      return null;
    }
    return path;
  }

  @override
  Future<void> close() async {
    _ticker?.cancel();
    try {
      if (await _recorder.isRecording()) await _recorder.stop();
    } catch (_) {}
    await _recorder.dispose();
    return super.close();
  }
}
