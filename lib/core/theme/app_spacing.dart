import 'package:flutter/material.dart';

/// Comprehensive spacing design tokens for the Delwaqty platform.
///
/// All dimensions follow a 4px base grid for consistent visual rhythm.
/// Named constants provide semantic meaning for common spacing needs.
abstract final class AppSpacing {
  // ---------------------------------------------------------------------------
  // 4px Grid System (0 – 96)
  // ---------------------------------------------------------------------------

  /// 0px spacing.
  static const double d0 = 0;

  /// 4px spacing.
  static const double d4 = 4;

  /// 8px spacing.
  static const double d8 = 8;

  /// 12px spacing.
  static const double d12 = 12;

  /// 16px spacing.
  static const double d16 = 16;

  /// 20px spacing.
  static const double d20 = 20;

  /// 24px spacing.
  static const double d24 = 24;

  /// 28px spacing.
  static const double d28 = 28;

  /// 32px spacing.
  static const double d32 = 32;

  /// 36px spacing.
  static const double d36 = 36;

  /// 40px spacing.
  static const double d40 = 40;

  /// 44px spacing.
  static const double d44 = 44;

  /// 48px spacing.
  static const double d48 = 48;

  /// 56px spacing.
  static const double d56 = 56;

  /// 64px spacing.
  static const double d64 = 64;

  /// 72px spacing.
  static const double d72 = 72;

  /// 80px spacing.
  static const double d80 = 80;

  /// 96px spacing.
  static const double d96 = 96;

  // ---------------------------------------------------------------------------
  // Semantic Named Spacings
  // ---------------------------------------------------------------------------

  /// Extra small spacing — 4px.
  static const double xs = d4;

  /// Small spacing — 8px.
  static const double sm = d8;

  /// Medium spacing — 12px.
  static const double md = d12;

  /// Large spacing — 16px.
  static const double lg = d16;

  /// Extra large spacing — 24px.
  static const double xl = d24;

  /// Double extra large spacing — 32px.
  static const double xxl = d32;

  /// Triple extra large spacing — 48px.
  static const double xxxl = d48;

  // ---------------------------------------------------------------------------
  // Padding Constants
  // ---------------------------------------------------------------------------

  /// Standard horizontal padding used inside screen-level containers.
  static const double screenHorizontalPadding = d16;

  /// Standard vertical padding used inside screen-level containers.
  static const double screenVerticalPadding = d16;

  /// Horizontal padding inside card widgets.
  static const double cardPaddingHorizontal = d16;

  /// Vertical padding inside card widgets.
  static const double cardPaddingVertical = d12;

  /// Horizontal padding inside list tile widgets.
  static const double listTilePaddingHorizontal = d16;

  /// Vertical padding inside list tile widgets.
  static const double listTilePaddingVertical = d12;

  /// Padding inside button widgets.
  static const double buttonPaddingHorizontal = d24;

  /// Vertical padding inside button widgets.
  static const double buttonPaddingVertical = d12;

  /// Padding inside dialog widgets.
  static const double dialogPadding = d24;

  /// Padding inside bottom sheet content.
  static const double bottomSheetPadding = d16;

  /// Padding inside text field content.
  static const double fieldPaddingHorizontal = d16;

  /// Vertical padding inside text field content.
  static const double fieldPaddingVertical = 14;

  // ---------------------------------------------------------------------------
  // Margin Constants
  // ---------------------------------------------------------------------------

  /// Horizontal margin for section containers.
  static const double sectionMarginHorizontal = d16;

  /// Vertical margin between sections.
  static const double sectionMarginVertical = d16;

  /// Vertical margin between list items.
  static const double listItemMarginVertical = d8;

  /// Horizontal margin for card widgets.
  static const double cardMarginHorizontal = d16;

  /// Vertical margin for card widgets.
  static const double cardMarginVertical = d8;

  /// Margin between chip widgets.
  static const double chipMargin = d8;

  // ---------------------------------------------------------------------------
  // Border Radii
  // ---------------------------------------------------------------------------

  /// Small border radius — 4px.
  static const double radiusSm = d4;

  /// Medium border radius — 8px.
  static const double radiusMd = d8;

  /// Large border radius — 12px.
  static const double radiusLg = d12;

  /// Extra large border radius — 16px.
  static const double radiusXl = d16;

  /// Double extra large border radius — 24px.
  static const double radiusXxl = d24;

  /// Fully rounded border radius — 999px (used for pills / circles).
  static const double radiusFull = 999;

  /// Convenience [BorderRadius] for small corners.
  static const BorderRadius borderRadiusSm = BorderRadius.all(Radius.circular(radiusSm));

  /// Convenience [BorderRadius] for medium corners.
  static const BorderRadius borderRadiusMd = BorderRadius.all(Radius.circular(radiusMd));

  /// Convenience [BorderRadius] for large corners.
  static const BorderRadius borderRadiusLg = BorderRadius.all(Radius.circular(radiusLg));

  /// Convenience [BorderRadius] for extra large corners.
  static const BorderRadius borderRadiusXl = BorderRadius.all(Radius.circular(radiusXl));

  /// Convenience [BorderRadius] for double extra large corners.
  static const BorderRadius borderRadiusXxl = BorderRadius.all(Radius.circular(radiusXxl));

  /// Convenience [BorderRadius] for fully rounded corners.
  static const BorderRadius borderRadiusFull = BorderRadius.all(Radius.circular(radiusFull));
}
