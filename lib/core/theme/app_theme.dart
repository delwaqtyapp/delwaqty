import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_spacing.dart';
import 'app_text_styles.dart';

/// Builds the complete [ThemeData] for both light and dark modes.
///
/// Consumes the design-token classes so that every themed widget references
/// the central system rather than hard-coded values.
abstract final class AppTheme {
  /// Creates the light [ThemeData].
  static ThemeData lightTheme({String? fontFamily}) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.primaryLight,
      primary: AppColors.primaryLight,
      secondary: AppColors.secondaryLight,
      tertiary: AppColors.tertiaryLight,
      error: AppColors.errorLight,
      surface: AppColors.surfaceLight,
    );

    return _buildTheme(colorScheme, fontFamily);
  }

  /// Creates the dark [ThemeData].
  static ThemeData darkTheme({String? fontFamily}) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.primaryDark,
      brightness: Brightness.dark,
      primary: AppColors.primaryDark,
      secondary: AppColors.secondaryDark,
      tertiary: AppColors.tertiaryDark,
      error: AppColors.errorDark,
      surface: AppColors.surfaceDark,
    );

    return _buildTheme(colorScheme, fontFamily);
  }

  static ThemeData _buildTheme(ColorScheme colorScheme, String? fontFamily) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      fontFamily: fontFamily,
      textTheme: AppTextStyles.toTextTheme().apply(
        bodyColor: colorScheme.onSurface,
        displayColor: colorScheme.onSurface,
      ),
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: AppElevationValues.none,
        scrolledUnderElevation: AppElevationValues.xs,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
      ),
      scaffoldBackgroundColor: colorScheme.surface,
      cardTheme: CardThemeData(
        elevation: AppElevationValues.none,
        shape: const RoundedRectangleBorder(
          borderRadius: AppSpacing.borderRadiusLg,
        ),
        color: colorScheme.surfaceContainerLowest,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: AppElevationValues.none,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.buttonPaddingHorizontal,
            vertical: AppSpacing.buttonPaddingVertical,
          ),
          shape: const RoundedRectangleBorder(
            borderRadius: AppSpacing.borderRadiusLg,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.buttonPaddingHorizontal,
            vertical: AppSpacing.buttonPaddingVertical,
          ),
          shape: const RoundedRectangleBorder(
            borderRadius: AppSpacing.borderRadiusLg,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        border: OutlineInputBorder(
          borderRadius: AppSpacing.borderRadiusLg,
          borderSide: BorderSide(color: colorScheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppSpacing.borderRadiusLg,
          borderSide: BorderSide(color: colorScheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppSpacing.borderRadiusLg,
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppSpacing.borderRadiusLg,
          borderSide: BorderSide(color: colorScheme.error),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.fieldPaddingHorizontal,
          vertical: AppSpacing.fieldPaddingVertical,
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: AppSpacing.borderRadiusMd,
        ),
      ),
      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant,
        thickness: 1,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: colorScheme.surface,
        selectedItemColor: colorScheme.primary,
        unselectedItemColor: colorScheme.onSurfaceVariant,
        type: BottomNavigationBarType.fixed,
        elevation: AppElevationValues.lg,
      ),
    );
  }
}

/// Internal elevation constants used by [AppTheme].
///
/// Named to avoid clashing with [AppElevation] during the transition period.
abstract final class AppElevationValues {
  static const double none = 0;
  static const double xs = 1;
  static const double lg = 8;
}
