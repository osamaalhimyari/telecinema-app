import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/watch_cubit.dart';
import '../bloc/watch_state.dart';
import 'emoji_keyboard_picker.dart';

/// Fullscreen reaction palette — a horizontally **scrollable** strip of the
/// room's emoji, ending with a `+` button to add a custom one for the session.
/// It has no toggle of its own: it simply appears (at the top of the control
/// stack) whenever the master controls button is expanded, so the emoji are one
/// tap away. Each emoji sends a `reaction` that floats up via the fullscreen
/// `FloatingReactions` overlay.
class FullscreenReactionBar extends StatelessWidget {
  const FullscreenReactionBar({super.key});

  void _send(BuildContext context, String emoji) =>
      context.read<WatchCubit>().sendReaction(emoji);

  Future<void> _addCustom(BuildContext context) async {
    final emoji = await pickEmojiFromKeyboard(context);
    if (emoji == null || emoji.isEmpty || !context.mounted) return;
    final cubit = context.read<WatchCubit>();
    // Shared session palette so the portrait bar shows it too.
    cubit.addSessionReaction(emoji);
    cubit.sendReaction(emoji);
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<WatchCubit, WatchState>(
      buildWhen: (a, b) =>
          a.room?.reactions != b.room?.reactions || a.sessionReactions != b.sessionReactions,
      builder: (context, state) {
        final roomReactions = state.room?.reactions ?? const [];
        if (roomReactions.isEmpty && state.sessionReactions.isEmpty) {
          return const SizedBox.shrink();
        }

        // Room palette first, then any session-added custom emoji, de-duplicated.
        final seen = <String>{};
        final emojis = <String>[
          for (final e in roomReactions)
            if (e.isNotEmpty && seen.add(e)) e,
          for (final e in state.sessionReactions)
            if (seen.add(e)) e,
        ];

        return Material(
          color: Colors.black.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(99),
          clipBehavior: Clip.antiAlias,
          child: _strip(context, emojis),
        );
      },
    );
  }

  /// The scrollable emoji strip: the room's emoji followed by the `+` add
  /// button. Capped to ~60% of the screen width so a long palette scrolls
  /// horizontally instead of covering the video.
  Widget _strip(BuildContext context, List<String> emojis) {
    final maxWidth = MediaQuery.sizeOf(context).width * 0.6;
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final emoji in emojis)
              InkWell(
                borderRadius: BorderRadius.circular(99),
                onTap: () => _send(context, emoji),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 8),
                  child: Text(emoji, style: const TextStyle(fontSize: 20)),
                ),
              ),
            _iconButton(icon: Icons.add_rounded, onTap: () => _addCustom(context)),
          ],
        ),
      ),
    );
  }

  Widget _iconButton({required IconData icon, required VoidCallback onTap}) {
    return InkWell(
      borderRadius: BorderRadius.circular(99),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(icon, size: 22, color: Colors.white),
      ),
    );
  }
}
