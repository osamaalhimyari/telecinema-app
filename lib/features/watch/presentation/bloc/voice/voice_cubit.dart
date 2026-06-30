import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '/logic/identity/identity_cubit.dart';
import '../../../data/datasources/watch_socket_datasource.dart';
import '../../../domain/entities/chat_message.dart';
import '../../../domain/repositories/watch_repository.dart';
import '../watch_cubit.dart';
import 'voice_state.dart';

/// Tap-to-talk **voice messages** over the room socket. A talk burst is recorded
/// to a short AAC clip, then relayed (`voice_start` → `voice_chunk` →
/// `voice_end`, each tagged with a `clipId`) to everyone else. Unlike a live
/// PTT, the clip is **not** auto-played: it lands in the chat as a tap-to-play
/// bubble (so the receiver sees a voice arrived), and the first time a listener
/// opens it a `voice_read` receipt flips the sender's bubble to "read".
///
/// The actual message bubbles live in [WatchCubit.state.messages] (so they
/// interleave with text chat and survive panel switches); this cubit owns the
/// audio engine — recording, playback, and the read-receipt wiring — and pushes
/// the messages across via [attach].
///
/// The server does no mixing — it only forwards bytes — so playback
/// interoperates cleanly **mobile↔mobile**. (Web peers use MediaRecorder/webm,
/// which mobile cannot decode; that cross-platform gap is inherent to the relay
/// design — such a clip simply fails to play when tapped.)
class VoiceCubit extends Cubit<VoiceState> {
  VoiceCubit(this._repo, this._identity) : super(const VoiceState()) {
    _sub = _repo.voice.listen(_onVoice);
    _readSub = _repo.voiceRead.listen(_onVoiceRead);
    _playbackSub = _playback.playerStateStream.listen((s) {
      if (s.processingState == ProcessingState.completed) {
        _playback.stop();
        if (!isClosed) emit(state.copyWith(clearPlaying: true));
      }
    });
  }

  final WatchRepository _repo;
  final IdentityCubit _identity;
  final AudioRecorder _recorder = AudioRecorder();

  /// Single tap-to-play player (only one note plays at a time).
  final AudioPlayer _playback = AudioPlayer();

  StreamSubscription<VoiceEvent>? _sub;
  StreamSubscription<String>? _readSub;
  StreamSubscription<PlayerState>? _playbackSub;

  /// The room brain that stores the message list. Wired in by the page (both
  /// cubits are page-scoped siblings); null until then.
  WatchCubit? _watch;
  void attach(WatchCubit watch) => _watch = watch;

  /// Reassembly state per speaker socket id (one in-flight clip per speaker).
  final Map<String, List<int>> _incoming = {};
  final Map<String, String?> _incomingClip = {};
  final Map<String, String> _incomingName = {};

  static const _mime = 'audio/aac';

  /// `start()` (permission + recorder init) is async; track it so a release
  /// that arrives mid-startup isn't dropped.
  bool _startingMic = false;
  bool _stopRequested = false;
  String? _recordPath;

