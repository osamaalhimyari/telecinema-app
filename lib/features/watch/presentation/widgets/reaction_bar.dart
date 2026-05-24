import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '/core/extensions/context_extensions.dart';
import '../bloc/watch_cubit.dart';
import '../bloc/watch_state.dart';

/// The room's emoji reaction palette. Tapping sends a `reaction` to everyone
/// and floats the emoji locally.
class ReactionBar extends StatelessWidget {
  const ReactionBar({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<WatchCubit, WatchState>(
      buildWhen: (a, b) => a.room?.reactions != b.room?.reactions,
      builder: (context, state) {
        final reactions = state.room?.reactions ?? const [];
        return SizedBox(
          height: 44,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: reactions.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final emoji = reactions[i];
              return InkWell(
                borderRadius: BorderRadius.circular(99),
                onTap: () => context.read<WatchCubit>().sendReaction(emoji),
                child: Container(
                  alignment: Alignment.center,
                  width: 44,
                  decoration: BoxDecoration(
                    color: context.colors.surface,
                    shape: BoxShape.circle,
                    border: Border.all(color: context.colors.outline),
                  ),
                  child: Text(emoji, style: const TextStyle(fontSize: 20)),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
