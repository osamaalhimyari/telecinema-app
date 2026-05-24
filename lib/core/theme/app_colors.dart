import 'package:flutter/material.dart';

/// Semantic color tokens. Two concrete palettes (light/dark) implement this,
/// and [AppTheme] maps them onto a Material [ThemeData]. The watch-party brand
/// is a teal accent on a near-black canvas (mirroring the website).
abstract class AppColors {
  Color get primary;
  Color get onPrimary;
  Color get secondary;
  Color get scaffoldBackground;
  Color get surface;
  Color get surfaceVariant;
  Color get textPrimary;
  Color get textSecondary;
  Color get textHint;
  Color get inputFill;
  Color get border;
  Color get success;
  Color get info;
  Color get warning;
  Color get error;
}

/// Dark — the watch-party default: OLED-friendly near-black with a teal accent.
class DarkColors implements AppColors {
  @override
  Color get primary => const Color(0xFF14B8A6); // teal-500
  @override
  Color get onPrimary => const Color(0xFF04201C);
  @override
  Color get secondary => const Color(0xFF2DD4BF); // teal-400

  @override
  Color get scaffoldBackground => const Color(0xFF0B0D11);
  @override
  Color get surface => const Color(0xFF14171D); // cards
  @override
  Color get surfaceVariant => const Color(0xFF1C2027); // wells, inputs

  @override
  Color get textPrimary => const Color(0xFFEDEFF2);
  @override
  Color get textSecondary => const Color(0xFF9AA3B0);
  @override
  Color get textHint => const Color(0xFF626B79);

  @override
  Color get inputFill => const Color(0xFF1C2027);
  @override
  Color get border => const Color(0xFF262B34);

  @override
  Color get success => const Color(0xFF34D399);
  @override
  Color get info => const Color(0xFF60A5FA);
  @override
  Color get warning => const Color(0xFFFBBF24);
  @override
  Color get error => const Color(0xFFF87171);
}

/// Light — a calm alternative with the same teal accent.
class LightColors implements AppColors {
  @override
  Color get primary => const Color(0xFF0D9488); // teal-600
  @override
  Color get onPrimary => const Color(0xFFFFFFFF);
  @override
  Color get secondary => const Color(0xFF14B8A6);

  @override
  Color get scaffoldBackground => const Color(0xFFF7F8FA);
  @override
  Color get surface => const Color(0xFFFFFFFF);
  @override
  Color get surfaceVariant => const Color(0xFFEFF1F4);

  @override
  Color get textPrimary => const Color(0xFF15181E);
  @override
  Color get textSecondary => const Color(0xFF55606E);
  @override
  Color get textHint => const Color(0xFF98A1AE);

  @override
  Color get inputFill => const Color(0xFFEFF1F4);
  @override
  Color get border => const Color(0xFFE2E5EA);

  @override
  Color get success => const Color(0xFF059669);
  @override
  Color get info => const Color(0xFF2563EB);
  @override
  Color get warning => const Color(0xFFD97706);
  @override
  Color get error => const Color(0xFFDC2626);
}
