import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '/core/constants/reaction_emojis.dart';
import '/core/extensions/context_extensions.dart';
import '/core/localization/translation_keys.dart';
import '../bloc/watch_cubit.dart';

/// Pops the floating reaction card. Captures the [WatchCubit] up front so the
/// dialog (pushed on the root navigator, outside the room's BlocProvider) can
/// still send reactions. Tapping an emoji sends it and closes the card.
Future<void> showReactionPicker(BuildContext context) {
  final cubit = context.read<WatchCubit>();
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.35),
    builder: (dialogContext) => ReactionPickerCard(
      roomReactions: cubit.state.room?.reactions ?? const [],
      onPick: (emoji) {
        cubit.sendReaction(emoji);
        Navigator.of(dialogContext).pop();
      },
    ),
  );
}

/// A floating card holding a 6-column, scrollable grid of reaction emoji. The
/// room's own palette is shown first (deduped), followed by a broad set, so the
/// quick reactions stay at the top and everything else is reachable by scroll.
class ReactionPickerCard extends StatelessWidget {
  const ReactionPickerCard({
    super.key,
    required this.onPick,
    this.roomReactions = const [],
  });

  final void Function(String emoji) onPick;
  final List<String> roomReactions;

  static const _columns = 6;

  @override
  Widget build(BuildContext context) {
    final seen = <String>{};
    final emojis = <String>[
      for (final e in roomReactions)
        if (e.isNotEmpty && seen.add(e)) e,
      for (final e in kReactionEmojis)
        if (seen.add(e)) e,
    ];

    final size = MediaQuery.sizeOf(context);
    final maxWidth = math.min(360.0, size.width - 48);
    final maxHeight = size.height * 0.5;

    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxWidth,
          maxHeight: maxHeight + 56,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    context.tr(TranslationKeys.reactions),
                    style: context.text.titleSmall,
                  ),
                  const Spacer(),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              Flexible(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: maxHeight),
                  child: GridView.builder(
                    shrinkWrap: true,
                    padding: const EdgeInsets.only(right: 8, top: 4, bottom: 4),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: _columns,
                          mainAxisSpacing: 4,
                          crossAxisSpacing: 4,
                        ),
                    itemCount: emojis.length,
                    itemBuilder: (context, i) {
                      final emoji = emojis[i];
                      return InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () => onPick(emoji),
                        child: Center(
                          child: Text(
                            emoji,
                            style: const TextStyle(fontSize: 24),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
