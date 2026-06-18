import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '/core/extensions/context_extensions.dart';
import '/core/localization/translation_keys.dart';
import '../bloc/voice_message/voice_message_cubit.dart';
import '../bloc/voice_message/voice_message_state.dart';
import '../bloc/watch_cubit.dart';

/// The chat composer's trailing area. Normally it's the text [field] plus a
/// send button (or a mic button when the field is empty). **Tap the mic** to
/// start recording a voice message — the whole row then becomes a recording bar
/// (cancel · live timer · send). Tap send to send it, cancel to discard.
///
/// Owns a [VoiceMessageCubit] (recording → [WatchCubit.sendVoiceMessage]); [dark]
/// tunes colors for the fullscreen overlay.
class VoiceComposer extends StatelessWidget {
  const VoiceComposer({
    super.key,
    required this.field,
    required this.input,
    required this.onSend,
    this.dark = false,
  });

  /// The text input (each composer styles its own).
  final Widget field;

  /// The input's controller — drives the mic-vs-send swap.
  final TextEditingController input;

  /// Sends the typed text.
  final VoidCallback onSend;

  final bool dark;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => VoiceMessageCubit(context.read<WatchCubit>()),
      child: BlocConsumer<VoiceMessageCubit, VoiceMessageState>(
        listenWhen: (a, b) => !a.permissionDenied && b.permissionDenied,
        listener: (context, _) =>
            context.showSnack(context.tr(TranslationKeys.voiceMicPermission)),
        builder: (context, vm) {
          if (vm.isRecording) return _recordingBar(context, vm);
          return Row(
            children: [
              Expanded(child: field),
              const SizedBox(width: 8),
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: input,
                builder: (context, value, _) => value.text.trim().isEmpty
                    ? IconButton.filled(
                        tooltip: context.tr(TranslationKeys.voiceHoldToRecord),
                        onPressed: () => context.read<VoiceMessageCubit>().startRecording(),
                        icon: const Icon(Icons.mic_rounded),
                      )
                    : IconButton.filled(
                        onPressed: onSend,
                        icon: const Icon(Icons.send_rounded),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _recordingBar(BuildContext context, VoiceMessageState vm) {
    final cubit = context.read<VoiceMessageCubit>();
    final fg = dark ? Colors.white : context.colors.onSurface;
    return Row(
      children: [
        IconButton(
          tooltip: context.tr(TranslationKeys.cancel),
          onPressed: cubit.cancel,
          icon: Icon(Icons.delete_outline_rounded, color: context.colors.error),
        ),
        const _BlinkingDot(),
        const SizedBox(width: 10),
        Text(
          _fmt(vm.elapsedMs),
          style: TextStyle(color: fg, fontWeight: FontWeight.w600, fontSize: 15),
        ),
        const Spacer(),
        IconButton.filled(
          onPressed: cubit.finishAndSend,
          icon: const Icon(Icons.send_rounded),
        ),
      ],
    );
  }

  String _fmt(int ms) {
    final total = (ms / 1000).floor();
    final m = total ~/ 60;
    final s = total % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}

/// A slowly pulsing red dot — the "recording" cue beside the timer.
class _BlinkingDot extends StatefulWidget {
  const _BlinkingDot();

  @override
  State<_BlinkingDot> createState() => _BlinkingDotState();
}

class _BlinkingDotState extends State<_BlinkingDot> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 800),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 1, end: 0.25).animate(_c),
      child: Icon(Icons.fiber_manual_record_rounded, color: context.colors.error, size: 16),
    );
  }
}
