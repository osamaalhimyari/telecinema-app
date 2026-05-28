import 'package:flutter/material.dart';

import '/core/extensions/context_extensions.dart';
import '/core/localization/translation_keys.dart';
import 'reaction_picker_card.dart';

/// Reaction button for the fullscreen player, pinned to the top-left. Tapping
/// opens the floating reaction picker — a 6-column, scrollable grid of emoji —
/// and each pick sends a reaction that floats up via the fullscreen
/// `FloatingReactions` overlay.
class FullscreenReactionButton extends StatelessWidget {
  const FullscreenReactionButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.45),
      borderRadius: BorderRadius.circular(99),
      clipBehavior: Clip.antiAlias,
      child: IconButton(
        tooltip: context.tr(TranslationKeys.reactions),
        color: Colors.white,
        icon: const Icon(Icons.add_reaction_outlined),
        onPressed: () => showReactionPicker(context),
      ),
    );
  }
}
