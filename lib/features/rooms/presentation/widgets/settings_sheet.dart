import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '/core/extensions/context_extensions.dart';
import '/core/localization/translation_keys.dart';
import '/logic/identity/identity_cubit.dart';
import '/logic/localization/locale_cubit.dart';
import '/logic/theme/theme_cubit.dart';
import '/logic/theme/theme_state.dart';

/// Bottom sheet for the lightweight, account-less settings: display name,
/// theme and language.
class SettingsSheet extends StatefulWidget {
  const SettingsSheet({super.key});

  static Future<void> show(BuildContext context) => showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => const SettingsSheet(),
  );

  @override
  State<SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<SettingsSheet> {
  late final TextEditingController _name = TextEditingController(
    text: context.read<IdentityCubit>().state,
  );

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 8,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.tr(TranslationKeys.settings), style: context.text.titleLarge),
          const SizedBox(height: 20),

          Text(context.tr(TranslationKeys.yourName), style: context.text.titleSmall),
          const SizedBox(height: 8),
          TextField(
            controller: _name,
            maxLength: 30,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              hintText: context.tr(TranslationKeys.enterName),
              prefixIcon: const Icon(Icons.person_outline_rounded),
            ),
            onSubmitted: (v) => context.read<IdentityCubit>().setName(v),
          ),
          const SizedBox(height: 8),

          _RowTile(
            icon: Icons.dark_mode_outlined,
            label: context.tr(TranslationKeys.theme),
            trailing: BlocBuilder<ThemeCubit, ThemeState>(
              builder: (context, state) => Switch(
                value: state.mode != ThemeMode.light,
                onChanged: (_) => context.read<ThemeCubit>().toggle(),
              ),
            ),
          ),
          _RowTile(
            icon: Icons.translate_rounded,
            label: context.tr(TranslationKeys.language),
            trailing: TextButton(
              onPressed: () => context.read<LocaleCubit>().toggle(),
              child: Text(context.read<LocaleCubit>().isRtl ? 'العربية' : 'English'),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                context.read<IdentityCubit>().setName(_name.text);
                Navigator.of(context).pop();
              },
              child: Text(context.tr(TranslationKeys.save)),
            ),
          ),
        ],
      ),
    );
  }
}

class _RowTile extends StatelessWidget {
  const _RowTile({required this.icon, required this.label, required this.trailing});
  final IconData icon;
  final String label;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: context.colors.primary),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: context.text.bodyLarge)),
          trailing,
        ],
      ),
    );
  }
}
