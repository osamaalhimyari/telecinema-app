import 'package:flutter/material.dart';

/// Read-only view of the active theme, consumed by `MaterialApp`. The concrete
/// implementation is [ThemeCubit] in `logic/theme`.
abstract class ThemeService {
  ThemeMode get themeMode;
  ThemeData get lightTheme;
  ThemeData get darkTheme;
}
