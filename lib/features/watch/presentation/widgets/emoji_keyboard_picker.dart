import 'package:flutter/material.dart';

import '/core/extensions/context_extensions.dart';
import '/core/localization/translation_keys.dart';

/// Opens a tiny dialog with an autofocused field so the user can pick an emoji
/// straight from their device keyboard's emoji panel. Resolves to the first
/// grapheme they entered, or `null` if they cancelled / typed nothing.
Future<String?> pickEmojiFromKeyboard(BuildContext context) {
  final controller = TextEditingController();

  String? firstEmoji() {
    final text = controller.text.trim();
    if (text.isEmpty) return null;
    return text.characters.first;
  }

  return showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(dialogContext.tr(TranslationKeys.addEmoji)),
      content: TextField(
        controller: controller,
        autofocus: true,
        maxLength: 8,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 32),
        decoration: InputDecoration(
          counterText: '',
          hintText: dialogContext.tr(TranslationKeys.addEmojiHint),
        ),
        onSubmitted: (_) => Navigator.of(dialogContext).pop(firstEmoji()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: Text(dialogContext.tr(TranslationKeys.cancel)),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(firstEmoji()),
          child: Text(dialogContext.tr(TranslationKeys.ok)),
        ),
      ],
    ),
  );
}
