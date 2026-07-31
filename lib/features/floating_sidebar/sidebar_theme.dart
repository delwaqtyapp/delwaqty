import 'dart:ui';
import 'package:flutter/material.dart';

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

  static const _darkTop = Color(0xFF262637);
  static const _darkBottom = Color(0xFF171820);
  static const _lightTop = Color(0xFFF8F9FE);
  static const _lightBottom = Color(0xFFEEEFF5);

  static const _selectedStart = Color(0xFF6C63FF);
  static const _selectedEnd = Color(0xFF8B7BFF);

  static const SidebarTheme dark = SidebarTheme(
    cardGradientTop: _darkTop,
    cardGradientBottom: _darkBottom,
    cardOpacity: 0.96,
    cardBorderColor: Color(0x14FFFFFF),
    cardShadowColor: Color(0x33000000),
    selectedGradientStart: _selectedStart,
    selectedGradientEnd: _selectedEnd,
    selectedIndicatorColor: _selectedStart,
    iconColor: Color(0xFF9E9EB8),
    textPrimary: Color(0xFFF5F5FA),
    textSecondary: Color(0xFF8E8EA8),
    dividerColor: Color(0x1AFFFFFF),
    sectionTitleColor: Color(0xFF7C7C9A),
    badgeBackground: Color(0xFF6C63FF),
    badgeTextColor: Color(0xFFFFFFFF),
    quickSettingsBackground: Color(0x0DFFFFFF),
  );

  static const SidebarTheme light = SidebarTheme(
    cardGradientTop: _lightTop,
    cardGradientBottom: _lightBottom,
    cardOpacity: 0.98,
    cardBorderColor: Color(0x1A000000),
    cardShadowColor: Color(0x08000000),
    selectedGradientStart: _selectedStart,
    selectedGradientEnd: _selectedEnd,
    selectedIndicatorColor: _selectedStart,
    iconColor: Color(0xFF6B7280),
    textPrimary: Color(0xFF1F2937),
    textSecondary: Color(0xFF9CA3AF),
    dividerColor: Color(0x1A000000),
    sectionTitleColor: Color(0xFF9CA3AF),
    badgeBackground: Color(0xFF6C63FF),
    badgeTextColor: Color(0xFFFFFFFF),
    quickSettingsBackground: Color(0x0D000000),
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
      selectedGradientStart: selectedGradientStart ?? this.selectedGradientStart,
      selectedGradientEnd: selectedGradientEnd ?? this.selectedGradientEnd,
      selectedIndicatorColor: selectedIndicatorColor ?? this.selectedIndicatorColor,
      iconColor: iconColor ?? this.iconColor,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      dividerColor: dividerColor ?? this.dividerColor,
      sectionTitleColor: sectionTitleColor ?? this.sectionTitleColor,
      badgeBackground: badgeBackground ?? this.badgeBackground,
      badgeTextColor: badgeTextColor ?? this.badgeTextColor,
      quickSettingsBackground: quickSettingsBackground ?? this.quickSettingsBackground,
    );
  }

  @override
  ThemeExtension<SidebarTheme> lerp(covariant ThemeExtension<SidebarTheme>? other, double t) {
    if (other is! SidebarTheme) return this;
    return SidebarTheme(
      cardGradientTop: Color.lerp(cardGradientTop, other.cardGradientTop, t)!,
      cardGradientBottom: Color.lerp(cardGradientBottom, other.cardGradientBottom, t)!,
      cardOpacity: lerpDouble(cardOpacity, other.cardOpacity, t)!,
      cardBorderColor: Color.lerp(cardBorderColor, other.cardBorderColor, t)!,
      cardShadowColor: Color.lerp(cardShadowColor, other.cardShadowColor, t)!,
      selectedGradientStart: Color.lerp(selectedGradientStart, other.selectedGradientStart, t)!,
      selectedGradientEnd: Color.lerp(selectedGradientEnd, other.selectedGradientEnd, t)!,
      selectedIndicatorColor: Color.lerp(selectedIndicatorColor, other.selectedIndicatorColor, t)!,
      iconColor: Color.lerp(iconColor, other.iconColor, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      dividerColor: Color.lerp(dividerColor, other.dividerColor, t)!,
      sectionTitleColor: Color.lerp(sectionTitleColor, other.sectionTitleColor, t)!,
      badgeBackground: Color.lerp(badgeBackground, other.badgeBackground, t)!,
      badgeTextColor: Color.lerp(badgeTextColor, other.badgeTextColor, t)!,
      quickSettingsBackground: Color.lerp(quickSettingsBackground, other.quickSettingsBackground, t)!,
    );
  }
}
