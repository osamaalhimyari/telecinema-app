import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '/core/config/app_config.dart';
import '/core/extensions/context_extensions.dart';
import '/core/localization/translation_keys.dart';
import '/injections/injection.dart';
import '/logic/identity/identity_cubit.dart';
import '/logic/localization/locale_cubit.dart';
import '/logic/storage/key_value_storage.dart';
import '/logic/storage/shared_prefs_storage.dart';
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

  // The server field shows the persisted override (what will be used after the
  // next launch), falling back to whatever is active now.
  late final TextEditingController _server = TextEditingController(
    text: sl<KeyValueStorage>().getString(StorageKeys.serverBaseUrl) ?? AppConfig.baseUrl,
  );
  String? _serverError;

  bool get _isServerDefault =>
      AppConfig.normalizeUrl(_server.text) == AppConfig.defaultBaseUrl;

  @override
  void dispose() {
    _name.dispose();
    _server.dispose();
    super.dispose();
  }

  void _resetServer() {
    setState(() {
      _server.text = AppConfig.defaultBaseUrl;
      _serverError = null;
    });
  }

  void _save() {
    final raw = _server.text;
    if (!AppConfig.isValidUrl(raw)) {
      setState(() => _serverError = context.tr(TranslationKeys.serverInvalid));
      return;
    }
    final normalized = AppConfig.normalizeUrl(raw);
    final storage = sl<KeyValueStorage>();
    final current = storage.getString(StorageKeys.serverBaseUrl) ?? AppConfig.defaultBaseUrl;
    final changed = AppConfig.normalizeUrl(current) != normalized;

    // Store the override, or clear it when it matches the built-in default so
    // we don't pin a stale URL across future default changes.
    if (normalized == AppConfig.defaultBaseUrl) {
      storage.remove(StorageKeys.serverBaseUrl);
    } else {
      storage.setString(StorageKeys.serverBaseUrl, normalized);
    }

    context.read<IdentityCubit>().setName(_name.text);

    final messenger = ScaffoldMessenger.of(context);
    final restartMsg = context.tr(TranslationKeys.serverChangedRestart);
    Navigator.of(context).pop();
    if (changed) {
      messenger.showSnackBar(SnackBar(content: Text(restartMsg)));
    }
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
            controller: _name,
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
          const SizedBox(height: 20),

          Text(context.tr(TranslationKeys.server), style: context.text.titleSmall),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _server,
                  keyboardType: TextInputType.url,
                  autocorrect: false,
                  textInputAction: TextInputAction.done,
                  onChanged: (_) => setState(() => _serverError = null),
                  decoration: InputDecoration(
                    hintText: context.tr(TranslationKeys.serverHint),
                    prefixIcon: const Icon(Icons.dns_outlined),
                  ),
                  onSubmitted: (_) => _save(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                tooltip: context.tr(TranslationKeys.resetToDefault),
                onPressed: _isServerDefault ? null : _resetServer,
                icon: const Icon(Icons.restart_alt_rounded),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _serverError ??
                '${context.tr(TranslationKeys.serverDefaultLabel)}: ${AppConfig.defaultBaseUrl}',
            style: context.text.bodySmall?.copyWith(
              color: _serverError != null ? context.colors.error : context.colors.outline,
            ),
          ),

          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _save,
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
