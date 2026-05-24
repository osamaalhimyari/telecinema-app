import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '/core/extensions/context_extensions.dart';
import '/core/localization/translation_keys.dart';
import '../bloc/watch_cubit.dart';

/// A compact, collapsible reaction palette for the fullscreen player, pinned to
/// the top-left. Collapsed it's a single button; tapping expands the room's
/// emoji palette, and each emoji sends a reaction (which then floats up via the
/// fullscreen `FloatingReactions` overlay).
class FullscreenReactionButton extends StatefulWidget {
  const FullscreenReactionButton({super.key});

  @override
  State<FullscreenReactionButton> createState() => _FullscreenReactionButtonState();
}

class _FullscreenReactionButtonState extends State<FullscreenReactionButton> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final reactions = context.select<WatchCubit, List<String>>(
      (c) => c.state.room?.reactions ?? const [],
    );
    return Material(
      color: Colors.black.withValues(alpha: 0.45),
      borderRadius: BorderRadius.circular(99),
      clipBehavior: Clip.antiAlias,
      child: AnimatedSize(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        alignment: Alignment.centerLeft,
        child: _expanded ? _palette(context, reactions) : _collapsed(context),
      ),
    );
  }

  Widget _collapsed(BuildContext context) {
    return IconButton(
      tooltip: context.tr(TranslationKeys.reactions),
      color: Colors.white,
      icon: const Icon(Icons.add_reaction_outlined),
      onPressed: () => setState(() => _expanded = true),
    );
  }

  Widget _palette(BuildContext context, List<String> reactions) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          visualDensity: VisualDensity.compact,
          color: Colors.white,
          icon: const Icon(Icons.close_rounded),
          onPressed: () => setState(() => _expanded = false),
        ),
        for (final emoji in reactions)
          InkWell(
            borderRadius: BorderRadius.circular(99),
            onTap: () => context.read<WatchCubit>().sendReaction(emoji),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
              child: Text(emoji, style: const TextStyle(fontSize: 22)),
            ),
          ),
        const SizedBox(width: 6),
      ],
    );
  }
}
