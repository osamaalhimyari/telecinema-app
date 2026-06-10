import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';

/// Custom semantic colors not covered by [ColorScheme].
/// Access via `Theme.of(context).colorsModel.success`.
class ColorsModel extends ThemeExtension<ColorsModel> {
  final Color success;
  final Color info;
  final Color warning;

  const ColorsModel({required this.success, required this.info, required this.warning});

  @override
  ThemeExtension<ColorsModel> copyWith({Color? success, Color? info, Color? warning}) {
    return ColorsModel(
      success: success ?? this.success,
      info: info ?? this.info,
      warning: warning ?? this.warning,
    );
  }

  @override
  ThemeExtension<ColorsModel> lerp(ThemeExtension<ColorsModel>? other, double t) {
    if (other is! ColorsModel) return this;
    return ColorsModel(
      success: Color.lerp(success, other.success, t)!,
      info: Color.lerp(info, other.info, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
    );
  }
}

extension AppThemeGetter on ThemeData {
  ColorsModel get colorsModel => extension<ColorsModel>()!;
}

class AppTheme {
  AppTheme._();

  static const double _radiusSm = 10;
  static const double _radiusMd = 14;
  static const double _radiusLg = 20;

  static ThemeData build(bool isDark) {
    final AppColors c = isDark ? DarkColors() : LightColors();

    final colorScheme = ColorScheme(
      brightness: isDark ? Brightness.dark : Brightness.light,
      primary: c.primary,
      onPrimary: c.onPrimary,
      secondary: c.secondary,
      onSecondary: isDark ? const Color(0xFF04201C) : Colors.white,
      error: c.error,
      onError: Colors.white,
      surface: c.surface,
      onSurface: c.textPrimary,
      outline: c.border,
      outlineVariant: c.border,
    );

    final textTheme = TextTheme(
      headlineMedium: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: c.textPrimary,
        letterSpacing: -0.3,
        height: 1.25,
      ),
      titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: c.textPrimary),
      titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: c.textPrimary),
      titleSmall: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.textPrimary),
      bodyLarge: TextStyle(fontSize: 16, color: c.textPrimary, height: 1.5),
      bodyMedium: TextStyle(fontSize: 14, color: c.textSecondary, height: 1.45),
      bodySmall: TextStyle(fontSize: 12, color: c.textHint, height: 1.4),
      labelLarge: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: c.onPrimary,
        letterSpacing: 0.2,
      ),
      labelMedium: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: c.textSecondary),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: isDark ? Brightness.dark : Brightness.light,
      scaffoldBackgroundColor: c.scaffoldBackground,
      colorScheme: colorScheme,
      textTheme: textTheme,
      visualDensity: VisualDensity.adaptivePlatformDensity,
      splashFactory: InkRipple.splashFactory,
      dividerColor: c.border,
      disabledColor: c.textHint,
      extensions: [ColorsModel(success: c.success, info: c.info, warning: c.warning)],

      appBarTheme: AppBarTheme(
        backgroundColor: c.scaffoldBackground,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: false,
        iconTheme: IconThemeData(color: c.textPrimary, size: 22),
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: c.textPrimary,
        ),
        systemOverlayStyle: isDark
            ? SystemUiOverlayStyle.light.copyWith(statusBarColor: Colors.transparent)
            : SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.transparent),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: c.primary,
          foregroundColor: c.onPrimary,
          disabledBackgroundColor: c.inputFill,
          disabledForegroundColor: c.textHint,
          elevation: 0,
          minimumSize: const Size(0, 50),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_radiusSm)),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: c.primary,
          foregroundColor: c.onPrimary,
          minimumSize: const Size(0, 50),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_radiusSm)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: c.primary),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: c.textPrimary,
          side: BorderSide(color: c.border),
          minimumSize: const Size(0, 50),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_radiusSm)),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: c.textPrimary),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.inputFill,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: TextStyle(color: c.textHint, fontSize: 14),
        labelStyle: TextStyle(color: c.textSecondary, fontSize: 14),
        floatingLabelStyle: TextStyle(color: c.primary, fontSize: 14),
        errorStyle: TextStyle(color: c.error, fontSize: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_radiusSm),
          borderSide: BorderSide(color: c.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_radiusSm),
          borderSide: BorderSide(color: c.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_radiusSm),
          borderSide: BorderSide(color: c.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_radiusSm),
          borderSide: BorderSide(color: c.error),
        ),
      ),

      cardTheme: CardThemeData(
        color: c.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_radiusMd),
          side: BorderSide(color: c.border, width: 0.5),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_radiusMd)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: c.border,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(_radiusLg)),
        ),
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: c.scaffoldBackground,
        surfaceTintColor: Colors.transparent,
        // Solid primary pill on the active tab — same accent as the "Create
        // room" button — with the icon flipped to onPrimary so it reads on it.
        indicatorColor: c.primary,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected) ? c.onPrimary : c.textSecondary,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 12,
            fontWeight: states.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
            color: states.contains(WidgetState.selected) ? c.primary : c.textSecondary,
          ),
        ),
        elevation: 0,
        height: 68,
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: c.surfaceVariant,
        contentTextStyle: TextStyle(color: c.textPrimary, fontSize: 14),
        actionTextColor: c.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_radiusSm)),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: c.surfaceVariant,
        labelStyle: TextStyle(fontSize: 12, color: c.textPrimary),
        side: BorderSide(color: c.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99)),
      ),
      dividerTheme: DividerThemeData(color: c.border, thickness: 0.5, space: 1),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: c.primary,
        linearTrackColor: c.inputFill,
        circularTrackColor: c.inputFill,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: c.primary,
        foregroundColor: c.onPrimary,
        elevation: 2,
      ),
      iconTheme: IconThemeData(color: c.textPrimary, size: 22),
    );
  }
}
