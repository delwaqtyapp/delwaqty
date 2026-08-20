import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:delwaqty/features/customer/delivery/presentation/providers/delivery_providers.dart';
import 'package:delwaqty/features/customer/delivery/domain/entities/delivery_order.dart';
import 'package:delwaqty/features/customer/ride/presentation/providers/ride_providers.dart';
import 'package:delwaqty/features/customer/ride/presentation/widgets/ride_map.dart';
import 'package:delwaqty/features/customer/ride/domain/entities/ride.dart';
import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:delwaqty/shared/widgets/animated_fade_in.dart';
import 'package:delwaqty/shared/widgets/shimmer_loading.dart';
import 'package:delwaqty/core/theme/app_colors.dart';

class DeliveryTrackingPage extends ConsumerStatefulWidget {
  const DeliveryTrackingPage({required this.deliveryId, super.key});
  final String deliveryId;

  @override
  ConsumerState<DeliveryTrackingPage> createState() =>
      _DeliveryTrackingPageState();
}

class _DeliveryTrackingPageState extends ConsumerState<DeliveryTrackingPage> {
  int _rating = 0;
  final _commentController = TextEditingController();

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final rideAsync = ref.watch(rideStreamProvider(widget.deliveryId));

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.orderTracking),
        actions: [
          ...rideAsync.when(
            loading: () => <Widget>[],
            error: (_, __) => <Widget>[],
            data: (ride) {
              if (!ride.status.isTerminal) {
                return [
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => _showCancelDialog(context, ref, ride),
                  ),
                ];
              }
              return <Widget>[];
            },
          ),
        ],
      ),
      body: rideAsync.when(
        loading: () => ListView(
          padding: const EdgeInsets.all(16),
          children: const [
            ShimmerCard(height: 300),
            SizedBox(height: 12),
            ShimmerCard(height: 120),
            SizedBox(height: 12),
            ShimmerCard(height: 160),
          ],
        ),
        error: (e, _) => Center(child: Text(l10n.errorWithMessage(e.toString()))),
        data: (ride) => _TrackingBody(ride: ride, deliveryId: widget.deliveryId),
      ),
      bottomNavigationBar: rideAsync.valueOrNull != null &&
              rideAsync.valueOrNull!.status == RideStatus.completed
          ? _RatingBar(
              rating: _rating,
              onRatingChanged: (r) => setState(() => _rating = r),
              controller: _commentController,
              onSubmit: () => _submitRating(context, ref),
            )
          : null,
    );
  }

  void _showCancelDialog(BuildContext context, WidgetRef ref, Ride ride) {
    final l10n = AppLocalizations.of(context);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.cancel),
        content: Text(l10n.confirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l10n.no),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              try {
                await ref
                    .read(deliveryRepositoryProvider)
                    .cancelDelivery(ride.id);
                if (mounted) context.pop();
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text(l10n.errorWithMessage(e.toString()))),
                  );
                }
              }
            },
            child: Text(l10n.yes),
          ),
        ],
      ),
    );
  }

  Future<void> _submitRating(BuildContext context, WidgetRef ref) async {
    if (_rating == 0) return;
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    try {
      await ref.read(deliveryRepositoryProvider).rateDelivery(
            widget.deliveryId,
            '',
            _rating,
            comment: _commentController.text.isEmpty
                ? null
                : _commentController.text,
          );
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.success)),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.errorWithMessage(e.toString()))),
      );
    }
  }
}

class _TrackingBody extends StatelessWidget {
  const _TrackingBody({required this.ride, required this.deliveryId});
  final Ride ride;
  final String deliveryId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        AnimatedFadeIn(
          child: _MapSection(ride: ride),
        ),
        const SizedBox(height: 16),
        if (ride.driverId != null)
          AnimatedFadeIn(
            delay: const Duration(milliseconds: 50),
            child: _DriverInfoCard(ride: ride),
          ),
        const SizedBox(height: 16),
        AnimatedFadeIn(
          delay: const Duration(milliseconds: 100),
          child: _StatusTimeline(status: ride.status, ride: ride),
        ),
        const SizedBox(height: 16),
        if (ride.estimatedMinutes != null)
          AnimatedFadeIn(
            delay: const Duration(milliseconds: 150),
            child: _EtaCard(estimatedMinutes: ride.estimatedMinutes!),
          ),
        const SizedBox(height: 16),
        AnimatedFadeIn(
          delay: const Duration(milliseconds: 200),
          child: _ReceiptCard(ride: ride),
        ),
      ],
    );
  }
}

class _MapSection extends StatelessWidget {
  const _MapSection({required this.ride});
  final Ride ride;

  @override
  Widget build(BuildContext context) {
    final pickup = LatLng(ride.pickupLatitude, ride.pickupLongitude);
    final dropoff = LatLng(ride.dropoffLatitude, ride.dropoffLongitude);
    final driver = ride.driverLatitude != null && ride.driverLongitude != null
        ? LatLng(ride.driverLatitude!, ride.driverLongitude!)
        : null;
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: RideMap(
        pickup: pickup,
        dropoff: dropoff,
        driver: driver,
        height: 300,
      ),
    );
  }
}

