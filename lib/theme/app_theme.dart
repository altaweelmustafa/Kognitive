import 'package:flutter/material.dart';

import '../config/color_config.dart';
import 'app_text.dart';

abstract final class AppTheme {
  static ThemeData get dark => _build(AppColors.dark, Brightness.dark);
  static ThemeData get light => _build(AppColors.light, Brightness.light);

  static ThemeData _build(AppColors c, Brightness brightness) {
    final base = ThemeData(brightness: brightness, fontFamily: AppText.sans);
    return base.copyWith(
      extensions: [c],
      scaffoldBackgroundColor: c.background,
      colorScheme: ColorScheme.fromSeed(
        seedColor: c.brandFill,
        brightness: brightness,
        primary: c.brandAccent,
        onPrimary: c.onBrand,
        surface: c.background,
        onSurface: c.textPrimary,
      ),
      textTheme: base.textTheme.apply(
        bodyColor: c.textPrimary,
        displayColor: c.textPrimary,
      ),
      iconTheme: IconThemeData(color: c.textPrimary),
      dividerTheme: DividerThemeData(color: c.divider, thickness: 1, space: 1),
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      appBarTheme: AppBarTheme(
        backgroundColor: c.background,
        foregroundColor: c.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: AppText.listTitle.copyWith(
          fontFamily: AppText.sans,
          fontWeight: FontWeight.w700,
          color: c.textPrimary,
        ),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: c.brandAccent,
        selectionColor: c.brandAccent.withValues(alpha: 0.35),
        selectionHandleColor: c.brandAccent,
      ),
    );
  }
}
