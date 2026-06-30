import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '/core/extensions/context_extensions.dart';
import '/core/localization/translation_keys.dart';
import '/core/shared/user_avatar.dart';
import '../../domain/entities/chat_message.dart';
import '../bloc/voice/voice_cubit.dart';
import '../bloc/voice/voice_state.dart';

/// A WhatsApp-style voice-note bubble: a play/stop button, the clip length, the
/// time it arrived, and — for our own sent notes — a single/double read-receipt
/// check (double = a listener opened it). Received notes carry a small "unheard"
/// dot until the first time they're played.
///
/// The audio + playing-state live in [VoiceCubit]; tapping play routes through
/// it (which also fires the read receipt for received clips).
class VoiceMessageBubble extends StatelessWidget {
  const VoiceMessageBubble({
    super.key,
    required this.message,
    required this.mine,
    this.onVideo = false,
  });

  final ChatMessage message;
  final bool mine;

  /// Translucent dark styling for the fullscreen-over-video messages panel.
  final bool onVideo;

  @override
  Widget build(BuildContext context) {
    final fg = onVideo ? Colors.white : context.colors.onSurface;
    final subtle = onVideo ? Colors.white70 : context.colors.onSurfaceVariant;
    final accent = onVideo ? Colors.white : context.colors.primary;
    final unheard = !mine && !message.voicePlayed;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      constraints: const BoxConstraints(maxWidth: 260),
      decoration: BoxDecoration(
        color: mine
            ? context.colors.primary.withValues(alpha: onVideo ? 0.35 : 0.38)
            : (onVideo ? Colors.white.withValues(alpha: 0.12) : context.colors.surface),
        borderRadius: BorderRadius.circular(14),
        border: onVideo ? null : Border.all(color: context.colors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!mine)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                message.name,
                style: context.text.labelMedium?.copyWith(
                  color: userColorFor(message.name),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _PlayButton(message: message, accent: accent, fg: onVideo ? Colors.black : Colors.white),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.mic_rounded, size: 15, color: subtle),
                      const SizedBox(width: 3),
                      Text(
                        context.tr(TranslationKeys.voiceMessage),
                        style: context.text.bodySmall?.copyWith(color: fg, fontWeight: FontWeight.w600),
                      ),
                      if (unheard) ...[
                        const SizedBox(width: 6),
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (message.durationMs > 0) ...[
                        Text(
                          _fmtDuration(message.durationMs),
                          style: context.text.labelSmall?.copyWith(color: subtle),
                        ),
                        const SizedBox(width: 6),
                      ],
                      Text(
                        _hhmm(message.time),
                        style: context.text.labelSmall?.copyWith(color: subtle),
                      ),
                      if (mine) ...[
                        const SizedBox(width: 4),
                        Icon(
                          message.voiceRead ? Icons.done_all_rounded : Icons.done_rounded,
                          size: 15,
                          color: message.voiceRead
                              ? (onVideo ? Colors.lightBlueAccent : context.colors.primary)
                              : subtle,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _fmtDuration(int ms) {
    final total = (ms / 1000).round();
    final m = total ~/ 60;
    final s = total % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  static String _hhmm(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}

/// Circular play/stop control reflecting [VoiceCubit]'s current playing clip.
class _PlayButton extends StatelessWidget {
  const _PlayButton({required this.message, required this.accent, required this.fg});

  final ChatMessage message;
  final Color accent;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<VoiceCubit, VoiceState>(
      buildWhen: (a, b) => (a.playingId == message.id) != (b.playingId == message.id),
      builder: (context, state) {
        final playing = state.playingId == message.id;
        return Material(
          color: accent,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => context.read<VoiceCubit>().playMessage(message),
            child: Padding(
              padding: const EdgeInsets.all(7),
              child: Icon(
                playing ? Icons.stop_rounded : Icons.play_arrow_rounded,
                size: 18,
                color: fg,
              ),
            ),
          ),
        );
      },
    );
  }
}
