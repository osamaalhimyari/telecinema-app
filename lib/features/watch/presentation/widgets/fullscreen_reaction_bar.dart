import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/watch_cubit.dart';
import '../bloc/watch_state.dart';
import 'emoji_keyboard_picker.dart';

/// Fullscreen reaction palette pinned over the video.
///
/// To keep the picture clear it starts **collapsed** as a single reaction icon.
/// Tapping the icon expands a horizontally **scrollable** strip of the room's
/// emoji, ending with a `+` button to add a custom one for the session; tapping
/// the icon again collapses the strip away. Each emoji sends a `reaction` that
/// floats up via the fullscreen `FloatingReactions` overlay.
class FullscreenReactionBar extends StatefulWidget {
  const FullscreenReactionBar({super.key});

  @override
  State<FullscreenReactionBar> createState() => _FullscreenReactionBarState();
}

class _FullscreenReactionBarState extends State<FullscreenReactionBar> {
  /// Whether the emoji strip is shown. Starts hidden behind the single icon.
  bool _expanded = false;

  /// Custom emoji added via the `+` button this session (not part of the
  /// server-defined room palette). Mirrors [ReactionBar].
  final List<String> _extra = [];

  void _toggle() => setState(() => _expanded = !_expanded);

  void _send(String emoji) => context.read<WatchCubit>().sendReaction(emoji);

  Future<void> _addCustom() async {
    final emoji = await pickEmojiFromKeyboard(context);
    if (emoji == null || emoji.isEmpty || !mounted) return;
    if (!_extra.contains(emoji)) setState(() => _extra.add(emoji));
    _send(emoji);
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<WatchCubit, WatchState>(
      buildWhen: (a, b) => a.room?.reactions != b.room?.reactions,
      builder: (context, state) {
        final roomReactions = state.room?.reactions ?? const [];
        if (roomReactions.isEmpty && _extra.isEmpty) return const SizedBox.shrink();

        // Room palette first, then any session-added custom emoji, de-duplicated.
        final seen = <String>{};
        final emojis = <String>[
          for (final e in roomReactions)
            if (e.isNotEmpty && seen.add(e)) e,
          for (final e in _extra)
            if (seen.add(e)) e,
        ];

        return Material(
          color: Colors.black.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(99),
          clipBehavior: Clip.antiAlias,
          child: AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            alignment: Alignment.centerLeft,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // The always-present toggle. Collapses/expands the strip.
                _iconButton(
                  icon: _expanded ? Icons.close_rounded : Icons.add_reaction_outlined,
                  onTap: _toggle,
                ),
                if (_expanded) _strip(context, emojis),
              ],
            ),
          ),
        );
      },
    );
  }

  /// The scrollable emoji strip revealed when expanded: the room's emoji
  /// followed by the `+` add button. Capped to ~55% of the screen width so a
  /// long palette scrolls horizontally instead of covering the video.
  Widget _strip(BuildContext context, List<String> emojis) {
    final maxWidth = MediaQuery.sizeOf(context).width * 0.55;
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(right: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final emoji in emojis)
              InkWell(
                borderRadius: BorderRadius.circular(99),
                onTap: () => _send(emoji),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 8),
                  child: Text(emoji, style: const TextStyle(fontSize: 20)),
                ),
              ),
            _iconButton(icon: Icons.add_rounded, onTap: _addCustom),
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
