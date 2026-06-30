import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '/core/extensions/context_extensions.dart';
import '/core/localization/translation_keys.dart';
import '/core/shared/user_avatar.dart';
import '/logic/identity/identity_cubit.dart';
import '../../domain/entities/chat_message.dart';
import '../bloc/fullscreen_messages/fullscreen_messages_cubit.dart';
import '../bloc/fullscreen_ui/fullscreen_ui_cubit.dart';
import '../bloc/fullscreen_ui/fullscreen_ui_state.dart';
import '../bloc/watch_cubit.dart';
import '../bloc/watch_state.dart';
import 'typing_indicator.dart';
import 'voice_composer.dart';
import 'voice_message_bubble.dart';

/// Round toggle that sits under the fullscreen reaction bar. Tapping it
/// opens/closes the [FullscreenMessagesPanel]; the icon fills in while open.
class FullscreenMessagesButton extends StatelessWidget {
  const FullscreenMessagesButton({
    super.key,
    required this.open,
    required this.onTap,
  });

  final bool open;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: open
          ? context.colors.primary.withValues(alpha: 0.9)
          : Colors.black.withValues(alpha: 0.45),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      // Sized to match the fullscreen reaction toggle (Icon 22 + 8 padding) so
      // the two stacked buttons read as a matching pair.
      child: InkWell(
        borderRadius: BorderRadius.circular(99),
        onTap: onTap,
        child: Tooltip(
          message: context.tr(TranslationKeys.messages),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(
              open ? Icons.forum_rounded : Icons.forum_outlined,
              size: 22,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

/// A translucent chat panel that slides in from the right over the fullscreen
/// video. It shows the room's message history (the same `state.messages` as the
/// inline chat) and a compose box, so viewers can both read and reply without
/// leaving fullscreen. Shown/hidden by [open]; [onClose] backs the header's
/// close button.
class FullscreenMessagesPanel extends StatelessWidget {
  const FullscreenMessagesPanel({
    super.key,
    required this.open,
    required this.onClose,
  });

  final bool open;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => FullscreenMessagesCubit(context.read<WatchCubit>()),
      child: _PanelView(open: open, onClose: onClose),
    );
  }
}

class _PanelView extends StatelessWidget {
  const _PanelView({required this.open, required this.onClose});

  final bool open;
  final VoidCallback onClose;

  void _send(BuildContext context) =>
      context.read<FullscreenMessagesCubit>().send();

  /// Time of receipt + (on our own messages) a delivery mark — a check once the
  /// room has it, a clock while it's in flight, or a tap-to-retry hint. Mirrors
  /// the inline chat bubble so voice messages read the same here.
  Widget _meta(BuildContext context, ChatMessage m, bool mine) {
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            TimeOfDay.fromDateTime(m.time).format(context),
            style: const TextStyle(color: Colors.white70, fontSize: 10),
          ),
          if (mine) ...[
            const SizedBox(width: 5),
            switch (m.status) {
              ChatStatus.sent => const Icon(
                Icons.done_all_rounded,
                size: 13,
                color: Colors.white70,
              ),
              ChatStatus.sending => const Icon(
                Icons.schedule_rounded,
                size: 12,
                color: Colors.white70,
              ),
              ChatStatus.failed => Text(
                context.tr(TranslationKeys.chatRetry),
                style: TextStyle(color: context.colors.error, fontSize: 11),
              ),
            },
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    // Narrow streamer-style sidebar — keep it slim so it covers as little of the
    // video as possible.
    final panelWidth = (width * 0.30).clamp(230.0, 320.0);

    // Jump to the latest messages whenever the panel is (re)opened — fired when
    // the parent's `messagesOpen` flips false -> true (was `didUpdateWidget`).
    return BlocListener<FullscreenUiCubit, FullscreenUiState>(
      listenWhen: (a, b) => !a.messagesOpen && b.messagesOpen,
      listener: (context, _) =>
          context.read<FullscreenMessagesCubit>().scrollToEnd(),
      child: Align(
        alignment: Alignment.centerRight,
        child: AnimatedSlide(
          offset: open ? Offset.zero : const Offset(1, 0),
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          child: AnimatedOpacity(
            opacity: open ? 1 : 0,
            duration: const Duration(milliseconds: 200),
            child: IgnorePointer(
              ignoring: !open,
              child: SizedBox(
                width: panelWidth,
                height: double.infinity,
                child: Material(
                  // Lighter scrim so more of the video shows through behind the
                  // streamer-style chat.
                  color: Colors.black.withValues(alpha: 0.34),
                  child: SafeArea(
                    left: false,
                    child: Column(
                      children: [
                        _header(context),
                        Expanded(child: _list(context)),
                        const TypingIndicator(dark: true),
                        _composer(context),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 4, 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              context.tr(TranslationKeys.messages),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          IconButton(
            color: Colors.white,
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.close_rounded),
            onPressed: onClose,
          ),
        ],
      ),
    );
  }

  Widget _list(BuildContext context) {
    final me = context.watch<IdentityCubit>().state;
    return BlocConsumer<WatchCubit, WatchState>(
      listenWhen: (a, b) => a.messages.length != b.messages.length,
      listener: (context, _) =>
          context.read<FullscreenMessagesCubit>().scrollToEnd(),
      buildWhen: (a, b) => a.messages != b.messages,
      builder: (context, state) {
        if (state.messages.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                context.tr(TranslationKeys.chatEmpty),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ),
          );
        }
        return ListView.builder(
          controller: context.read<FullscreenMessagesCubit>().scroll,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          itemCount: state.messages.length,
          itemBuilder: (context, i) {
            final m = state.messages[i];
            final mine = m.mine || m.name == me;
            final failed = m.status == ChatStatus.failed;
            // Streamer-style: every message (including our own) reads as one
            // left-aligned line with a colored username — so you see your own
            // messages exactly like the ones you receive.
            return GestureDetector(
              onTap: failed ? () => context.read<WatchCubit>().retryChat(m) : null,
              child: Opacity(
                opacity: m.status == ChatStatus.sending ? 0.6 : 1,
                child: Container(
                  width: double.infinity,
                  margin: const EdgeInsets.symmetric(vertical: 2),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: failed ? Border.all(color: context.colors.error) : null,
                  ),
                  child: m.isVoice
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            m.name,
                            style: TextStyle(
                              color: userColorFor(m.name),
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 2),
                          VoiceMessageBubble(message: m, dark: true),
                          _meta(context, m, mine),
                        ],
                      )
                    : Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: '${m.name}  ',
                          style: TextStyle(
                            color: userColorFor(m.name),
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                        TextSpan(
                          text: m.text,
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                        ),
                        // Delivery indicator on our own messages, so we can tell
                        // whether one reached the room: a check once confirmed,
                        // else a sending / tap-to-retry hint.
                        if (mine)
                          WidgetSpan(
                            alignment: PlaceholderAlignment.middle,
                            child: Padding(
                              padding: const EdgeInsets.only(left: 6),
                              child: switch (m.status) {
                                ChatStatus.sent => const Icon(
                                  Icons.done_all_rounded,
                                  size: 13,
                                  color: Colors.white70,
                                ),
                                ChatStatus.sending => const Icon(
                                  Icons.schedule_rounded,
                                  size: 12,
                                  color: Colors.white70,
                                ),
                                ChatStatus.failed => Text(
                                  context.tr(TranslationKeys.chatRetry),
                                  style: TextStyle(color: context.colors.error, fontSize: 11),
                                ),
                              },
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
    );
  }

  Widget _composer(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        10,
        6,
        10,
        MediaQuery.of(context).viewInsets.bottom + 10,
      ),
      // Text field + send, or tap-the-mic to record a voice message.
      child: VoiceComposer(
        dark: true,
        input: context.read<FullscreenMessagesCubit>().input,
        onSend: () => _send(context),
        field: TextField(
          controller: context.read<FullscreenMessagesCubit>().input,
          textInputAction: TextInputAction.send,
          style: const TextStyle(color: Colors.white),
          minLines: 1,
          maxLines: 3,
          decoration: InputDecoration(
            isDense: true,
            hintText: context.tr(TranslationKeys.chatHint),
            hintStyle: const TextStyle(color: Colors.white54),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.1),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 8,
            ),
          ),
          onSubmitted: (_) => _send(context),
        ),
      ),
    );
  }
}
