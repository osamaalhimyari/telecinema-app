import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '/core/app_info.dart';
import '/core/config/app_config.dart';
import '/core/extensions/context_extensions.dart';
import '/core/localization/translation_keys.dart';
import '/injections/injection.dart';
import '/logic/identity/identity_cubit.dart';
import '/logic/localization/locale_cubit.dart';
import '/logic/storage/key_value_storage.dart';
import '/logic/theme/theme_cubit.dart';
import '/logic/theme/theme_state.dart';
import '../bloc/settings_sheet/settings_sheet_cubit.dart';
import '../bloc/settings_sheet/settings_sheet_state.dart';

/// Bottom sheet for the lightweight, account-less settings: display name,
/// theme and language.
class SettingsSheet extends StatelessWidget {
  const SettingsSheet({super.key});

  static Future<void> show(BuildContext context) => showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => const SettingsSheet(),
  );

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => SettingsSheetCubit(
        sl<KeyValueStorage>(),
        context.read<IdentityCubit>(),
      ),
      child: const _SettingsSheetView(),
    );
  }
}

class _SettingsSheetView extends StatelessWidget {
  const _SettingsSheetView();

  Future<void> _save(BuildContext context) async {
    final cubit = context.read<SettingsSheetCubit>();
    final messenger = ScaffoldMessenger.of(context);
    final restartMsg = context.tr(TranslationKeys.serverChangedRestart);
    final invalidMsg = context.tr(TranslationKeys.serverInvalid);

    final result = await cubit.save();
    if (!context.mounted) return;

    if (result == SettingsSaveResult.invalid) {
      cubit.setServerError(invalidMsg);
      return;
    }

    Navigator.of(context).pop();
    if (result == SettingsSaveResult.savedChanged) {
      messenger.showSnackBar(SnackBar(content: Text(restartMsg)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<SettingsSheetCubit>();
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
          Text(
            context.tr(TranslationKeys.settings),
            style: context.text.titleLarge,
          ),
          const SizedBox(height: 20),

          Text(
            context.tr(TranslationKeys.yourName),
            style: context.text.titleSmall,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: cubit.name,
            maxLength: 30,
            textInputAction: TextInputAction.done,
            onChanged: (value) {
              if (value.isNotEmpty) {
                context.read<IdentityCubit>().setName(value);
              }
            },
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
              child: Text(
                context.read<LocaleCubit>().isRtl ? 'العربية' : 'English',
              ),
            ),
          ),
          _RowTile(
            icon: Icons.info_outline_rounded,
            label: context.tr(TranslationKeys.appVersion),
            trailing: Text(
              'v${AppInfo.version} (${AppInfo.buildNumber})',
              style: context.text.bodyMedium,
            ),
          ),
          const SizedBox(height: 20),

          Text(
            context.tr(TranslationKeys.server),
            style: context.text.titleSmall,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: cubit.server,
                  keyboardType: TextInputType.url,
                  autocorrect: false,
                  textInputAction: TextInputAction.done,
                  onChanged: (_) => cubit.onServerChanged(),
                  decoration: InputDecoration(
                    hintText: context.tr(TranslationKeys.serverHint),
                    prefixIcon: const Icon(Icons.dns_outlined),
                  ),
                  onSubmitted: (_) => _save(context),
                ),
              ),
              const SizedBox(width: 8),
              BlocSelector<SettingsSheetCubit, SettingsSheetState, bool>(
                selector: (state) => state.isServerDefault,
                builder: (context, isServerDefault) => IconButton.filledTonal(
                  tooltip: context.tr(TranslationKeys.resetToDefault),
                  onPressed: isServerDefault ? null : cubit.resetServer,
                  icon: const Icon(Icons.restart_alt_rounded),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          BlocSelector<SettingsSheetCubit, SettingsSheetState, String?>(
            selector: (state) => state.serverError,
            builder: (context, serverError) => Text(
              serverError ??
                  '${context.tr(TranslationKeys.serverDefaultLabel)}: ${AppConfig.defaultBaseUrl}',
              style: context.text.bodySmall?.copyWith(
                color: serverError != null
                    ? context.colors.error
                    : context.colors.outline,
              ),
            ),
          ),

          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => _save(context),
              child: Text(context.tr(TranslationKeys.save)),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _RowTile extends StatelessWidget {
  const _RowTile({
    required this.icon,
    required this.label,
    required this.trailing,
  });
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
