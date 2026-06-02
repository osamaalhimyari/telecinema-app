import 'package:flutter/material.dart';

import '../localization/app_localizations.dart';
import '../theme/app_theme.dart';

extension TranslateX on BuildContext {
  /// Localized string for [key]. See [AppLocalizations.tr].
  String tr(String key) => AppLocalizations.of(this).tr(key);
}

extension ThemeX on BuildContext {
  ThemeData get theme => Theme.of(this);
  ColorScheme get colors => Theme.of(this).colorScheme;
  ColorsModel get semantic => Theme.of(this).colorsModel;
  TextTheme get text => Theme.of(this).textTheme;
}

extension SnackX on BuildContext {
  void showSnack(String message) {
    ScaffoldMessenger.of(this)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}
