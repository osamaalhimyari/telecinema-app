import 'package:flutter/material.dart';

/// Read-only view of localization state. The concrete implementation is
/// [LocaleCubit] in `logic/localization`.
abstract class LocaleService {
  Locale get locale;
  List<Locale> get supportedLocales;
  bool get isRtl;
}
