import 'package:flutter/material.dart';
import 'package:delwaqty/core/theme/app_colors.dart';
import 'package:delwaqty/core/theme/app_text_styles.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:delwaqty/features/auth/presentation/auth_provider.dart';
import 'package:delwaqty/features/auth/domain/auth_state.dart';
import 'package:delwaqty/features/driver/driver_module.dart';
import 'package:delwaqty/features/driver/presentation/providers/dispatch_providers.dart';
import 'package:delwaqty/features/ride/domain/entities/ride.dart';
import 'package:delwaqty/features/ride/presentation/providers/ride_providers.dart';
import 'package:delwaqty/features/ride/presentation/widgets/ride_map.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

class DriverTripPage extends ConsumerWidget {
  const DriverTripPage({required this.rideId, super.key});
  final String rideId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final rideAsync = ref.watch(rideStreamProvider(rideId));
    final authState = ref.watch(authStateProvider);
    final userId = authState is AuthAuthenticated ? authState.user.id : null;
    final profileAsync =
        userId == null ? null : ref.watch(driverProfileProvider(userId));

    return Scaffold(
      appBar: AppBar(title: Text(l10n.activeTrip)),
      body: rideAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) =>
            Center(child: Text(l10n.somethingWentWrong)),
        data: (ride) {
          final driverId = profileAsync?.valueOrNull?.id;
          if (driverId == null) {
            return const Center(child: CircularProgressIndicator());
          }
          if (ride.status == RideStatus.completed) {
            return _CompletedView(ride: ride, driverId: driverId);
          }
          if (ride.status == RideStatus.cancelled) {
            return _CancelledView();
          }
          return _ActiveTripView(ride: ride, driverId: driverId);
        },
      ),
    );
  }
}

class _ActiveTripView extends ConsumerStatefulWidget {
  const _ActiveTripView({required this.ride, required this.driverId});
  final Ride ride;
  final String driverId;

  @override
  ConsumerState<_ActiveTripView> createState() => _ActiveTripViewState();
}

