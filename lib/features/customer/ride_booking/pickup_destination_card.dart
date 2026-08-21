import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:delwaqty/features/customer/ride_booking/ride_booking_theme.dart';

class PickupDestinationCard extends StatelessWidget {
  const PickupDestinationCard({
    required this.pickupAddress,
    required this.dropoffAddress,
    required this.hasPickup,
    required this.hasDropoff,
    required this.onPickupTap,
    required this.onDropoffTap,
    super.key,
  });

  final String pickupAddress;
  final String dropoffAddress;
  final bool hasPickup;
  final bool hasDropoff;
  final VoidCallback onPickupTap;
  final VoidCallback onDropoffTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return ClipRRect(
      borderRadius: BorderRadius.circular(RideBookingTheme.cardRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                RideBookingTheme.cardBg.withValues(alpha: 0.95),
                RideBookingTheme.cardBg.withValues(alpha: 0.85),
              ],
            ),
            borderRadius: BorderRadius.circular(RideBookingTheme.cardRadius),
            border: Border.all(
              color: RideBookingTheme.whiteAlpha08,
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 28,
                offset: const Offset(0, 12),
              ),
              BoxShadow(
                color: RideBookingTheme.primaryPurple.withValues(alpha: 0.06),
                blurRadius: 40,
                offset: const Offset(0, 20),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _AnimatedRouteLine(hasPickup: hasPickup, hasDropoff: hasDropoff),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  children: [
                    _LocationField(
                      text: hasPickup ? pickupAddress : l10n.currentLocation,
                      hint: l10n.currentLocation,
                      hasValue: hasPickup,
                      dotColor: RideBookingTheme.green,
                      onTap: onPickupTap,
                    ),
                    const SizedBox(height: 12),
                    _LocationField(
                      text: hasDropoff ? dropoffAddress : l10n.whereTo,
                      hint: l10n.whereTo,
                      hasValue: hasDropoff,
                      dotColor: RideBookingTheme.red,
                      onTap: onDropoffTap,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AnimatedRouteLine extends StatelessWidget {
  const _AnimatedRouteLine({required this.hasPickup, required this.hasDropoff});

  final bool hasPickup;
  final bool hasDropoff;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: SizedBox(
        width: 24,
        height: 72,
        child: CustomPaint(
          painter: _RouteLinePainter(
            hasPickup: hasPickup,
            hasDropoff: hasDropoff,
          ),
        ),
      ),
    );
  }
}

class _RouteLinePainter extends CustomPainter {
  _RouteLinePainter({required this.hasPickup, required this.hasDropoff});

  final bool hasPickup;
  final bool hasDropoff;

  @override
  void paint(Canvas canvas, Size size) {
    final pickupColor =
        hasPickup ? RideBookingTheme.green : RideBookingTheme.whiteAlpha24;
    final dropoffColor =
        hasDropoff ? RideBookingTheme.red : RideBookingTheme.whiteAlpha24;

    final pickupPaint = Paint()
      ..color = pickupColor
      ..style = PaintingStyle.fill;

    final dropoffPaint = Paint()
      ..color = dropoffColor
      ..style = PaintingStyle.fill;

    canvas.drawCircle(const Offset(12, 6), 6, pickupPaint);

    if (hasPickup) {
      final glowPaint = Paint()
        ..color = RideBookingTheme.green.withValues(alpha: 0.2)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(const Offset(12, 6), 10, glowPaint);
    }

    final dashPath = Path();
    const dashWidth = 3.0;
    const dashSpace = 4.0;
    var y = 16.0;
    while (y < size.height - 12) {
      dashPath.moveTo(12, y);
      dashPath.lineTo(12, (y + dashWidth).clamp(0, size.height - 12));
      y += dashWidth + dashSpace;
    }

    final activeLine = hasPickup && hasDropoff;
    final dashPaint = Paint()
      ..color = activeLine
          ? RideBookingTheme.primaryPurple.withValues(alpha: 0.5)
          : RideBookingTheme.whiteAlpha12
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(dashPath, dashPaint);

    canvas.drawCircle(Offset(12, size.height - 6), 6, dropoffPaint);

    if (hasDropoff) {
      final glowPaint2 = Paint()
        ..color = RideBookingTheme.red.withValues(alpha: 0.2)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(12, size.height - 6), 10, glowPaint2);
    }
  }

  @override
  bool shouldRepaint(covariant _RouteLinePainter oldDelegate) =>
      oldDelegate.hasPickup != hasPickup || oldDelegate.hasDropoff != hasDropoff;
}

class _LocationField extends StatelessWidget {
  const _LocationField({
    required this.text,
    required this.hint,
    required this.hasValue,
    required this.dotColor,
    required this.onTap,
  });

  final String text;
  final String hint;
  final bool hasValue;
  final Color dotColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: hasValue
              ? RideBookingTheme.whiteAlpha08
              : RideBookingTheme.whiteAlpha08.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(RideBookingTheme.innerRadius),
          border: hasValue
              ? null
              : Border.all(
                  color: RideBookingTheme.whiteAlpha08,
                  width: 1,
                ),
        ),
        child: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: dotColor.withValues(alpha: hasValue ? 1.0 : 0.4),
                boxShadow: hasValue
                    ? [
                        BoxShadow(
                          color: dotColor.withValues(alpha: 0.5),
                          blurRadius: 8,
                        ),
                      ]
                    : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                hasValue ? text : hint,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: hasValue ? FontWeight.w500 : FontWeight.w400,
                  color: hasValue
                      ? RideBookingTheme.whiteAlpha80
                      : RideBookingTheme.whiteAlpha40,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (!hasValue)
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 12,
                color: RideBookingTheme.whiteAlpha24,
              ),
            if (hasValue)
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: RideBookingTheme.whiteAlpha24,
              ),
          ],
        ),
      ),
    );
  }
}
