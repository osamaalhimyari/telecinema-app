import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../watch_cubit.dart';
import 'chat_panel_state.dart';

/// Owns the chat panel's local UI state — the message input + the message-list
/// scroll controllers — so the panel can be a plain StatelessWidget (no
/// setState). Sending delegates to the room's [WatchCubit]; the controllers are
/// disposed in [close].
class ChatPanelCubit extends Cubit<ChatPanelState> {
  ChatPanelCubit(this._watch) : super(const ChatPanelState());

  final WatchCubit _watch;

  final TextEditingController input = TextEditingController();
  final ScrollController scroll = ScrollController();

  void send() {
    final text = input.text.trim();
    if (text.isEmpty) return;
    _watch.sendChat(text);
    input.clear();
  }

  void scrollToEnd({bool animate = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // The callback can fire after the panel is torn down; bail out before
      // touching the (by then disposed) scroll controller.
      if (isClosed || !scroll.hasClients) return;
      final target = scroll.position.maxScrollExtent;
      if (animate) {
        scroll.animateTo(
          target,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      } else {
        scroll.jumpTo(target);
      }
    });
  }

  @override
  Future<void> close() {
    input.dispose();
    scroll.dispose();
    return super.close();
  }
}
