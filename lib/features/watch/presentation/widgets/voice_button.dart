import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '/core/extensions/context_extensions.dart';
import '/core/localization/translation_keys.dart';
import '../bloc/voice/voice_cubit.dart';
import '../bloc/voice/voice_state.dart';

/// Tap-to-talk control. Tap once to open the mic and start transmitting; tap
/// again to close it and send the burst to the room.
class VoiceButton extends StatelessWidget {
  const VoiceButton({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<VoiceCubit, VoiceState>(
      listenWhen: (a, b) => !a.permissionDenied && b.permissionDenied,
      listener: (context, _) =>
          context.showSnack(context.tr(TranslationKeys.micPermissionDenied)),
      builder: (context, state) {
        final cubit = context.read<VoiceCubit>();
        final active = state.micActive;
        return GestureDetector(
          onTap: () =>
              cubit.state.micActive ? cubit.stopTalking() : cubit.startTalking(),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: active ? context.semantic.success : context.colors.surface,
              borderRadius: BorderRadius.circular(99),
              border: Border.all(
                color: active ? context.semantic.success : context.colors.outline,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  active ? Icons.mic_rounded : Icons.mic_none_rounded,
                  size: 18,
                  color: active ? Colors.white : context.colors.onSurface,
                ),
                const SizedBox(width: 6),
                Text(
                  context.tr(TranslationKeys.tapToTalk),
                  style: context.text.labelMedium?.copyWith(
                    color: active ? Colors.white : context.colors.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
