import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '/core/extensions/context_extensions.dart';
import '../bloc/watch_cubit.dart';
import '../bloc/watch_state.dart';
import 'emoji_keyboard_picker.dart';

/// The room's emoji reaction palette as a compact, horizontally scrollable
/// strip. Tapping an emoji sends a `reaction` to everyone and floats it
/// locally. The trailing `+` lets the viewer pick any emoji from their keyboard;
/// the picked one is appended to the strip for the session and sent right away.
class ReactionBar extends StatelessWidget {
  const ReactionBar({super.key});

  Future<void> _addCustom(BuildContext context) async {
    final emoji = await pickEmojiFromKeyboard(context);
    if (emoji == null || emoji.isEmpty || !context.mounted) return;
    final cubit = context.read<WatchCubit>();
    // Shared session palette so the fullscreen bar shows it too.
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
        final seen = <String>{};
        final emojis = <String>[
          for (final e in roomReactions)
            if (e.isNotEmpty && seen.add(e)) e,
          for (final e in state.sessionReactions)
            if (seen.add(e)) e,
        ];

        return SizedBox(
          height: 44,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: emojis.length + 1,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              if (i == emojis.length) return _addButton(context);
              final emoji = emojis[i];
              return _circle(
                context,
                onTap: () => context.read<WatchCubit>().sendReaction(emoji),
                child: Text(emoji, style: const TextStyle(fontSize: 20)),
              );
            },
          ),
        );
      },
    );
  }

  Widget _addButton(BuildContext context) => _circle(
    context,
    onTap: () => _addCustom(context),
    child: Icon(Icons.add_rounded, size: 22, color: context.colors.primary),
  );

  Widget _circle(
    BuildContext context, {
    required VoidCallback onTap,
    required Widget child,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(99),
      onTap: onTap,
      child: Container(
        alignment: Alignment.center,
        width: 44,
        decoration: BoxDecoration(
          color: context.colors.surface,
          shape: BoxShape.circle,
          border: Border.all(color: context.colors.outline),
        ),
        child: child,
      ),
    );
  }
}
