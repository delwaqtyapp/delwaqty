import 'package:flutter/material.dart';

/// Elevation design tokens for the Delwaqty platform.
///
/// Provides a consistent set of elevation values and corresponding
/// [BoxShadow] definitions that can be applied to containers throughout the app.
abstract final class AppElevation {
  // ---------------------------------------------------------------------------
  // Elevation Values (in logical pixels)
  // ---------------------------------------------------------------------------

  /// No elevation — 0px.
  static const double none = 0;

  /// Extra small elevation — 1px.
  static const double xs = 1;

  /// Small elevation — 2px.
  static const double sm = 2;

  /// Medium elevation — 4px.
  static const double md = 4;

  /// Large elevation — 8px.
  static const double lg = 8;

  /// Extra large elevation — 12px.
  static const double xl = 12;

  // ---------------------------------------------------------------------------
  // BoxShadow Definitions
  // ---------------------------------------------------------------------------

  /// Shadow for no elevation (empty list).
  static const List<BoxShadow> shadowNone = [];

  /// Shadow for extra small elevation.
  static const List<BoxShadow> shadowXs = [
    BoxShadow(color: Color(0x0A000000), blurRadius: 1, offset: Offset(0, 1)),
  ];

  /// Shadow for small elevation.
  static const List<BoxShadow> shadowSm = [
    BoxShadow(color: Color(0x14000000), blurRadius: 2, offset: Offset(0, 1)),
    BoxShadow(color: Color(0x0A000000), blurRadius: 1, offset: Offset(0, 1)),
  ];

  /// Shadow for medium elevation.
  static const List<BoxShadow> shadowMd = [
    BoxShadow(color: Color(0x1A000000), blurRadius: 4, offset: Offset(0, 2)),
    BoxShadow(color: Color(0x0F000000), blurRadius: 2, offset: Offset(0, 1)),
  ];

  /// Shadow for large elevation.
  static const List<BoxShadow> shadowLg = [
    BoxShadow(color: Color(0x21000000), blurRadius: 8, offset: Offset(0, 4)),
    BoxShadow(color: Color(0x14000000), blurRadius: 4, offset: Offset(0, 2)),
  ];

  /// Shadow for extra large elevation.
  static const List<BoxShadow> shadowXl = [
    BoxShadow(color: Color(0x29000000), blurRadius: 12, offset: Offset(0, 6)),
    BoxShadow(color: Color(0x1A000000), blurRadius: 6, offset: Offset(0, 3)),
  ];

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Returns the [BoxShadow] list for a given elevation level.
  static List<BoxShadow> shadowsFor(double elevation) {
    if (elevation <= none) return shadowNone;
    if (elevation <= xs) return shadowXs;
    if (elevation <= sm) return shadowSm;
    if (elevation <= md) return shadowMd;
    if (elevation <= lg) return shadowLg;
    return shadowXl;
  }

  /// Returns a [BoxDecoration] with the given [elevation] and optional
  /// [color] and [borderRadius].
  static BoxDecoration decoration({
    required double elevation,
    Color? color,
    BorderRadiusGeometry? borderRadius,
  }) {
    return BoxDecoration(
      color: color,
      borderRadius: borderRadius,
      boxShadow: shadowsFor(elevation),
    );
  }
}
