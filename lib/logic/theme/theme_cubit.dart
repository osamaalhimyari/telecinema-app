import 'package:flutter/material.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';

import '/core/services/theme_service.dart';
import '/core/theme/app_theme.dart';
import 'theme_state.dart';

/// Owns the theme mode and exposes the built [ThemeData]s. Persists the chosen
/// mode via [HydratedCubit] so it survives a restart. Implements
/// [ThemeService] so `MaterialApp` can read it without a Bloc dependency.
class ThemeCubit extends HydratedCubit<ThemeState> implements ThemeService {
  ThemeCubit() : super(const ThemeState());

  void setMode(ThemeMode mode) => emit(state.copyWith(mode: mode));

  void toggle() => emit(
    state.copyWith(mode: state.mode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark),
  );

  @override
  ThemeMode get themeMode => state.mode;
  @override
  ThemeData get lightTheme => AppTheme.build(false);
  @override
  ThemeData get darkTheme => AppTheme.build(true);

  @override
  ThemeState fromJson(Map<String, dynamic> json) {
    final index = json['mode'] as int?;
    final mode = (index != null && index >= 0 && index < ThemeMode.values.length)
        ? ThemeMode.values[index]
        : ThemeMode.dark;
    return ThemeState(mode: mode);
  }

  @override
  Map<String, dynamic> toJson(ThemeState state) => {'mode': state.mode.index};
}
