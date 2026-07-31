import 'package:flutter/material.dart';

abstract final class RideBookingTheme {
  static const Color primaryPurple = Color(0xFF8B5CF6);
  static const Color secondaryPurple = Color(0xFFA78BFA);
  static const Color darkBg = Color(0xFF141419);
  static const Color cardBg = Color(0xFF1E1E28);
  static const Color cardBgLight = Color(0xFF262632);
  static const Color border = Color(0x14FFFFFF);
  static const Color green = Color(0xFF34C759);
  static const Color red = Color(0xFFFF5C5C);
  static const Color amber = Color(0xFFFFC107);
  static const Color whiteAlpha06 = Color(0x0FFFFFFF);
  static const Color whiteAlpha08 = Color(0x14FFFFFF);
  static const Color whiteAlpha12 = Color(0x1FFFFFFF);
  static const Color whiteAlpha16 = Color(0x29FFFFFF);
  static const Color whiteAlpha24 = Color(0x3DFFFFFF);
  static const Color whiteAlpha40 = Color(0x66FFFFFF);
  static const Color whiteAlpha60 = Color(0x99FFFFFF);
  static const Color whiteAlpha80 = Color(0xCCFFFFFF);

  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryPurple, secondaryPurple],
  );

  static const LinearGradient darkCardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [cardBg, Color(0xFF1A1A24)],
  );

  static const LinearGradient ctaGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF7C3AED), primaryPurple, secondaryPurple],
  );

  static EdgeInsets get screenPadding => const EdgeInsets.symmetric(horizontal: 20);

  static const double sectionSpacing = 16;
  static const double cardRadius = 24;
  static const double innerRadius = 16;
  static const double chipRadius = 12;
  static const double ctaHeight = 60;
  static const double ctaRadius = 22;
}

class RideBookingCard extends StatelessWidget {
  const RideBookingCard({
    required this.child,
    super.key,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius,
    this.gradient,
    this.border,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double? borderRadius;
  final Gradient? gradient;
  final Border? border;

  @override
  Widget build(BuildContext context) {
    final r = borderRadius ?? RideBookingTheme.cardRadius;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        gradient: gradient ?? RideBookingTheme.darkCardGradient,
        borderRadius: BorderRadius.circular(r),
        border: border ??
            Border.all(color: RideBookingTheme.whiteAlpha08, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 40,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: child,
    );
  }
}

class RideBookingSectionTitle extends StatelessWidget {
  const RideBookingSectionTitle({
    required this.text,
    super.key,
    this.trailing,
  });

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: RideBookingTheme.screenPadding,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            text,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: RideBookingTheme.whiteAlpha80,
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
