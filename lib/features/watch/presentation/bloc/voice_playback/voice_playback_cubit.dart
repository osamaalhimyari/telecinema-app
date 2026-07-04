import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:just_audio/just_audio.dart';

import 'voice_playback_state.dart';

/// Plays chat voice messages, one at a time. Shared across the chat tab and the
/// fullscreen panel so tapping a second clip stops the first. Bubbles drive it
/// by message id + the clip URL.
class VoicePlaybackCubit extends Cubit<VoicePlaybackState> {
  VoicePlaybackCubit() : super(const VoicePlaybackState()) {
    _posSub = _player.positionStream.listen((p) {
      if (state.activeId != null) emit(state.copyWith(position: p));
    });
    _durSub = _player.durationStream.listen((d) {
      if (state.activeId != null && d != null) emit(state.copyWith(duration: d));
    });
    _stateSub = _player.playerStateStream.listen((s) {
      if (state.activeId == null) return;
      if (s.processingState == ProcessingState.completed) {
        // Reset to the start, paused, so it can be replayed.
        _player.pause();
        _player.seek(Duration.zero);
        emit(state.copyWith(playing: false, position: Duration.zero));
      } else {
        emit(state.copyWith(playing: s.playing));
      }
    });
  }

  final AudioPlayer _player = AudioPlayer();
  StreamSubscription<Duration>? _posSub;
  StreamSubscription<Duration?>? _durSub;
  StreamSubscription<PlayerState>? _stateSub;

  /// Play/pause [id] (loading [url] the first time). Tapping a different clip
  /// switches to it.
  Future<void> toggle(String id, String url) async {
    if (state.activeId == id) {
      if (_player.playing) {
        await _player.pause();
      } else {
        await _player.play();
      }
      return;
    }
    // A different clip — load and play it.
    emit(VoicePlaybackState(activeId: id));
    try {
      await _player.setUrl(url);
      await _player.play();
    } catch (_) {
      if (state.activeId == id) emit(const VoicePlaybackState());
    }
  }

  @override
  Future<void> close() async {
    await _posSub?.cancel();
    await _durSub?.cancel();
    await _stateSub?.cancel();
    await _player.dispose();
    return super.close();
  }
}
