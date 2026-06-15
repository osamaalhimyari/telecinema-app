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

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final panelWidth = (width * 0.42).clamp(280.0, 420.0);

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
                  color: Colors.black.withValues(alpha: 0.62),
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
            return Align(
              alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
              child: GestureDetector(
                onTap: failed
                    ? () => context.read<WatchCubit>().retryChat(m)
                    : null,
                child: Opacity(
                  opacity: m.status == ChatStatus.sending ? 0.6 : 1,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 3),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                    constraints: const BoxConstraints(maxWidth: 260),
                    decoration: BoxDecoration(
                      color: mine
                          ? context.colors.primary.withValues(alpha: 0.35)
                          : Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: failed
                          ? Border.all(color: context.colors.error)
                          : null,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (!mine)
                          Text(
                            m.name,
                            style: TextStyle(
                              color: userColorFor(m.name),
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        Text(
                          m.text,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            // Server timestamp in this device's local timezone.
                            TimeOfDay.fromDateTime(m.time).format(context),
                            style: const TextStyle(
                              color: Colors.white60,
                              fontSize: 10,
                            ),
                          ),
                        ),
                        if (mine && m.isPending)
                          Padding(
                            padding: const EdgeInsets.only(top: 3),
                            child: Text(
                              failed
                                  ? context.tr(TranslationKeys.chatRetry)
                                  : context.tr(TranslationKeys.chatSending),
                              style: TextStyle(
                                color: failed
                                    ? context.colors.error
                                    : Colors.white70,
                                fontSize: 11,
                              ),
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
      child: Row(
        children: [
          Expanded(
            child: TextField(
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
          const SizedBox(width: 8),
          IconButton.filled(
            onPressed: () => _send(context),
            icon: const Icon(Icons.send_rounded),
          ),
        ],
      ),
    );
  }
}
