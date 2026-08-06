import 'package:flutter/material.dart';

/// Comprehensive design token color system for the Delwaqty platform.
///
/// Contains semantic colors, surface variants, merchant type colors,
/// order status colors, and core brand colors used throughout the app.
abstract final class AppColors {
  // ---------------------------------------------------------------------------
  // Premium Brand Palette (V2)
  // ---------------------------------------------------------------------------

  /// Deep purple — the signature primary brand color.
  static const Color brandPurple = Color(0xFF5B3DF0);

  /// Even deeper purple used for gradient anchors / dark surfaces.
  static const Color brandPurpleDeep = Color(0xFF3B1DB0);

  /// Vibrant violet used at the light end of brand gradients.
  static const Color brandViolet = Color(0xFF8B5CF6);

  /// Soft lavender tint used for subtle brand backgrounds.
  static const Color brandLavender = Color(0xFFEDE9FE);

  /// Very light lavender for hover / tinted fills.
  static const Color brandLavenderSoft = Color(0xFFF5F3FF);

  /// Apple-style soft gray background for light mode.
  static const Color brandSoftGray = Color(0xFFF5F6F8);

  /// Start color of the primary brand gradient.
  static const Color brandGradientStart = Color(0xFF5B3DF0);

  /// End color of the primary brand gradient.
  static const Color brandGradientEnd = Color(0xFF8B5CF6);

  /// End color for softer / larger brand gradients.
  static const Color brandGradientEndSoft = Color(0xFFA78BFA);

  /// Premium soft shadow tint — `0 10 35 rgba(98,65,200,.10)`.
  static const Color shadowBrand = Color(0x1A6241C8);

  /// Dark premium shadow tint for floating surfaces.
  static const Color shadowFloat = Color(0x1F3B1DB0);

  /// Cyan accent for gradients and highlights.
  static const Color brandCyan = Color(0xFF06B6D4);

  /// Teal accent for secondary gradient endpoints.
  static const Color brandTeal = Color(0xFF14B8A6);

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
  // Service Category Colors
  // ---------------------------------------------------------------------------

  /// Color representing the restaurants service.
  static const Color serviceRestaurant = Color(0xFFE65100);

  /// Color representing the grocery service.
  static const Color serviceGrocery = Color(0xFF2E7D32);

  /// Color representing the pharmacy service.
  static const Color servicePharmacy = Color(0xFF0277BD);

  /// Color representing the ride / tawsila service.
  static const Color serviceRide = Color(0xFF512DA8);

  /// Color representing home services.
  static const Color serviceHome = Color(0xFF4E342E);

  /// Color representing the delivery service.
  static const Color serviceDelivery = Color(0xFF00897B);

  /// Color representing the offers service.
  static const Color serviceOffers = Color(0xFFAD1457);

  /// Color representing the more / settings service.
  static const Color serviceMore = Color(0xFF616161);

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
