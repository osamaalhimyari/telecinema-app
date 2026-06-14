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

  /// Tiny delivery line under our own pending messages: a spinner while it's in
  /// flight, or a tappable "tap to retry" when the send failed.
  Widget _status(BuildContext context, ChatMessage m) {
    final failed = m.status == ChatStatus.failed;
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            failed ? Icons.error_outline_rounded : Icons.schedule_rounded,
            size: 12,
            color: failed ? context.colors.error : context.colors.onSurfaceVariant,
          ),
          const SizedBox(width: 4),
          Text(
            failed ? context.tr(TranslationKeys.chatRetry) : context.tr(TranslationKeys.chatSending),
            style: context.text.labelSmall?.copyWith(
              color: failed ? context.colors.error : context.colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
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
                  return Align(
                    alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                    child: GestureDetector(
                      onTap: failed ? () => context.read<WatchCubit>().retryChat(m) : null,
                      child: Opacity(
                        opacity: m.status == ChatStatus.sending ? 0.6 : 1,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 3),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          constraints: const BoxConstraints(maxWidth: 280),
                          decoration: BoxDecoration(
                            color: mine ? context.colors.primary.withValues(alpha: 0.38) : context.colors.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: failed ? context.colors.error : context.colors.outline,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (!mine)
                                Text(
                                  m.name,
                                  style: context.text.labelMedium?.copyWith(
                                    color: userColorFor(m.name),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              Text(m.text, style: context.text.bodyMedium?.copyWith(color: context.colors.onSurface)),
                              if (mine && m.isPending) _status(context, m),
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
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
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
                const SizedBox(width: 8),
                IconButton.filled(onPressed: chat.send, icon: const Icon(Icons.send_rounded)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
