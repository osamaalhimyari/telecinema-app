import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '/logic/identity/identity_cubit.dart';
import '../../../data/datasources/watch_socket_datasource.dart';
import '../../../domain/repositories/watch_repository.dart';
import 'voice_state.dart';

/// Push-to-talk voice over the room socket. A talk burst is recorded to a
/// short AAC clip, then relayed (`voice_start` → `voice_chunk` → `voice_end`)
/// to everyone else, who play it back. The server does no mixing — it only
/// forwards bytes — so this interoperates cleanly **mobile↔mobile**. (Web
/// peers use MediaRecorder/webm, which mobile cannot decode incrementally;
/// that cross-platform gap is inherent to the relay design.)
class VoiceCubit extends Cubit<VoiceState> {
  VoiceCubit(this._repo, this._identity) : super(const VoiceState()) {
    _sub = _repo.voice.listen(_onVoice);
  }

  final WatchRepository _repo;
  final IdentityCubit _identity;
  final AudioRecorder _recorder = AudioRecorder();

  /// Local id under which we list *ourselves* in [VoiceState.speakers] while
  /// transmitting, so the speaker also sees their own "speaking" label — not
  /// only the listeners do. Never collides with a real socket id.
  static const _meId = 'me';

  StreamSubscription<VoiceEvent>? _sub;

  /// Reassembling buffers + players keyed by speaker socket id.
  final Map<String, List<int>> _incoming = {};
  final Map<String, AudioPlayer> _players = {};

  static const _mime = 'audio/aac';

  /// `start()` (permission + recorder init) is async; track it so a release
  /// that arrives mid-startup isn't dropped (which used to leave the recorder
  /// running and send nothing).
  bool _startingMic = false;
  bool _stopRequested = false;
  String? _recordPath;

  // ---- transmit ----------------------------------------------------------

  Future<void> startTalking() async {
    if (state.micActive || _startingMic) return;
    _startingMic = true;
    _stopRequested = false;
    try {
      if (!await _recorder.hasPermission()) {
        emit(state.copyWith(permissionDenied: true));
        return;
      }
      final dir = await getTemporaryDirectory();
      _recordPath = '${dir.path}/ptt_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _recorder.start(
        // Full-duplex: keep playback alive while the mic is hot so you hear
        // others (and the video) *while* talking, instead of the OS muting
        // output for a record-only session. Echo cancellation + the voice-
        // communication audio path stop the speaker output from feeding back
        // into the mic (which would otherwise howl).
        //   - iOS: mixWithOthers makes the playAndRecord session mix with other
        //     audio rather than silence it; defaultToSpeaker keeps it on speaker.
        //   - Android: the voiceCommunication source + modeInCommunication put
        //     the device in VoIP mode (built-in AEC, simultaneous mic+speaker);
        //     speakerphone keeps audio on the loudspeaker.
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          numChannels: 1,
          sampleRate: 24000,
          echoCancel: true,
          noiseSuppress: true,
          autoGain: true,
          androidConfig: AndroidRecordConfig(
            audioSource: AndroidAudioSource.voiceCommunication,
            audioManagerMode: AudioManagerMode.modeInCommunication,
            speakerphone: true,
          ),
          iosConfig: IosRecordConfig(
            categoryOptions: [
              IosAudioCategoryOption.mixWithOthers,
              IosAudioCategoryOption.defaultToSpeaker,
              IosAudioCategoryOption.allowBluetooth,
              IosAudioCategoryOption.allowBluetoothA2DP,
            ],
          ),
        ),
        path: _recordPath!,
      );
      emit(state.copyWith(micActive: true, permissionDenied: false));
      // Show ourselves in the speaking indicator too (listeners already see us).
      _markSpeaking(_meId, _identity.state.trim(), true);
      HapticFeedback.vibrate(); // short buzz — you're live, start talking
      _repo.voiceStart(_mime);
    } catch (_) {
      emit(state.copyWith(micActive: false));
      _recordPath = null;
    } finally {
      _startingMic = false;
      // Released while we were still starting up → stop (and send) now.
      if (_stopRequested) await stopTalking();
    }
  }

  Future<void> stopTalking() async {
    // Release arrived before startup finished — defer to startTalking's finally.
    if (_startingMic) {
      _stopRequested = true;
      return;
    }
    if (!state.micActive) return;
    emit(state.copyWith(micActive: false));
    _markSpeaking(_meId, '', false);

    String? path;
    try {
      path = await _recorder.stop();
    } catch (_) {
      path = null;
    }
    path ??= _recordPath;
    _recordPath = null;

    if (path != null) {
      try {
        final bytes = await File(path).readAsBytes();
        if (bytes.isNotEmpty) _repo.voiceChunk(bytes);
      } catch (_) {
        /* nothing to send */
      }
    }
    _repo.voiceEnd();
  }

  // ---- receive -----------------------------------------------------------

  void _onVoice(VoiceEvent e) {
    switch (e.phase) {
      case VoicePhase.start:
        _incoming[e.id] = <int>[];
        _markSpeaking(e.id, e.name ?? 'Anonymous', true);
      case VoicePhase.chunk:
        if (e.chunk != null) (_incoming[e.id] ??= <int>[]).addAll(e.chunk!);
      case VoicePhase.end:
        _markSpeaking(e.id, state.speakers[e.id] ?? '', false);
        final bytes = _incoming.remove(e.id);
        if (bytes != null && bytes.isNotEmpty) _play(e.id, bytes);
    }
  }

  void _markSpeaking(String id, String name, bool talking) {
    final next = Map<String, String>.from(state.speakers);
    if (talking) {
      next[id] = name;
    } else {
      next.remove(id);
    }
    emit(state.copyWith(speakers: next));
  }

  Future<void> _play(String id, List<int> bytes) async {
    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/rx_${id}_${DateTime.now().millisecondsSinceEpoch}.m4a');
      await file.writeAsBytes(bytes, flush: true);

      final player = _players.putIfAbsent(id, AudioPlayer.new);
      await player.setFilePath(file.path);
      await player.play();
    } catch (_) {
      /* unplayable clip (e.g. a web/webm peer) — ignore */
    }
  }

  @override
  Future<void> close() async {
    await _sub?.cancel();
    try {
      if (await _recorder.isRecording()) await _recorder.stop();
    } catch (_) {}
    await _recorder.dispose();
    for (final p in _players.values) {
      await p.dispose();
    }
    return super.close();
  }
}
