import 'dart:async';

import 'package:flutter/material.dart';
import 'package:delwaqty/core/theme/app_colors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:delwaqty/features/_shared/auth/presentation/auth_provider.dart';
import 'package:delwaqty/features/_shared/auth/domain/auth_state.dart';
import 'package:delwaqty/features/customer/driver/driver_module.dart';
import 'package:delwaqty/features/customer/driver/domain/entities/driver_profile.dart';
import 'package:delwaqty/features/customer/driver/domain/entities/ride_offer.dart';
import 'package:delwaqty/features/customer/driver/presentation/providers/dispatch_providers.dart';
import 'package:delwaqty/features/customer/driver/presentation/widgets/ride_offer_sheet.dart';
import 'package:delwaqty/features/customer/driver/presentation/widgets/register_ride_driver_sheet.dart';
import 'package:delwaqty/features/customer/ride/domain/entities/ride.dart';
import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:delwaqty/shared/widgets/premium_empty_state.dart';
import 'package:delwaqty/shared/widgets/app_loader.dart';

class DriverRideHubPage extends ConsumerWidget {
  const DriverRideHubPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final authState = ref.watch(authStateProvider);
    final userId = authState is AuthAuthenticated ? authState.user.id : null;

    if (userId == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.driverRides)),
        body: Center(child: Text(l10n.pleaseLogIn)),
      );
    }

    final profileAsync = ref.watch(driverProfileProvider(userId));

    return Scaffold(
      appBar: AppBar(title: Text(l10n.driverRides)),
      body: profileAsync.when(
        loading: () => const SkeletonListTile(),
        error: (e, _) => Center(child: Text(l10n.errorWithMessage(e.toString()))),
        data: (profile) {
          if (profile == null || profile.vehicleType == null) {
            return PremiumEmptyState(
              icon: Icons.local_taxi_rounded,
              title: l10n.becomeADriver,
              message: l10n.joinFleetSubtitle,
              actionLabel: l10n.registerAsRideDriver,
              onAction: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                builder: (_) => RegisterRideDriverSheet(userId: userId),
              ),
            );
          }
          return _DriverRideBody(profile: profile);
        },
      ),
    );
  }
}

class _DriverRideBody extends ConsumerStatefulWidget {
  const _DriverRideBody({required this.profile});
  final DriverProfile profile;

  @override
  ConsumerState<_DriverRideBody> createState() => _DriverRideBodyState();
}

class _DriverRideBodyState extends ConsumerState<_DriverRideBody> {
  bool _offerShowing = false;

  String get _driverId => widget.profile.id;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final onlineState = ref.watch(driverOnlineProvider(_driverId));
    final online = onlineState.valueOrNull ?? false;

    ref.listen<AsyncValue<Ride?>>(activeDriverRideProvider(_driverId),
        (prev, next) {
      final ride = next.valueOrNull;
      if (ride != null && ride.status.isActive) {
        context.push('/driver/trip/${ride.id}');
      }
    });

    if (online) {
      ref.listen<AsyncValue<List<RideOffer>>>(rideOffersProvider(_driverId),
          (prev, next) {
        final offers = next.valueOrNull ?? const [];
        if (offers.isNotEmpty && !_offerShowing) {
          _presentOffer(offers.first);
        }
      });
    }

    final statsAsync = ref.watch(driverStatsProvider(_driverId));

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(driverStatsProvider(_driverId));
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _OnlineCard(
            online: online,
            loading: onlineState.isLoading,
            onToggle: () =>
                ref.read(driverOnlineProvider(_driverId).notifier).toggle(),
          ),
          const SizedBox(height: 16),
          statsAsync.when(
            loading: () => const Center(
                child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator())),
            error: (e, _) => const SizedBox.shrink(),
            data: (stats) => Column(
              children: [
                Row(
                  children: [
                    Expanded(
                        child: _MiniStat(
                            label: l10n.todayRides,
                            value: '${stats.todayRides}')),
                    const SizedBox(width: 12),
                    Expanded(
                        child: _MiniStat(
                            label: l10n.todayEarnings,
                            value: l10n.amountWithCurrency(
                                stats.todayEarnings.toStringAsFixed(0),
                                l10n.currencySymbol))),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                        child: _MiniStat(
                            label: l10n.rating,
                            value: stats.rating.toStringAsFixed(1))),
                    const SizedBox(width: 12),
                    Expanded(
                        child: _MiniStat(
                            label: l10n.acceptanceRate,
                            value: '${stats.acceptanceRate.toStringAsFixed(0)}%')),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: () => context.push('/driver/earnings'),
            icon: const Icon(Icons.account_balance_wallet_outlined),
            label: Text(l10n.wallet),
          ),
          const SizedBox(height: 32),
          Center(
            child: Column(
              children: [
                Icon(
                  online ? Icons.wifi_tethering_rounded : Icons.cloud_off_rounded,
                  size: 48,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurfaceVariant
                      .withValues(alpha: 0.5),
                ),
                const SizedBox(height: 12),
                Text(
                  online ? l10n.waitingForRides : l10n.goOnlineToReceive,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _presentOffer(RideOffer offer) async {
    _offerShowing = true;
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    final accepted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      builder: (_) => RideOfferSheet(offer: offer),
    );
    _offerShowing = false;
    if (!mounted) return;
    if (accepted == true) {
      try {
        await ref
            .read(dispatchRepositoryProvider)
            .acceptOffer(offer.rideId, offer.driverId);
        if (mounted) context.push('/driver/trip/${offer.rideId}');
      } catch (e) {
        messenger.showSnackBar(
          SnackBar(content: Text(_mapError(l10n, e))),
        );
      }
    } else if (accepted == false) {
      try {
        await ref
            .read(dispatchRepositoryProvider)
            .rejectOffer(offer.rideId, offer.driverId);
      } catch (e) {
        debugPrint('Failed to reject ride offer: $e');
      }
    }
  }

  String _mapError(AppLocalizations l10n, Object e) {
    final s = e.toString();
    if (s.contains('ride_unavailable') || s.contains('offer_expired')) {
      return l10n.rideNoLongerAvailable;
    }
    if (s.contains('driver_busy')) return l10n.driverBusy;
    return l10n.somethingWentWrong;
  }
}

class _OnlineCard extends StatelessWidget {
  const _OnlineCard({
    required this.online,
    required this.loading,
    required this.onToggle,
  });

  final bool online;
  final bool loading;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: online
              ? [AppColors.successLight, AppColors.successDark]
              : [theme.colorScheme.surfaceContainerHighest, theme.colorScheme.surfaceContainerHigh],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            online ? l10n.online : l10n.offline,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: online ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface,
            ),
          ),
          loading
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : Switch(
                  value: online,
                  onChanged: (_) => onToggle(),
                ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value,
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(label,
              style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}