class _DriverInfoCard extends StatelessWidget {
  const _DriverInfoCard({required this.ride});
  final Ride ride;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundImage: ride.driverPhoto != null
                  ? NetworkImage(ride.driverPhoto!)
                  : null,
              child: ride.driverPhoto == null
                  ? const Icon(Icons.person_rounded)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ride.driverName ?? l10n.notSet,
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    [
                      ride.vehicleType,
                      ride.vehicleColor,
                      ride.vehiclePlate,
                    ].where((e) => e != null && e.isNotEmpty).join(' Â· '),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (ride.driverPhone != null)
              IconButton(
                icon: const Icon(Icons.phone_rounded),
                onPressed: () => launchUrl(Uri.parse('tel:${ride.driverPhone}')),
              ),
          ],
        ),
      ),
    );
  }
}

class _StatusTimeline extends StatelessWidget {
  const _StatusTimeline({required this.status, required this.ride});
  final RideStatus status;
  final Ride ride;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final steps = [
      (RideStatus.searching, l10n.waitingForAcceptance, Icons.search_rounded),
      (RideStatus.matched, l10n.waitingForPassenger, Icons.person_add_rounded),
      (RideStatus.arrived, l10n.waitingForPassenger, Icons.location_on_rounded),
      (RideStatus.inTrip, l10n.deliveryTime, Icons.delivery_dining_rounded),
      (RideStatus.completed, l10n.orderHistory, Icons.check_circle_rounded),
    ];

    final currentIndex = steps.indexWhere((s) => s.$1 == status);
    final activeIndex = currentIndex >= 0 ? currentIndex : 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.orderTracking,
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            for (int i = 0; i < steps.length; i++) ...[
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i <= activeIndex
                          ? theme.colorScheme.primary
                          : theme.colorScheme.surfaceContainerHighest,
                    ),
                    child: Icon(
                      steps[i].$3,
                      size: 16,
                      color: i <= activeIndex
                          ? theme.colorScheme.onPrimary
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      steps[i].$2,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: i <= activeIndex
                            ? theme.colorScheme.onSurface
                            : theme.colorScheme.onSurfaceVariant,
                        fontWeight:
                            i == activeIndex ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                ],
              ),
              if (i < steps.length - 1)
                Padding(
                  padding: const EdgeInsets.only(left: 15),
                  child: Container(
                    width: 2,
                    height: 20,
                    color: i < activeIndex
                        ? theme.colorScheme.primary
                        : theme.colorScheme.surfaceContainerHighest,
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _EtaCard extends StatelessWidget {
  const _EtaCard({required this.estimatedMinutes});
  final int estimatedMinutes;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.timer_outlined,
                color: theme.colorScheme.primary, size: 32),
            const SizedBox(width: 12),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.deliveryTime,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      )),
                  Text(
                    '$estimatedMinutes ${l10n.onboardingNext.toLowerCase()}',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
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

class _ReceiptCard extends StatelessWidget {
  const _ReceiptCard({required this.ride});
  final Ride ride;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.orderSummary,
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _ReceiptRow(
                label: l10n.deliveryFee,
                value: l10n.amountWithCurrency(
                    (ride.baseFare ?? 0).toStringAsFixed(2),
                    ride.currency)),
            if (ride.discountAmount > 0)
              _ReceiptRow(
                label: l10n.offers,
                value: '-${l10n.amountWithCurrency(ride.discountAmount.toStringAsFixed(2), ride.currency)}',
              ),
            const Divider(),
            _ReceiptRow(
              label: l10n.subtotal,
              value: l10n.amountWithCurrency(
                  (ride.fare ?? 0).toStringAsFixed(2), ride.currency),
              bold: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _ReceiptRow extends StatelessWidget {
  const _ReceiptRow({required this.label, required this.value, this.bold = false});
  final String label;
  final String value;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: bold ? FontWeight.bold : FontWeight.normal,
                ),
                overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(value,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: bold ? FontWeight.bold : FontWeight.normal,
                ),
                overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}

class _RatingBar extends StatelessWidget {
  const _RatingBar({
    required this.rating,
    required this.onRatingChanged,
    required this.controller,
    required this.onSubmit,
  });

  final int rating;
  final ValueChanged<int> onRatingChanged;
  final TextEditingController controller;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (i) {
                final star = i + 1;
                return IconButton(
                  icon: Icon(
                    star <= rating
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    color: star <= rating ? AppColors.rating : null,
                    size: 36,
                  ),
                  onPressed: () => onRatingChanged(star),
                );
              }),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: controller,
              decoration: InputDecoration(
                hintText: l10n.trackingUpdatesHint,
                border: const OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: rating > 0 ? onSubmit : null,
                child: Text(l10n.submit),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