  /// The clipId of the burst we're currently recording (set on start).
  String? _currentClipId;
  int _seq = 0;
  String _newClipId() => 'v-${DateTime.now().microsecondsSinceEpoch}-${_seq++}';

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
        // Echo cancellation + the voice-communication audio path stop the
        // speaker output from feeding back into the mic while recording.
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
      _currentClipId = _newClipId();
      emit(state.copyWith(micActive: true, permissionDenied: false));
      HapticFeedback.vibrate(); // short buzz — you're live, start talking
      _repo.voiceStart(_mime, _currentClipId!);
    } catch (_) {
      emit(state.copyWith(micActive: false));
      _recordPath = null;
      _currentClipId = null;
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

    final clipId = _currentClipId;
    _currentClipId = null;

    String? path;
    try {
      path = await _recorder.stop();
    } catch (_) {
      path = null;
    }
    path ??= _recordPath;
    _recordPath = null;

    List<int>? bytes;
    if (path != null) {
      try {
        final b = await File(path).readAsBytes();
        if (b.isNotEmpty) {
          bytes = b;
          _repo.voiceChunk(b);
        }
      } catch (_) {
        /* nothing to send */
      }
    }
    _repo.voiceEnd(clipId ?? '');

    // Show our own sent note in the chat (tap to replay; flips to "read" once a
    // listener opens it). Skip empty/failed captures.
    if (clipId != null && bytes != null && bytes.isNotEmpty && path != null) {
      _watch?.addVoiceMessage(
        ChatMessage.voice(
          id: clipId,
          name: _identity.state,
          ts: DateTime.now().millisecondsSinceEpoch,
          mine: true,
          audioPath: path,
        ),
      );
      _probeDuration(clipId, path);
    }
  }

  // ---- receive -----------------------------------------------------------

  void _onVoice(VoiceEvent e) {
    switch (e.phase) {
      case VoicePhase.start:
        _incoming[e.id] = <int>[];
        _incomingClip[e.id] = e.clipId;
        _incomingName[e.id] = e.name ?? 'Anonymous';
        _markSpeaking(e.id, e.name ?? 'Anonymous', true);
      case VoicePhase.chunk:
        if (e.chunk != null) (_incoming[e.id] ??= <int>[]).addAll(e.chunk!);
      case VoicePhase.end:
        _markSpeaking(e.id, state.speakers[e.id] ?? '', false);
        final bytes = _incoming.remove(e.id);
        final tracked = _incomingClip.remove(e.id);
        final name = _incomingName.remove(e.id) ?? e.name ?? 'Anonymous';
        final clipId = _firstNonEmpty([e.clipId, tracked]) ??
            'rx-${e.id}-${DateTime.now().millisecondsSinceEpoch}';
        if (bytes != null && bytes.isNotEmpty) _ingestReceived(clipId, name, bytes);
    }
  }

  /// Writes a received clip to a file and pushes it into the chat as an unplayed
  /// voice note (no auto-play — the listener taps to open it).
  Future<void> _ingestReceived(String clipId, String name, List<int> bytes) async {
    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/rx_$clipId.m4a');
      await file.writeAsBytes(bytes, flush: true);
      _watch?.addVoiceMessage(
        ChatMessage.voice(
          id: clipId,
          name: name,
          ts: DateTime.now().millisecondsSinceEpoch,
          mine: false,
          audioPath: file.path,
        ),
      );
      _probeDuration(clipId, file.path);
    } catch (_) {
      /* couldn't persist the clip — drop it */
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

  // ---- playback ----------------------------------------------------------

  /// Tap-to-play a voice note. Tapping the one already playing stops it. The
  /// first time a *received* note is opened, a read receipt is sent so the
  /// sender's bubble flips to "read".
  Future<void> playMessage(ChatMessage m) async {
    final path = m.audioPath;
    if (path == null || !m.isVoice) return;

    if (state.playingId == m.id) {
      await _playback.stop();
      emit(state.copyWith(clearPlaying: true));
      return;
    }

    if (!m.mine && !m.voicePlayed) {
      _repo.sendVoiceRead(m.id);
      _watch?.markVoicePlayed(m.id);
    }

    try {
      emit(state.copyWith(playingId: m.id));
      await _playback.setFilePath(path);
      await _playback.play();
    } catch (_) {
      // Unplayable clip (e.g. a web/webm peer) — clear the playing state.
      if (!isClosed) emit(state.copyWith(clearPlaying: true));
    }
  }

  // ---- read receipts -----------------------------------------------------

  void _onVoiceRead(String clipId) => _watch?.markVoiceRead(clipId);

  // ---- helpers -----------------------------------------------------------

  Future<void> _probeDuration(String clipId, String path) async {
    try {
      final probe = AudioPlayer();
      final d = await probe.setFilePath(path);
      await probe.dispose();
      if (d != null && d > Duration.zero) {
        _watch?.updateVoiceDuration(clipId, d.inMilliseconds);
      }
    } catch (_) {
      /* duration stays 0 */
    }
  }

  String? _firstNonEmpty(List<String?> values) {
    for (final v in values) {
      if (v != null && v.isNotEmpty) return v;
    }
    return null;
  }

  @override
  Future<void> close() async {
    await _sub?.cancel();
    await _readSub?.cancel();
    await _playbackSub?.cancel();
    try {
      if (await _recorder.isRecording()) await _recorder.stop();
    } catch (_) {}
    await _recorder.dispose();
    await _playback.dispose();
    return super.close();
  }
}
