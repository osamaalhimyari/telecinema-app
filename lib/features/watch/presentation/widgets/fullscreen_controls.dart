import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '/core/extensions/context_extensions.dart';
import '/core/localization/translation_keys.dart';
import '../bloc/voice/voice_cubit.dart';
import '../bloc/voice/voice_state.dart';
import '../bloc/watch_cubit.dart';

/// A round, dark control button matching the fullscreen overlay style.
class _FsCircleButton extends StatelessWidget {
  const _FsCircleButton({required this.icon, required this.onPressed, this.tooltip});

  final IconData icon;
  final VoidCallback onPressed;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.45),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: IconButton(
        color: Colors.white,
        tooltip: tooltip,
        icon: Icon(icon),
        onPressed: onPressed,
      ),
    );
  }
}

/// Fullscreen chat: a button that opens a compose sheet (keyboard) to send one
/// message, then closes. Sends through the room's [WatchCubit].
class FullscreenChatButton extends StatelessWidget {
  const FullscreenChatButton({super.key});

  @override
  Widget build(BuildContext context) {
    return _FsCircleButton(
      icon: Icons.chat_bubble_outline_rounded,
      tooltip: context.tr(TranslationKeys.chatTab),
      onPressed: () => _compose(context),
    );
  }

  Future<void> _compose(BuildContext context) async {
    final cubit = context.read<WatchCubit>();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ChatComposer(onSend: cubit.sendChat),
    );
  }
}

class _ChatComposer extends StatefulWidget {
  const _ChatComposer({required this.onSend});

  final void Function(String text) onSend;

  @override
  State<_ChatComposer> createState() => _ChatComposerState();
}

class _ChatComposerState extends State<_ChatComposer> {
  final _input = TextEditingController();

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _send() {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    widget.onSend(text);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 12,
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _input,
              autofocus: true,
              textInputAction: TextInputAction.send,
              decoration: InputDecoration(
                hintText: context.tr(TranslationKeys.chatHint),
                isDense: true,
              ),
              onSubmitted: (_) => _send(),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(onPressed: _send, icon: const Icon(Icons.send_rounded)),
        ],
      ),
    );
  }
}

/// Hold-to-talk push-to-talk button for the fullscreen overlay (compact, dark).
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
        return GestureDetector(
          onTapDown: (_) => cubit.startTalking(),
          onTapUp: (_) => cubit.stopTalking(),
          onTapCancel: cubit.stopTalking,
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: active ? context.semantic.success : Colors.black.withValues(alpha: 0.45),
              shape: BoxShape.circle,
            ),
            child: Icon(
              active ? Icons.mic_rounded : Icons.mic_none_rounded,
              color: Colors.white,
            ),
          ),
        );
      },
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
