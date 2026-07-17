import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delwaqty/features/auth/presentation/auth_provider.dart';
import 'package:delwaqty/features/auth/domain/auth_state.dart';
import 'package:delwaqty/features/driver/driver_module.dart';
import 'package:delwaqty/features/driver/domain/entities/driver_profile.dart';
import 'package:delwaqty/shared/widgets/animated_fade_in.dart';
import 'package:delwaqty/shared/widgets/shimmer_loading.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

class DriverDashboardPage extends ConsumerWidget {
  const DriverDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final authState = ref.watch(authStateProvider);

    final userId = authState is AuthAuthenticated ? authState.user.id : null;
    if (userId == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.driverDashboard)),
        body: Center(child: Text(l10n.pleaseLogIn)),
      );
    }

    final profileAsync = ref.watch(driverProfileProvider(userId));

    return Scaffold(
      appBar: AppBar(title: Text(l10n.driverDashboard)),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(driverProfileProvider(userId)),
        child: profileAsync.when(
          data: (profile) {
            if (profile == null) {
              return _buildRegistrationPrompt(context, ref, userId);
            }
            return _buildDashboard(context, ref, profile);
          },
          loading: () => ListView(
            padding: const EdgeInsets.all(16),
            children: const [
              ShimmerCard(height: 100),
              SizedBox(height: 12),
              ShimmerCard(height: 100),
              SizedBox(height: 12),
              ShimmerCard(height: 100),
            ],
          ),
          error: (e, _) => Center(child: Text(l10n.errorWithMessage(e.toString()))),
        ),
      ),
    );
  }

  Widget _buildRegistrationPrompt(BuildContext context, WidgetRef ref, String userId) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.delivery_dining_rounded,
              size: 80,
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.becomeADriver,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.joinFleetSubtitle,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () async {
                final repo = ref.read(driverRepositoryProvider);
                await repo.registerProfile(userId, vehicleType: 'motorcycle');
                ref.invalidate(driverProfileProvider(userId));
              },
              icon: const Icon(Icons.app_registration_rounded),
              label: Text(l10n.registerNow),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboard(BuildContext context, WidgetRef ref, DriverProfile profile) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        AnimatedFadeIn(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  theme.colorScheme.primary,
                  theme.colorScheme.primary.withValues(alpha: 0.8),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      profile.status == DriverStatus.online ? l10n.online : l10n.offline,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                    Switch(
                      value: profile.status == DriverStatus.online,
                      activeColor: Colors.white,
                      onChanged: (value) async {
                        final repo = ref.read(driverRepositoryProvider);
                        await repo.updateStatus(
                          profile.id,
                          value ? DriverStatus.online : DriverStatus.offline,
                        );
                        ref.invalidate(driverProfileProvider(profile.userId));
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _StatItem(label: l10n.totalDeliveries, value: '${profile.totalDeliveries}'),
                    _StatItem(label: l10n.earnings, value: l10n.amountWithCurrency(profile.totalEarnings.toStringAsFixed(0), l10n.currencySymbol)),
                    _StatItem(label: l10n.rating, value: profile.rating.toStringAsFixed(1)),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        AnimatedFadeIn(
          delay: const Duration(milliseconds: 100),
          child: Text(
            l10n.vehicleInfo,
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 8),
        AnimatedFadeIn(
          delay: const Duration(milliseconds: 150),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.two_wheeler_rounded, color: theme.colorScheme.primary),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.vehicleType ?? l10n.notSet,
                      style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    if (profile.vehiclePlate != null)
                      Text(
                        profile.vehiclePlate!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        AnimatedFadeIn(
          delay: const Duration(milliseconds: 200),
          child: Text(
            l10n.availableDeliveries,
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 8),
        AnimatedFadeIn(
          delay: const Duration(milliseconds: 250),
          child: _AvailableDeliveriesList(profileId: profile.id),
        ),
      ],
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Colors.white.withValues(alpha: 0.8),
          ),
        ),
      ],
    );
  }
}

class _AvailableDeliveriesList extends ConsumerWidget {
  const _AvailableDeliveriesList({required this.profileId});

  final String profileId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final deliveriesAsync = ref.watch(availableDeliveriesProvider);

    return deliveriesAsync.when(
      data: (deliveries) {
        if (deliveries.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(24),
            alignment: Alignment.center,
            child: Text(
              l10n.noDeliveriesAvailable,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          );
        }
        return Column(
          children: deliveries.take(5).map((delivery) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.store_outlined, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(delivery.merchantName, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 2),
                          Text(
                            delivery.deliveryAddress,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    if (delivery.deliveryFee != null)
                      Text(
                        l10n.amountWithCurrency(delivery.deliveryFee!.toStringAsFixed(0), l10n.currencySymbol),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => const SizedBox.shrink(),
    );
  }
}
