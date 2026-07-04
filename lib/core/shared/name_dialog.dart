import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '/core/extensions/context_extensions.dart';
import '/core/localization/translation_keys.dart';
import '/core/shared/bloc/name_dialog/name_dialog_cubit.dart';
import '/core/shared/bloc/name_dialog/name_dialog_state.dart';
import '/logic/identity/identity_cubit.dart';

/// Prompts the viewer for a display name and saves it via [IdentityCubit].
///
/// Shown on room entry when no name has been chosen yet; the name is then
/// remembered (and can be changed later from Settings). A non-empty name is
/// required and tapping outside won't dismiss it. [show] resolves to `true`
/// once a name is saved, or `false` if the viewer backed out without one — the
/// caller should then leave the room.
class NameDialog extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => NameDialogCubit(),
      child: const _NameDialogView(),
    );
  }
}

class _NameDialogView extends StatelessWidget {
  const _NameDialogView();

  void _submit(BuildContext context) {
    final cubit = context.read<NameDialogCubit>();
    final name = cubit.name.text.trim();
    if (name.isEmpty) return;
    context.read<IdentityCubit>().setName(name);
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<NameDialogCubit>();
    return AlertDialog(
      title: Text(context.tr(TranslationKeys.yourName)),
      content: TextField(
        controller: cubit.name,
        autofocus: true,
        maxLength: 30,
        textInputAction: TextInputAction.done,
        decoration: InputDecoration(
          hintText: context.tr(TranslationKeys.enterName),
          prefixIcon: const Icon(Icons.person_outline_rounded),
        ),
        onSubmitted: (_) => _submit(context),
      ),
      actions: [
        BlocBuilder<NameDialogCubit, NameDialogState>(
          buildWhen: (a, b) => a.canSave != b.canSave,
          builder: (context, state) {
            return FilledButton(
              onPressed: state.canSave ? () => _submit(context) : null,
              child: Text(context.tr(TranslationKeys.save)),
            );
          },
        ),
      ],
    );
  }
}
