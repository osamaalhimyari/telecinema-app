import 'package:flutter/material.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';

import '/core/services/locale_service.dart';
import 'locale_state.dart';

/// Owns the active locale and persists it. Implements [LocaleService] so
/// `MaterialApp` and the `context.tr` extension can read it directly.
class LocaleCubit extends HydratedCubit<LocaleState> implements LocaleService {
  LocaleCubit() : super(const LocaleState());

  static const _supported = [Locale('en'), Locale('ar')];

  void setLocale(Locale locale) {
    if (!_supported.any((l) => l.languageCode == locale.languageCode)) return;
    emit(state.copyWith(locale: locale));
  }

  void toggle() => emit(
    state.copyWith(
      locale: state.locale.languageCode == 'ar' ? const Locale('en') : const Locale('ar'),
    ),
  );

  @override
  Locale get locale => state.locale;
  @override
  List<Locale> get supportedLocales => _supported;
  @override
  bool get isRtl => state.locale.languageCode == 'ar';

  @override
  LocaleState fromJson(Map<String, dynamic> json) {
    final code = json['languageCode'] as String?;
    return LocaleState(locale: Locale(code ?? 'en'));
  }

  @override
  Map<String, dynamic> toJson(LocaleState state) => {'languageCode': state.locale.languageCode};
}
