import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '/core/extensions/context_extensions.dart';
import '/core/localization/translation_keys.dart';
import '../bloc/voice/voice_cubit.dart';
import '../bloc/voice/voice_state.dart';
import '../bloc/watch_cubit.dart';
import '../bloc/watch_state.dart';

/// Tap-to-talk push-to-talk button for the fullscreen overlay (compact, dark).
///
/// Tapping opens the mic and starts transmitting; tapping again closes it and
/// sends the burst to the room. (The room's audio is a record-then-relay clip,
/// so everyone else hears it once you tap to close.)
class FullscreenVoiceButton extends StatelessWidget {
  const FullscreenVoiceButton({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<VoiceCubit, VoiceState>(
      listenWhen: (a, b) => !a.permissionDenied && b.permissionDenied,
      listener: (context, _) => context.showSnack(context.tr(TranslationKeys.micPermissionDenied)),
      buildWhen: (a, b) => a.micActive != b.micActive,
      builder: (context, state) {
        final cubit = context.read<VoiceCubit>();
        final active = state.micActive;
        return Tooltip(
          message: context.tr(TranslationKeys.tapToTalk),
          child: GestureDetector(
            onTap: () => cubit.state.micActive ? cubit.stopTalking() : cubit.startTalking(),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: active ? context.semantic.success : Colors.black.withValues(alpha: 0.45),
                shape: BoxShape.circle,
              ),
              child: Icon(
                active ? Icons.mic_rounded : Icons.mic_none_rounded,
                size: 20,
                color: Colors.white,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Live viewer count over the fullscreen video, with the room name beside it
/// (the fullscreen view has no app bar to carry the title). It shares the
/// player's controls-visibility flag, so it fades in and out together with the
/// playback controls. Tapping the pill shows the full room name in a snackbar —
/// useful when a long name is ellipsized — and it only accepts taps while the
/// controls are visible, so a tap on the hidden pill still reaches the video to
/// toggle them.
class FullscreenViewerCount extends StatelessWidget {
  const FullscreenViewerCount({super.key, required this.visibility});

  final ValueListenable<bool> visibility;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: visibility,
      builder: (context, visible, child) => IgnorePointer(
        ignoring: !visible,
        child: AnimatedOpacity(
          opacity: visible ? 1 : 0,
          duration: const Duration(milliseconds: 200),
          child: child,
        ),
      ),
      child: BlocBuilder<WatchCubit, WatchState>(
        buildWhen: (a, b) => a.viewerCount != b.viewerCount || a.room != b.room,
        builder: (context, state) {
          final name = state.room?.name ?? '';
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: name.isEmpty ? null : () => context.showSnack(name),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(99),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.visibility_rounded, color: Colors.white, size: 15),
                  const SizedBox(width: 6),
                  Text(
                    '${state.viewerCount} ${context.tr(TranslationKeys.watching)}',
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                  if (name.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Container(
                      width: 3,
                      height: 3,
                      decoration: const BoxDecoration(
                        color: Colors.white54,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Flexible so a long name shrinks/ellipsizes before the Row
                    // can overflow on a narrow landscape (or large text scale);
                    // capped at 180px when there is ample room.
                    Flexible(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 180),
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Shows who is currently talking, over the fullscreen video.
class FullscreenSpeakingIndicator extends StatelessWidget {
  const FullscreenSpeakingIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<VoiceCubit, VoiceState>(
      buildWhen: (a, b) => a.speakers != b.speakers,
      builder: (context, state) {
        if (state.speakers.isEmpty) return const SizedBox.shrink();
        final names = state.speakers.values.where((n) => n.isNotEmpty).join(', ');
        final label = names.isEmpty
            ? context.tr(TranslationKeys.speaking)
            : '$names ${context.tr(TranslationKeys.speaking)}';
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(99),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.mic_rounded, color: context.semantic.success, size: 16),
              const SizedBox(width: 6),
              Text(label, style: const TextStyle(color: Colors.white, fontSize: 13)),
            ],
          ),
        );
      },
    );
  }
}