class _ActiveTripViewState extends ConsumerState<_ActiveTripView> {
  final _otpController = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  Ride get ride => widget.ride;

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    try {
      await action();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(_mapError(l10n, e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _mapError(AppLocalizations l10n, Object e) {
    final s = e.toString();
    if (s.contains('invalid_otp')) return l10n.invalidOtp;
    if (s.contains('invalid_transition')) return l10n.errorLoading;
    return l10n.somethingWentWrong;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final repo = ref.read(dispatchRepositoryProvider);

    final destination = ride.status == RideStatus.inTrip
        ? LatLng(ride.dropoffLatitude, ride.dropoffLongitude)
        : LatLng(ride.pickupLatitude, ride.pickupLongitude);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        RideMap(
          pickup: LatLng(ride.pickupLatitude, ride.pickupLongitude),
          dropoff: LatLng(ride.dropoffLatitude, ride.dropoffLongitude),
          driver: ride.driverLatitude != null && ride.driverLongitude != null
              ? LatLng(ride.driverLatitude!, ride.driverLongitude!)
              : null,
        ),
        const SizedBox(height: 16),
        _StatusBanner(status: ride.status),
        const SizedBox(height: 16),
        _AddressCard(
          icon: Icons.my_location_rounded,
          color: AppColors.successLight,
          label: l10n.pickup,
          address: ride.pickupAddress,
        ),
        const SizedBox(height: 8),
        _AddressCard(
          icon: Icons.location_on_rounded,
          color: AppColors.errorLight,
          label: l10n.destination,
          address: ride.dropoffAddress,
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Flexible(
                child: Text(l10n.estimatedEarnings),
              ),
              const SizedBox(width: 8),
              Text(
                l10n.amountWithCurrency(
                    (ride.fare ?? 0).toStringAsFixed(0), l10n.currencySymbol),
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        OutlinedButton.icon(
          onPressed: () => launchUrl(Uri.parse(
            'https://www.google.com/maps/dir/?api=1&destination=${destination.latitude},${destination.longitude}',
          )),
          icon: const Icon(Icons.navigation_rounded),
          label: Text(
            '${l10n.navigate}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(height: 12),
        if (ride.status == RideStatus.matched)
          FilledButton(
            onPressed: _busy
                ? null
                : () => _run(() =>
                    repo.arriveAtPickup(ride.id, widget.driverId)),
            style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16)),
            child: Text(l10n.confirmArrival),
          ),
        if (ride.status == RideStatus.arrived) ...[
          Text(l10n.enterOtpToStart, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 8),
          TextField(
            controller: _otpController,
            keyboardType: TextInputType.number,
            maxLength: 4,
            textAlign: TextAlign.center,
            style: AppTextStyles.headlineSmall.copyWith(letterSpacing: 8),
            decoration: const InputDecoration(border: OutlineInputBorder()),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _busy
                ? null
                : () => _run(() => repo.startTrip(
                    ride.id, widget.driverId, _otpController.text.trim())),
            style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16)),
            child: Text(l10n.startTrip),
          ),
        ],
        if (ride.status == RideStatus.inTrip)
          FilledButton(
            onPressed: _busy
                ? null
                : () => _run(
                    () => repo.completeTrip(ride.id, widget.driverId)),
            style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16)),
            child: Text(l10n.completeTrip),
          ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: _busy
              ? null
              : () => _run(() async {
                    await repo.cancelAsDriver(ride.id);
                    if (mounted) context.pop();
                  }),
          child: Text(l10n.cancelRide,
              style: AppTextStyles.bodyMedium.copyWith(color: theme.colorScheme.error)),
        ),
      ],
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.status});
  final RideStatus status;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final label = switch (status) {
      RideStatus.matched => l10n.arrivingAtPickup,
      RideStatus.arrived => l10n.confirmArrival,
      RideStatus.inTrip => l10n.inTrip,
      _ => '',
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: theme.textTheme.titleMedium
            ?.copyWith(color: theme.colorScheme.onPrimary, fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _AddressCard extends StatelessWidget {
  const _AddressCard({
    required this.icon,
    required this.color,
    required this.label,
    required this.address,
  });
  final IconData icon;
  final Color color;
  final String label;
  final String address;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant)),
                Text(address.isEmpty ? '-' : address,
                    style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CompletedView extends ConsumerStatefulWidget {
  const _CompletedView({required this.ride, required this.driverId});
  final Ride ride;
  final String driverId;

  @override
  ConsumerState<_CompletedView> createState() => _CompletedViewState();
}

class _CompletedViewState extends ConsumerState<_CompletedView> {
  int _stars = 5;
  bool _submitting = false;
  bool _done = false;

  Future<void> _submit() async {
    setState(() => _submitting = true);
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    try {
      await ref
          .read(dispatchRepositoryProvider)
          .ratePassenger(widget.ride.id, widget.driverId, _stars);
      setState(() => _done = true);
    } catch (e) {
      messenger.showSnackBar(
          SnackBar(content: Text(l10n.somethingWentWrong)));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle_rounded,
              size: 72, color: AppColors.successLight),
          const SizedBox(height: 16),
          Text(l10n.tripCompleted,
              style: theme.textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(
            '${l10n.earningsCredited}: '
            '${l10n.amountWithCurrency((widget.ride.fare ?? 0).toStringAsFixed(0), l10n.currencySymbol)}',
            style: theme.textTheme.titleMedium
                ?.copyWith(color: theme.colorScheme.primary),
          ),
          const SizedBox(height: 32),
          if (!_done) ...[
            Text(l10n.rateThePassenger, style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (i) {
                return IconButton(
                  icon: Icon(
                    i < _stars ? Icons.star_rounded : Icons.star_border_rounded,
                    color: AppColors.rating,
                    size: 36,
                  ),
                  onPressed: () => setState(() => _stars = i + 1),
                );
              }),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _submitting ? null : _submit,
              style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 48, vertical: 14)),
              child: _submitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(l10n.submitRating),
            ),
          ],
          if (_done)
            FilledButton(
              onPressed: () => context.go('/driver/rides'),
              child: Text(l10n.done),
            ),
        ],
      ),
    );
  }
}

class _CancelledView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.cancel_rounded,
              size: 72, color: Theme.of(context).colorScheme.error),
          const SizedBox(height: 16),
          Text(l10n.tripCancelled,
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () => context.go('/driver/rides'),
            child: Text(l10n.done),
          ),
        ],
      ),
    );
  }
}
