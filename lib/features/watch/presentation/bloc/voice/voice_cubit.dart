import 'dart:async';
import 'dart:io';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

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
  VoiceCubit(this._repo) : super(const VoiceState()) {
    _sub = _repo.voice.listen(_onVoice);
  }

  final WatchRepository _repo;
  final AudioRecorder _recorder = AudioRecorder();

  StreamSubscription<VoiceEvent>? _sub;

  /// Reassembling buffers + players keyed by speaker socket id.
  final Map<String, List<int>> _incoming = {};
  final Map<String, AudioPlayer> _players = {};

  static const _mime = 'audio/aac';

  // ---- transmit ----------------------------------------------------------

  Future<void> startTalking() async {
    if (state.micActive) return;
    if (!await _recorder.hasPermission()) {
      emit(state.copyWith(permissionDenied: true));
      return;
    }
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/ptt_${DateTime.now().millisecondsSinceEpoch}.m4a';
    try {
      await _recorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc, numChannels: 1, sampleRate: 24000),
        path: path,
      );
      emit(state.copyWith(micActive: true, permissionDenied: false));
      _repo.voiceStart(_mime);
    } catch (_) {
      emit(state.copyWith(micActive: false));
    }
  }

  Future<void> stopTalking() async {
    if (!state.micActive) return;
    emit(state.copyWith(micActive: false));
    String? path;
    try {
      path = await _recorder.stop();
    } catch (_) {
      path = null;
    }
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
