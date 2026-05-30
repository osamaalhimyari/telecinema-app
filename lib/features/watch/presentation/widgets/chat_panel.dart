import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '/core/extensions/context_extensions.dart';
import '/core/localization/translation_keys.dart';
import '/core/shared/user_avatar.dart';
import '/logic/identity/identity_cubit.dart';
import '../bloc/watch_cubit.dart';
import '../bloc/watch_state.dart';

class ChatPanel extends StatefulWidget {
  const ChatPanel({super.key});

  @override
  State<ChatPanel> createState() => _ChatPanelState();
}

class _ChatPanelState extends State<ChatPanel> {
  final _input = TextEditingController();
  final _scroll = ScrollController();

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _send() {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    context.read<WatchCubit>().sendChat(text);
    _input.clear();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final me = context.watch<IdentityCubit>().state;
    return Column(
      children: [
        Expanded(
          child: BlocConsumer<WatchCubit, WatchState>(
            listenWhen: (a, b) => a.messages.length != b.messages.length,
            listener: (_, _) => _scrollToEnd(),
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
                controller: _scroll,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                itemCount: state.messages.length,
                itemBuilder: (context, i) {
                  final m = state.messages[i];
                  final mine = m.name == me;
                  return Align(
                    alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 3),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      constraints: const BoxConstraints(maxWidth: 280),
                      decoration: BoxDecoration(
                        color: mine ? context.colors.primary.withValues(alpha: 0.38) : context.colors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: context.colors.outline),
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
                        ],
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
                    controller: _input,
                    textInputAction: TextInputAction.send,
                    minLines: 1,
                    maxLines: 3,
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
          ),
        ),
      ],
    );
  }
}
