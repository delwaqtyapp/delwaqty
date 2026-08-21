import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';
import 'app_spacing.dart';
import 'app_text_styles.dart';
import '../../features/admin/floating_sidebar/sidebar_theme.dart';

/// Builds the complete [ThemeData] for both light and dark modes.
///
/// Consumes the design-token classes so that every themed widget references
/// the central system rather than hard-coded values.
abstract final class AppTheme {
  /// Creates the light [ThemeData].
  static ThemeData lightTheme({String? fontFamily}) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.brandPurple,
      primary: AppColors.brandPurple,
      secondary: AppColors.brandViolet,
      tertiary: AppColors.primaryLight,
      error: AppColors.errorLight,
      surface: Colors.white,
      onSurface: const Color(0xFF17161C),
      primaryContainer: AppColors.brandLavender,
      onPrimaryContainer: AppColors.brandPurpleDeep,
      secondaryContainer: AppColors.brandLavenderSoft,
      onSecondaryContainer: AppColors.brandPurpleDeep,
      surfaceContainerLowest: Colors.white,
      surfaceContainerLow: AppColors.brandLavenderSoft,
      surfaceContainerHighest: const Color(0xFFEFEFF3),
      outlineVariant: const Color(0xFFE4E4EC),
    );

    return _buildTheme(colorScheme, fontFamily);
  }

  /// Creates the dark [ThemeData].
  static ThemeData darkTheme({String? fontFamily}) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.brandViolet,
      brightness: Brightness.dark,
      primary: AppColors.brandViolet,
      secondary: AppColors.brandGradientEndSoft,
      tertiary: AppColors.tertiaryDark,
      error: AppColors.errorDark,
      surface: AppColors.surfaceDark,
    );

    return _buildTheme(colorScheme, fontFamily);
  }

  static ThemeData _buildTheme(ColorScheme colorScheme, String? fontFamily) {
    final resolvedFamily = fontFamily ?? _defaultFontFamily;
    final baseTextTheme = AppTextStyles.toTextTheme().apply(
      bodyColor: colorScheme.onSurface,
      displayColor: colorScheme.onSurface,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      fontFamily: resolvedFamily,
      textTheme: fontFamily == null
          ? GoogleFonts.cairoTextTheme(baseTextTheme)
          : baseTextTheme,
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: AppElevationValues.none,
        scrolledUnderElevation: AppElevationValues.none,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        titleTextStyle: AppTextStyles.titleLarge.copyWith(
          color: colorScheme.onSurface,
          fontWeight: FontWeight.w800,
        ),
      ),
      scaffoldBackgroundColor: colorScheme.surface,
      cardTheme: CardThemeData(
        elevation: AppElevationValues.none,
        shape: const RoundedRectangleBorder(
          borderRadius: AppSpacing.borderRadiusCard,
        ),
        color: colorScheme.surfaceContainerLowest,
        margin: EdgeInsets.zero,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          elevation: AppElevationValues.none,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.d24,
            vertical: AppSpacing.d12,
          ),
          shape: const RoundedRectangleBorder(
            borderRadius: AppSpacing.borderRadiusButton,
          ),
          textStyle: AppTextStyles.labelLarge.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: AppElevationValues.none,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.buttonPaddingHorizontal,
            vertical: AppSpacing.buttonPaddingVertical,
          ),
          shape: const RoundedRectangleBorder(
            borderRadius: AppSpacing.borderRadiusButton,
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
            borderRadius: AppSpacing.borderRadiusButton,
          ),
          side: BorderSide(color: colorScheme.outlineVariant, width: 1.2),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: const RoundedRectangleBorder(
            borderRadius: AppSpacing.borderRadiusButton,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        border: const OutlineInputBorder(
          borderRadius: AppSpacing.borderRadiusSearch,
          borderSide: BorderSide.none,
        ),
        enabledBorder: const OutlineInputBorder(
          borderRadius: AppSpacing.borderRadiusSearch,
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppSpacing.borderRadiusSearch,
          borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppSpacing.borderRadiusSearch,
          borderSide: BorderSide(color: colorScheme.error),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.fieldPaddingHorizontal,
          vertical: AppSpacing.fieldPaddingVertical,
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colorScheme.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: AppSpacing.borderRadiusDialog,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colorScheme.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppSpacing.radiusSheet),
          ),
        ),
        showDragHandle: true,
        dragHandleColor: colorScheme.outlineVariant,
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
          side: BorderSide(color: colorScheme.outlineVariant),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        labelStyle: AppTextStyles.labelLarge.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        thickness: 1,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: colorScheme.surface,
        selectedItemColor: colorScheme.primary,
        unselectedItemColor: colorScheme.onSurfaceVariant,
        type: BottomNavigationBarType.fixed,
        elevation: AppElevationValues.none,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
      extensions: [
        if (colorScheme.brightness == Brightness.dark) SidebarTheme.dark else SidebarTheme.light,
      ],
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

/// The primary brand font family used across the app.
///
/// Cairo is loaded through `google_fonts` and provides a native Arabic
/// typeface with Latin support, improving legibility for both locales.
abstract final class AppFontFamily {
  static const String cairo = 'Cairo';
}

const String _defaultFontFamily = AppFontFamily.cairo;
