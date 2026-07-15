import 'package:flutter/material.dart';

/// Comprehensive design token color system for the Delwaqty platform.
///
/// Contains semantic colors, surface variants, merchant type colors,
/// order status colors, and core brand colors used throughout the app.
abstract final class AppColors {
  // ---------------------------------------------------------------------------
  // Core Brand Colors
  // ---------------------------------------------------------------------------

  /// Primary brand color for light theme.
  static const Color primaryLight = Color(0xFF6750A4);

  /// Primary brand color for dark theme.
  static const Color primaryDark = Color(0xFFD0BCFF);

  /// Secondary brand color for light theme.
  static const Color secondaryLight = Color(0xFF625B71);

  /// Secondary brand color for dark theme.
  static const Color secondaryDark = Color(0xFFCCC2DC);

  /// Tertiary brand color for light theme.
  static const Color tertiaryLight = Color(0xFF7D5260);

  /// Tertiary brand color for dark theme.
  static const Color tertiaryDark = Color(0xFFEFB8C8);

  /// Error color for light theme.
  static const Color errorLight = Color(0xFFB3261E);

  /// Error color for dark theme.
  static const Color errorDark = Color(0xFFF2B8B5);

  // ---------------------------------------------------------------------------
  // Semantic Colors
  // ---------------------------------------------------------------------------

  /// Success state color for light theme.
  static const Color successLight = Color(0xFF2E7D32);

  /// Success state color for dark theme.
  static const Color successDark = Color(0xFF81C784);

  /// Warning state color for light theme.
  static const Color warningLight = Color(0xFFF57C00);

  /// Warning state color for dark theme.
  static const Color warningDark = Color(0xFFFFB74D);

  /// Informational state color for light theme.
  static const Color infoLight = Color(0xFF0288D1);

  /// Informational state color for dark theme.
  static const Color infoDark = Color(0xFF4FC3F7);

  /// Hyperlink text color for light theme.
  static const Color linkLight = Color(0xFF1565C0);

  /// Hyperlink text color for dark theme.
  static const Color linkDark = Color(0xFF64B5F6);

  // ---------------------------------------------------------------------------
  // Surface Variants
  // ---------------------------------------------------------------------------

  /// Primary surface for light theme.
  static const Color surfaceLight = Color(0xFFFFFBFE);

  /// Primary surface for dark theme.
  static const Color surfaceDark = Color(0xFF1C1B1F);

  /// Dimmed surface for light theme.
  static const Color surfaceDimLight = Color(0xFFDED8E1);

  /// Dimmed surface for dark theme.
  static const Color surfaceDimDark = Color(0xFF141218);

  /// Bright surface for light theme.
  static const Color surfaceBrightLight = Color(0xFFFFFBFE);

  /// Bright surface for dark theme.
  static const Color surfaceBrightDark = Color(0xFF3B383E);

  /// Lowest container surface for light theme.
  static const Color surfaceContainerLowestLight = Color(0xFFFFFFFF);

  /// Lowest container surface for dark theme.
  static const Color surfaceContainerLowestDark = Color(0xFF0F0D13);

  /// Low container surface for light theme.
  static const Color surfaceContainerLowLight = Color(0xFFF7F2FA);

  /// Low container surface for dark theme.
  static const Color surfaceContainerLowDark = Color(0xFF1D1B20);

  /// Mid container surface for light theme.
  static const Color surfaceContainerMidLight = Color(0xFFF1ECF4);

  /// Mid container surface for dark theme.
  static const Color surfaceContainerMidDark = Color(0xFF211F26);

  /// High container surface for light theme.
  static const Color surfaceContainerHighLight = Color(0xFFECE6F0);

  /// High container surface for dark theme.
  static const Color surfaceContainerHighDark = Color(0xFF2B2930);

  /// Highest container surface for light theme.
  static const Color surfaceContainerHighestLight = Color(0xFFE6E0E9);

  /// Highest container surface for dark theme.
  static const Color surfaceContainerHighestDark = Color(0xFF36343B);

  // ---------------------------------------------------------------------------
  // Merchant Type Colors
  // ---------------------------------------------------------------------------

  /// Color representing food / restaurant merchants.
  static const Color merchantFood = Color(0xFFE65100);

  /// Color representing grocery merchants.
  static const Color merchantGrocery = Color(0xFF2E7D32);

  /// Color representing pharmacy merchants.
  static const Color merchantPharmacy = Color(0xFF0277BD);

  /// Color representing electronics merchants.
  static const Color merchantElectronics = Color(0xFF512DA8);

  /// Color representing fashion merchants.
  static const Color merchantFashion = Color(0xFFAD1457);

  /// Color representing furniture merchants.
  static const Color merchantFurniture = Color(0xFF4E342E);

  // ---------------------------------------------------------------------------
  // Order Status Colors
  // ---------------------------------------------------------------------------

  /// Color for pending orders.
  static const Color orderPending = Color(0xFFF57C00);

  /// Color for confirmed orders.
  static const Color orderConfirmed = Color(0xFF1565C0);

  /// Color for orders being prepared.
  static const Color orderPreparing = Color(0xFF7B1FA2);

  /// Color for orders ready for pickup / delivery.
  static const Color orderReady = Color(0xFF00897B);

  /// Color for orders in transit.
  static const Color orderInTransit = Color(0xFF0288D1);

  /// Color for delivered orders.
  static const Color orderDelivered = Color(0xFF2E7D32);

  /// Color for cancelled orders.
  static const Color orderCancelled = Color(0xFFC62828);

  // ---------------------------------------------------------------------------
  // Rating Colors
  // ---------------------------------------------------------------------------

  /// Amber color used for star ratings.
  static const Color rating = Color(0xFFFFC107);
}
