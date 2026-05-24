import 'package:flutter/material.dart';

import 'lang/ar_ar.dart';
import 'lang/en_us.dart';

/// Lightweight, map-based localization (no ARB/codegen) — the same approach as
/// the rider reference. Look up strings with `context.tr(TranslationKeys.x)`.
class AppLocalizations {
  AppLocalizations(this.locale);

  final Locale locale;

  static AppLocalizations of(BuildContext context) =>
      Localizations.of<AppLocalizations>(context, AppLocalizations)!;

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  static const Map<String, Map<String, String>> _all = {'en': enUs, 'ar': arAr};

  Map<String, String> get _map => _all[locale.languageCode] ?? enUs;

  /// Translate [key]. Falls back to the English value, then the raw key, so a
  /// missing string is visible rather than crashing.
  String tr(String key) => _map[key] ?? enUs[key] ?? key;
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => const ['en', 'ar'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async => AppLocalizations(locale);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
