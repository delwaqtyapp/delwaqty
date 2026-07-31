import 'package:flutter/material.dart';
import 'package:delwaqty/features/ride_booking/ride_booking_theme.dart';
import 'package:delwaqty/features/ride_booking/ride_booking_animations.dart';

class PrimaryCtaButton extends StatelessWidget {
  const PrimaryCtaButton({
    required this.onPressed,
    required this.child,
    super.key,
    this.isLoading = false,
    this.isEnabled = true,
  });

  final VoidCallback? onPressed;
  final Widget child;
  final bool isLoading;
  final bool isEnabled;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: RideBookingTheme.screenPadding,
      child: GradientPulseButton(
        onPressed: onPressed,
        isLoading: isLoading,
        isEnabled: isEnabled,
        height: RideBookingTheme.ctaHeight,
        borderRadius: RideBookingTheme.ctaRadius,
        gradient: RideBookingTheme.ctaGradient,
        child: child,
      ),
    );
  }
}
