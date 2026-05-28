import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/watch_cubit.dart';
import '../bloc/watch_state.dart';

/// Fullscreen reaction palette: the room's reaction emoji shown as a single
/// tappable line (the room's 8 reactions, no picker), pinned over the video.
/// Tapping sends a reaction that floats up via the fullscreen
/// `FloatingReactions` overlay.
class FullscreenReactionBar extends StatelessWidget {
  const FullscreenReactionBar({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<WatchCubit, WatchState>(
      buildWhen: (a, b) => a.room?.reactions != b.room?.reactions,
      builder: (context, state) {
        final reactions = state.room?.reactions ?? const [];
        if (reactions.isEmpty) return const SizedBox.shrink();
        return Material(
          color: Colors.black.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(99),
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final emoji in reactions)
                  InkWell(
                    borderRadius: BorderRadius.circular(99),
                    onTap: () => context.read<WatchCubit>().sendReaction(emoji),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 8),
                      child: Text(emoji, style: const TextStyle(fontSize: 20)),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
