import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '/core/config/app_config.dart';
import '/core/extensions/context_extensions.dart';
import '../../domain/entities/chat_message.dart';
import '../bloc/voice_playback/voice_playback_cubit.dart';
import '../bloc/voice_playback/voice_playback_state.dart';

/// A chat voice message: play/pause + a progress bar + the length. While our own
/// clip is still uploading ([ChatMessage.audioUrl] null) it shows a spinner
/// instead of play. Playback is driven by the shared [VoicePlaybackCubit] (one
/// clip at a time). [dark] tunes colors for the fullscreen overlay.
class VoiceMessageBubble extends StatelessWidget {
  const VoiceMessageBubble({super.key, required this.message, this.dark = false});

  final ChatMessage message;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final url = AppConfig.voiceUrl(message.audioUrl);
    final ready = url != null;
    final accent = context.colors.primary;
    final fg = dark ? Colors.white : context.colors.onSurface;
    final totalMs = message.durationMs ?? 0;

    return BlocBuilder<VoicePlaybackCubit, VoicePlaybackState>(
      buildWhen: (a, b) {
        final wasActive = a.activeId == message.id;
        final isActive = b.activeId == message.id;
        if (wasActive != isActive) return true;
        return isActive &&
            (a.playing != b.playing || a.position != b.position || a.duration != b.duration);
      },
      builder: (context, pb) {
        final isActive = pb.activeId == message.id;
        final playing = isActive && pb.playing;
        final progress = isActive ? pb.progress : 0.0;
        // Count up the active clip's position; otherwise show the total length.
        final shownMs =
            isActive && pb.position > Duration.zero ? pb.position.inMilliseconds : totalMs;

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!ready)
              const Padding(
                padding: EdgeInsets.all(6),
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else
              InkResponse(
                radius: 24,
                onTap: () => context.read<VoicePlaybackCubit>().toggle(message.id, url),
                child: Icon(
                  playing ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded,
                  color: accent,
                  size: 34,
                ),
              ),
            const SizedBox(width: 8),
            SizedBox(
              width: 104,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: ready ? progress : null,
                  minHeight: 4,
                  backgroundColor: accent.withValues(alpha: 0.22),
                  color: accent,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.mic_rounded, size: 13, color: fg.withValues(alpha: 0.7)),
            const SizedBox(width: 2),
            Text(
              _fmt(shownMs),
              style: TextStyle(color: fg, fontSize: 11, fontFeatures: const []),
            ),
          ],
        );
      },
    );
  }

  String _fmt(int ms) {
    final total = (ms / 1000).round();
    final m = total ~/ 60;
    final s = total % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}
