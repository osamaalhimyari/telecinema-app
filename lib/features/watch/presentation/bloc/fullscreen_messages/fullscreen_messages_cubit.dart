import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../watch_cubit.dart';
import 'fullscreen_messages_state.dart';

/// Owns the fullscreen messages panel's local UI state — the message input +
/// the message-list scroll controllers — so the panel can be a plain
/// StatelessWidget (no setState). Sending delegates to the room's [WatchCubit];
/// the controllers are disposed in [close].
class FullscreenMessagesCubit extends Cubit<FullscreenMessagesState> {
  FullscreenMessagesCubit(this._watch) : super(const FullscreenMessagesState());

  final WatchCubit _watch;

  final TextEditingController input = TextEditingController();
  final ScrollController scroll = ScrollController();

  void send() {
    final text = input.text.trim();
    if (text.isEmpty) return;
    _watch.sendChat(text);
    input.clear();
  }

  void scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scroll.hasClients) {
        scroll.animateTo(
          scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
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
