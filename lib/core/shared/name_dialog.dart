import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '/core/extensions/context_extensions.dart';
import '/core/localization/translation_keys.dart';
import '/logic/identity/identity_cubit.dart';

/// Prompts the viewer for a display name and saves it via [IdentityCubit].
///
/// Shown on room entry when no name has been chosen yet; the name is then
/// remembered (and can be changed later from Settings). A non-empty name is
/// required and tapping outside won't dismiss it. [show] resolves to `true`
/// once a name is saved, or `false` if the viewer backed out without one — the
/// caller should then leave the room.
class NameDialog extends StatefulWidget {
  const NameDialog({super.key});

  static Future<bool> show(BuildContext context) async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const NameDialog(),
    );
    return saved ?? false;
  }

  @override
  State<NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<NameDialog> {
  final _name = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    context.read<IdentityCubit>().setName(name);
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final canSave = _name.text.trim().isNotEmpty;
    return AlertDialog(
      title: Text(context.tr(TranslationKeys.yourName)),
      content: TextField(
        controller: _name,
        autofocus: true,
        maxLength: 30,
        textInputAction: TextInputAction.done,
        decoration: InputDecoration(
          hintText: context.tr(TranslationKeys.enterName),
          prefixIcon: const Icon(Icons.person_outline_rounded),
        ),
        onChanged: (_) => setState(() {}),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        FilledButton(
          onPressed: canSave ? _submit : null,
          child: Text(context.tr(TranslationKeys.save)),
        ),
      ],
    );
  }
}
