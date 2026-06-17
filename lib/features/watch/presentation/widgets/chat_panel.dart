import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '/core/extensions/context_extensions.dart';
import '/core/localization/translation_keys.dart';
import '/core/shared/user_avatar.dart';
import '/logic/identity/identity_cubit.dart';
import '../../domain/entities/chat_message.dart';
import '../bloc/chat_panel/chat_panel_cubit.dart';
import '../bloc/watch_cubit.dart';
import '../bloc/watch_state.dart';
import 'typing_indicator.dart';
import 'voice_composer.dart';
import 'voice_message_bubble.dart';

class ChatPanel extends StatelessWidget {
  const ChatPanel({super.key});

  @override
  Widget build(BuildContext context) {
    // The WatchCubit is provided by room_page above us; hand it to the panel's
    // cubit so sends can be delegated to it.
    return BlocProvider(
      create: (_) => ChatPanelCubit(context.read<WatchCubit>()),
      child: const _ChatPanelView(),
    );
  }
}

class _ChatPanelView extends StatelessWidget {
  const _ChatPanelView();

  /// Tiny delivery mark shown beside the time on our own messages: a clock while
  /// it's in flight, a check once the server confirms it reached the room, or a
  /// tappable "tap to retry" hint when the send failed.
  Widget _deliveryMark(BuildContext context, ChatMessage m) {
    switch (m.status) {
      case ChatStatus.sending:
        return Icon(
          Icons.schedule_rounded,
          size: 12,
          color: context.colors.onSurfaceVariant,
        );
      case ChatStatus.sent:
        return Icon(Icons.done_all_rounded, size: 13, color: context.colors.primary);
      case ChatStatus.failed:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded, size: 12, color: context.colors.error),
            const SizedBox(width: 3),
            Text(
              context.tr(TranslationKeys.chatRetry),
              style: context.text.labelSmall?.copyWith(color: context.colors.error),
            ),
          ],
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = context.watch<IdentityCubit>().state;
    final chat = context.read<ChatPanelCubit>();
    return Column(
      children: [
        Expanded(
          child: BlocConsumer<WatchCubit, WatchState>(
            listenWhen: (a, b) => a.messages.length != b.messages.length,
            listener: (_, _) => chat.scrollToEnd(),
            builder: (context, state) {
              if (state.messages.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      context.tr(TranslationKeys.chatEmpty),
                      textAlign: TextAlign.center,
                      style: context.text.bodyMedium,
                    ),
                  ),
                );
              }
              return ListView.builder(
                controller: chat.scroll,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                itemCount: state.messages.length,
                itemBuilder: (context, i) {
                  final m = state.messages[i];
                  final mine = m.mine || m.name == me;
                  final failed = m.status == ChatStatus.failed;
                  // Streamer-style: every message — including our own — is shown
                  // the same way, left-aligned with a colored username, so you
                  // read your messages just like the ones you receive.
                  return Align(
                    alignment: Alignment.centerLeft,
                    child: GestureDetector(
                      onTap: failed ? () => context.read<WatchCubit>().retryChat(m) : null,
                      child: Opacity(
                        opacity: m.status == ChatStatus.sending ? 0.6 : 1,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 3),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          constraints: const BoxConstraints(maxWidth: 280),
                          decoration: BoxDecoration(
                            color: context.colors.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: failed ? context.colors.error : context.colors.outline,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                m.name,
                                style: context.text.labelMedium?.copyWith(
                                  color: userColorFor(m.name),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              if (m.isVoice)
                                VoiceMessageBubble(message: m)
                              else
                                Text(m.text, style: context.text.bodyMedium?.copyWith(color: context.colors.onSurface)),
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      // `m.time` is the server timestamp rendered
                                      // in this device's own timezone + clock format.
                                      TimeOfDay.fromDateTime(m.time).format(context),
                                      style: context.text.labelSmall?.copyWith(
                                        color: context.colors.onSurfaceVariant,
                                        fontSize: 10,
                                      ),
                                    ),
                                    // Our own messages get a small delivery mark
                                    // right beside the time — no extra words.
                                    if (mine) ...[
                                      const SizedBox(width: 5),
                                      _deliveryMark(context, m),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
        const TypingIndicator(),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
            // Text field + send, or tap-the-mic to record a voice message.
            child: VoiceComposer(
              input: chat.input,
              onSend: chat.send,
              field: TextField(
                controller: chat.input,
                textInputAction: TextInputAction.send,
                minLines: 1,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: context.tr(TranslationKeys.chatHint),
                  isDense: true,
                ),
                onSubmitted: (_) => chat.send(),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
