import 'dart:ui';

import 'package:flutter/material.dart';

import 'package:delwaqty/core/theme/app_colors.dart';

class SidebarTheme extends ThemeExtension<SidebarTheme> {
  const SidebarTheme({
    required this.cardGradientTop,
    required this.cardGradientBottom,
    required this.cardOpacity,
    required this.cardBorderColor,
    required this.cardShadowColor,
    required this.selectedGradientStart,
    required this.selectedGradientEnd,
    required this.selectedIndicatorColor,
    required this.iconColor,
    required this.textPrimary,
    required this.textSecondary,
    required this.dividerColor,
    required this.sectionTitleColor,
    required this.badgeBackground,
    required this.badgeTextColor,
    required this.quickSettingsBackground,
  });

  final Color cardGradientTop;
  final Color cardGradientBottom;
  final double cardOpacity;
  final Color cardBorderColor;
  final Color cardShadowColor;
  final Color selectedGradientStart;
  final Color selectedGradientEnd;
  final Color selectedIndicatorColor;
  final Color iconColor;
  final Color textPrimary;
  final Color textSecondary;
  final Color dividerColor;
  final Color sectionTitleColor;
  final Color badgeBackground;
  final Color badgeTextColor;
  final Color quickSettingsBackground;

  // Derived from AppColors (design batch 4.1): the selected state runs the
  // brandPurple -> brandViolet gradient; surfaces and text use the shared
  // tokens so the sidebar follows palette changes automatically.
  static final SidebarTheme dark = SidebarTheme(
    cardGradientTop: AppColors.surfaceContainerHighDark,
    cardGradientBottom: AppColors.surfaceContainerLowDark,
    cardOpacity: 0.96,
    cardBorderColor: Colors.white.withValues(alpha: 0.08),
    cardShadowColor: Colors.black.withValues(alpha: 0.2),
    selectedGradientStart: AppColors.brandPurple,
    selectedGradientEnd: AppColors.brandViolet,
    selectedIndicatorColor: AppColors.brandPurple,
    iconColor: Colors.white.withValues(alpha: 0.62),
    textPrimary: Colors.white.withValues(alpha: 0.96),
    textSecondary: Colors.white.withValues(alpha: 0.56),
    dividerColor: Colors.white.withValues(alpha: 0.1),
    sectionTitleColor: Colors.white.withValues(alpha: 0.49),
    badgeBackground: AppColors.brandPurple,
    badgeTextColor: Colors.white,
    quickSettingsBackground: Colors.white.withValues(alpha: 0.05),
  );

  static final SidebarTheme light = SidebarTheme(
    cardGradientTop: AppColors.brandLavenderSoft,
    cardGradientBottom: AppColors.brandSoftGray,
    cardOpacity: 0.98,
    cardBorderColor: Colors.black.withValues(alpha: 0.1),
    cardShadowColor: Colors.black.withValues(alpha: 0.03),
    selectedGradientStart: AppColors.brandPurple,
    selectedGradientEnd: AppColors.brandViolet,
    selectedIndicatorColor: AppColors.brandPurple,
    iconColor: AppColors.textMuted,
    textPrimary: AppColors.textPrimary,
    textSecondary: AppColors.textMuted,
    dividerColor: AppColors.borderSubtle,
    sectionTitleColor: AppColors.textMuted,
    badgeBackground: AppColors.brandPurple,
    badgeTextColor: Colors.white,
    quickSettingsBackground: Colors.black.withValues(alpha: 0.05),
  );

  @override
  ThemeExtension<SidebarTheme> copyWith({
    Color? cardGradientTop,
    Color? cardGradientBottom,
    double? cardOpacity,
    Color? cardBorderColor,
    Color? cardShadowColor,
    Color? selectedGradientStart,
    Color? selectedGradientEnd,
    Color? selectedIndicatorColor,
    Color? iconColor,
    Color? textPrimary,
    Color? textSecondary,
    Color? dividerColor,
    Color? sectionTitleColor,
    Color? badgeBackground,
    Color? badgeTextColor,
    Color? quickSettingsBackground,
  }) {
    return SidebarTheme(
      cardGradientTop: cardGradientTop ?? this.cardGradientTop,
      cardGradientBottom: cardGradientBottom ?? this.cardGradientBottom,
      cardOpacity: cardOpacity ?? this.cardOpacity,
      cardBorderColor: cardBorderColor ?? this.cardBorderColor,
      cardShadowColor: cardShadowColor ?? this.cardShadowColor,
      selectedGradientStart:
          selectedGradientStart ?? this.selectedGradientStart,
      selectedGradientEnd: selectedGradientEnd ?? this.selectedGradientEnd,
      selectedIndicatorColor:
          selectedIndicatorColor ?? this.selectedIndicatorColor,
      iconColor: iconColor ?? this.iconColor,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      dividerColor: dividerColor ?? this.dividerColor,
      sectionTitleColor: sectionTitleColor ?? this.sectionTitleColor,
      badgeBackground: badgeBackground ?? this.badgeBackground,
      badgeTextColor: badgeTextColor ?? this.badgeTextColor,
      quickSettingsBackground:
          quickSettingsBackground ?? this.quickSettingsBackground,
    );
  }

  @override
  ThemeExtension<SidebarTheme> lerp(
    covariant ThemeExtension<SidebarTheme>? other,
    double t,
  ) {
    if (other is! SidebarTheme) return this;
    return SidebarTheme(
      cardGradientTop: Color.lerp(cardGradientTop, other.cardGradientTop, t)!,
      cardGradientBottom: Color.lerp(
        cardGradientBottom,
        other.cardGradientBottom,
        t,
      )!,
      cardOpacity: lerpDouble(cardOpacity, other.cardOpacity, t)!,
      cardBorderColor: Color.lerp(cardBorderColor, other.cardBorderColor, t)!,
      cardShadowColor: Color.lerp(cardShadowColor, other.cardShadowColor, t)!,
      selectedGradientStart: Color.lerp(
        selectedGradientStart,
        other.selectedGradientStart,
        t,
      )!,
      selectedGradientEnd: Color.lerp(
        selectedGradientEnd,
        other.selectedGradientEnd,
        t,
      )!,
      selectedIndicatorColor: Color.lerp(
        selectedIndicatorColor,
        other.selectedIndicatorColor,
        t,
      )!,
      iconColor: Color.lerp(iconColor, other.iconColor, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      dividerColor: Color.lerp(dividerColor, other.dividerColor, t)!,
      sectionTitleColor: Color.lerp(
        sectionTitleColor,
        other.sectionTitleColor,
        t,
      )!,
      badgeBackground: Color.lerp(badgeBackground, other.badgeBackground, t)!,
      badgeTextColor: Color.lerp(badgeTextColor, other.badgeTextColor, t)!,
      quickSettingsBackground: Color.lerp(
        quickSettingsBackground,
        other.quickSettingsBackground,
        t,
      )!,
    );
  }
}
