import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:delwaqty/features/location/presentation/providers/location_provider.dart';
import 'package:delwaqty/features/ride_booking/ride_booking_theme.dart';
import 'package:delwaqty/features/ride_booking/ride_booking_animations.dart';

class LocationHeaderCard extends ConsumerWidget {
  const LocationHeaderCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final locationAsync = ref.watch(userLocationProvider);

    final address = locationAsync.when(
      data: (loc) => loc?.detailedAddress.isNotEmpty == true
          ? loc!.detailedAddress
          : l10n.locationUnavailable,
      loading: () => l10n.searchingForLocation,
      error: (_, __) => l10n.locationUnavailable,
    );

    final city = locationAsync.when(
      data: (loc) {
        if (loc?.detailedAddress.isNotEmpty == true) {
          final parts = loc!.detailedAddress.split(',');
          return parts.length > 1 ? parts.last.trim() : '';
        }
        return '';
      },
      loading: () => '',
      error: (_, __) => '',
    );

    final isLoading = locationAsync is AsyncLoading;
    final hasLocation = locationAsync.valueOrNull != null;

    return RideBookingCard(
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(RideBookingTheme.cardRadius),
        child: Stack(
          children: [
            Positioned(
              right: -40,
              top: -40,
              child: Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      RideBookingTheme.primaryPurple.withValues(alpha: 0.12),
                      RideBookingTheme.primaryPurple.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: -20,
              bottom: -30,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: RideBookingTheme.green.withValues(alpha: 0.04),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  GlowWidget(
                    color: hasLocation
                        ? RideBookingTheme.green
                        : RideBookingTheme.primaryPurple,
                    radius: 20,
                    opacity: 0.2,
                    child: PulseAnimation(
                      color: hasLocation
                          ? RideBookingTheme.green
                          : RideBookingTheme.primaryPurple,
                      size: 52,
                      child: Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: hasLocation
                                ? [
                                    RideBookingTheme.green,
                                    const Color(0xFF28A745),
                                  ]
                                : [
                                    RideBookingTheme.primaryPurple,
                                    const Color(0xFF7C3AED),
                                  ],
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: (hasLocation
                                      ? RideBookingTheme.green
                                      : RideBookingTheme.primaryPurple)
                                  .withValues(alpha: 0.4),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.location_on_rounded,
                          color: Colors.white,
                          size: 26,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.currentLocation,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: RideBookingTheme.whiteAlpha40,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 5),
                        isLoading
                            ? SizedBox(
                                height: 20,
                                width: 160,
                                child: LinearProgressIndicator(
                                  backgroundColor:
                                      RideBookingTheme.whiteAlpha08,
                                  color: RideBookingTheme.primaryPurple
                                      .withValues(alpha: 0.5),
                                  minHeight: 2,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              )
                            : Text(
                                address,
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                  color: RideBookingTheme.whiteAlpha80,
                                  height: 1.3,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                        if (city.isNotEmpty && !isLoading) ...[
                          const SizedBox(height: 3),
                          Text(
                            city,
                            style: TextStyle(
                              fontSize: 13,
                              color: RideBookingTheme.whiteAlpha40,
                              letterSpacing: 0.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  SlowPulseAnimation(
                    color: hasLocation
                        ? RideBookingTheme.green
                        : RideBookingTheme.whiteAlpha24,
                    size: 44,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: hasLocation
                            ? RideBookingTheme.green.withValues(alpha: 0.12)
                            : RideBookingTheme.whiteAlpha08,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: hasLocation
                              ? RideBookingTheme.green.withValues(alpha: 0.2)
                              : RideBookingTheme.whiteAlpha08,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: hasLocation
                                  ? RideBookingTheme.green
                                  : RideBookingTheme.whiteAlpha40,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            hasLocation ? 'GPS' : '---',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: hasLocation
                                  ? RideBookingTheme.green
                                  : RideBookingTheme.whiteAlpha40,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
