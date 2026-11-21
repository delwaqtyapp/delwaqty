import 'package:flutter/material.dart';

/// Typography design tokens for the Delwaqty platform.
///
/// Provides a set of pre-defined [TextStyle]s based on Material 3 type scale.
/// Always prefer these over raw `Theme.of(context).textTheme` accesses so that
/// weights, sizes and letter-spacing stay consistent across the app.
abstract final class AppTextStyles {
  // ---------------------------------------------------------------------------
  // Display
  // ---------------------------------------------------------------------------

  /// Display large — 57sp, -0.25px letter spacing.
  static const TextStyle displayLarge = TextStyle(
    fontSize: 57,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    height: 1.2,
  );

  /// Display medium — 45sp.
  static const TextStyle displayMedium = TextStyle(
    fontSize: 45,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    height: 1.22,
  );

  /// Display small — 36sp.
  static const TextStyle displaySmall = TextStyle(
    fontSize: 36,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    height: 1.28,
  );

  // ---------------------------------------------------------------------------
  // Headlines
  // ---------------------------------------------------------------------------

  /// Headline large — 32sp.
  static const TextStyle headlineLarge = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    height: 1.3,
  );

  /// Headline medium — 28sp.
  static const TextStyle headlineMedium = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    height: 1.3,
  );

  /// Headline small — 24sp.
  static const TextStyle headlineSmall = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    height: 1.3,
  );

  // ---------------------------------------------------------------------------
  // Titles
  // ---------------------------------------------------------------------------

  /// Title large — 22sp.
  static const TextStyle titleLarge = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    height: 1.35,
  );

  /// Title medium — 16sp, 0.15px letter spacing.
  static const TextStyle titleMedium = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    height: 1.35,
  );

  /// Title small — 14sp, 0.1px letter spacing.
  static const TextStyle titleSmall = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    height: 1.35,
  );

  // ---------------------------------------------------------------------------
  // Body
  // ---------------------------------------------------------------------------

  /// Body large — 16sp, 0.5px letter spacing.
  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    height: 1.55,
  );

  /// Body medium — 14sp, 0.25px letter spacing.
  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    height: 1.55,
  );

  /// Body small — 12sp, 0.4px letter spacing.
  static const TextStyle bodySmall = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    height: 1.45,
  );

  // ---------------------------------------------------------------------------
  // Labels
  // ---------------------------------------------------------------------------

  /// Label large — 14sp, 0.1px letter spacing.
  static const TextStyle labelLarge = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    letterSpacing: 0,
    height: 1.4,
  );

  /// Label medium — 12sp, 0.5px letter spacing.
  static const TextStyle labelMedium = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    letterSpacing: 0,
    height: 1.4,
  );

  /// Label small — 11sp, 0.5px letter spacing.
  static const TextStyle labelSmall = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    letterSpacing: 0,
    height: 1.4,
  );

  // ---------------------------------------------------------------------------
  // Money
  // ---------------------------------------------------------------------------

  /// Price — 16sp, extra-bold, tabular figures so numbers align in lists.
  static const TextStyle price = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w800,
    letterSpacing: 0,
    height: 1.3,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Returns a [TextTheme] mapping suitable for passing to [ThemeData.textTheme].
  ///
  /// [arabicFirst] selects the Arabic-first rhythm (zero letter-spacing,
  /// taller line-heights). The customer app passes `false` to keep its
  /// original look frozen by owner decision (Nov 2026); merchant, driver
  /// and admin use the Arabic-first rhythm.
  static TextTheme toTextTheme({Color? color, bool arabicFirst = true}) {
    final base = color != null ? TextStyle(color: color) : const TextStyle();
    if (!arabicFirst) {
      return TextTheme(
        displayLarge: displayLarge
            .copyWith(letterSpacing: -0.25, height: 1.12)
            .merge(base),
        displayMedium: displayMedium.copyWith(height: 1.16).merge(base),
        displaySmall: displaySmall.copyWith(height: 1.22).merge(base),
        headlineLarge: headlineLarge.copyWith(height: 1.25).merge(base),
        headlineMedium: headlineMedium.copyWith(height: 1.29).merge(base),
        headlineSmall: headlineSmall.copyWith(height: 1.33).merge(base),
        titleLarge: titleLarge.copyWith(height: 1.27).merge(base),
        titleMedium: titleMedium
            .copyWith(letterSpacing: 0.15, height: 1.5)
            .merge(base),
        titleSmall: titleSmall
            .copyWith(letterSpacing: 0.1, height: 1.43)
            .merge(base),
        bodyLarge: bodyLarge
            .copyWith(letterSpacing: 0.5, height: 1.5)
            .merge(base),
        bodyMedium: bodyMedium
            .copyWith(letterSpacing: 0.25, height: 1.43)
            .merge(base),
        bodySmall: bodySmall
            .copyWith(letterSpacing: 0.4, height: 1.33)
            .merge(base),
        labelLarge: labelLarge
            .copyWith(letterSpacing: 0.1, height: 1.43)
            .merge(base),
        labelMedium: labelMedium
            .copyWith(letterSpacing: 0.5, height: 1.33)
            .merge(base),
        labelSmall: labelSmall
            .copyWith(letterSpacing: 0.5, height: 1.45)
            .merge(base),
      );
    }
    return TextTheme(
      displayLarge: displayLarge.merge(base),
      displayMedium: displayMedium.merge(base),
      displaySmall: displaySmall.merge(base),
      headlineLarge: headlineLarge.merge(base),
      headlineMedium: headlineMedium.merge(base),
      headlineSmall: headlineSmall.merge(base),
      titleLarge: titleLarge.merge(base),
      titleMedium: titleMedium.merge(base),
      titleSmall: titleSmall.merge(base),
      bodyLarge: bodyLarge.merge(base),
      bodyMedium: bodyMedium.merge(base),
      bodySmall: bodySmall.merge(base),
      labelLarge: labelLarge.merge(base),
      labelMedium: labelMedium.merge(base),
      labelSmall: labelSmall.merge(base),
    );
  }
}
