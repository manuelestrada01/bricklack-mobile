import 'package:flutter/material.dart';
import 'app_tokens.dart';

class AppTheme {
  static ThemeData get light => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.light(
          primary: AppColors.lego_yellow,
          onPrimary: AppColors.navy_base,
          secondary: AppColors.navy_base,
          onSecondary: AppColors.surface,
          surface: AppColors.surface,
          onSurface: AppColors.navy_base,
          error: AppColors.status_error,
        ),
        scaffoldBackgroundColor: AppColors.background,
        fontFamily: 'Outfit',
        cardTheme: CardTheme(
          color: AppColors.surface,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            side: BorderSide(
              color: AppColors.navy_base.withOpacity(0.08),
            ),
          ),
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: AppColors.surface,
          foregroundColor: AppColors.navy_base,
          elevation: 0,
          centerTitle: false,
        ),
      );
}
