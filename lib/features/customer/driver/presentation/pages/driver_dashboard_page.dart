import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:delwaqty/features/_shared/auth/presentation/auth_provider.dart';
import 'package:delwaqty/features/_shared/auth/domain/auth_state.dart';
import 'package:delwaqty/features/customer/driver/driver_module.dart';
import 'package:delwaqty/features/customer/driver/domain/entities/driver_profile.dart';
import 'package:delwaqty/features/customer/driver/domain/entities/driver_performance.dart';
import 'package:delwaqty/shared/widgets/animated_fade_in.dart';
import 'package:delwaqty/shared/widgets/shimmer_loading.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

final _performanceProvider =
    FutureProvider.family<DriverPerformance, String>((ref, driverId) async {
  final repo = ref.watch(driverRepositoryProvider);
  return repo.getPerformance(driverId);
});

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
        onRefresh: () async {
          ref.invalidate(driverProfileProvider(userId));
        },
        child: profileAsync.when(
          data: (profile) {
            if (profile == null) {
              return _buildRegistrationPrompt(context, ref, userId);
            }
            if (!profile.onboardingCompleted &&
                profile.verificationStatus == 'pending' &&
                profile.vehicleType == null) {
              return _buildOnboardingPrompt(context, profile.id);
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
          error: (e, _) => Center(
              child: Text(l10n.errorWithMessage(e.toString()))),
        ),
      ),
    );
  }

  Widget _buildRegistrationPrompt(
      BuildContext context, WidgetRef ref, String userId) {
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
              color: Theme.of(context)
                  .colorScheme
                  .primary
                  .withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.becomeADriver,
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.joinFleetSubtitle,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color:
                        Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () async {
                final repo = ref.read(driverRepositoryProvider);
                await repo.registerProfile(userId,
                    vehicleType: 'motorcycle');
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

  Widget _buildOnboardingPrompt(BuildContext context, String driverId) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.app_registration_rounded,
              size: 80,
              color: Theme.of(context)
                  .colorScheme
                  .primary
                  .withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.onboardingTitle,
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.registrationPendingApproval,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color:
                        Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => context.push('/driver/onboarding/$driverId'),
              icon: const Icon(Icons.arrow_forward_rounded),
              label: Text(l10n.next),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboard(
      BuildContext context, WidgetRef ref, DriverProfile profile) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final performanceAsync = ref.watch(_performanceProvider(profile.id));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        AnimatedFadeIn(
          child: _OnlineHeader(profile: profile, ref: ref),
        ),
        const SizedBox(height: 16),
        performanceAsync.when(
          loading: () => const SizedBox.shrink(),
          error: (e, _) => const SizedBox.shrink(),
          data: (perf) => Column(
            children: [
              AnimatedFadeIn(
                delay: const Duration(milliseconds: 50),
                child: _EarningsOverviewCard(performance: perf),
              ),
              const SizedBox(height: 12),
              AnimatedFadeIn(
                delay: const Duration(milliseconds: 100),
                child: _PerformanceGrid(performance: perf),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        AnimatedFadeIn(
          delay: const Duration(milliseconds: 150),
          child: _ActionGrid(profile: profile),
        ),
        const SizedBox(height: 16),
        AnimatedFadeIn(
          delay: const Duration(milliseconds: 200),
          child: Text(
            l10n.vehicleInfo,
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 8),
        AnimatedFadeIn(
          delay: const Duration(milliseconds: 250),
          child: _VehicleInfoCard(profile: profile),
        ),
      ],
    );
  }
}

class _OnlineHeader extends StatelessWidget {
  const _OnlineHeader({required this.profile, required this.ref});
  final DriverProfile profile;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Container(
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
                profile.status == DriverStatus.online
                    ? l10n.online
                    : l10n.offline,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onPrimary.withValues(alpha: 0.8),
                ),
              ),
              Switch(
                value: profile.status == DriverStatus.online,
                activeColor: theme.colorScheme.onPrimary,
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
              _StatItem(
                  label: l10n.totalDeliveries,
                  value: '${profile.totalDeliveries}'),
              _StatItem(
                  label: l10n.earnings,
                  value: l10n.amountWithCurrency(
                      profile.totalEarnings.toStringAsFixed(0),
                      l10n.currencySymbol)),
              _StatItem(
                  label: l10n.rating,
                  value: profile.rating.toStringAsFixed(1)),
            ],
          ),
        ],
      ),
    );
  }
}

class _EarningsOverviewCard extends StatelessWidget {
  const _EarningsOverviewCard({required this.performance});
  final DriverPerformance performance;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest
            .withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.wallet,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Text(
            l10n.amountWithCurrency(
                performance.balance.toStringAsFixed(2),
                l10n.currencySymbol),
            style: theme.textTheme.headlineMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _MiniStat(
                  label: l10n.todayEarnings,
                  value: l10n.amountWithCurrency(
                      performance.todayEarnings.toStringAsFixed(0),
                      l10n.currencySymbol),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MiniStat(
                  label: l10n.weeklyEarnings,
                  value: l10n.amountWithCurrency(
                      performance.weekEarnings.toStringAsFixed(0),
                      l10n.currencySymbol),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MiniStat(
                  label: l10n.monthlyEarnings,
                  value: l10n.amountWithCurrency(
                      performance.monthEarnings.toStringAsFixed(0),
                      l10n.currencySymbol),
                ),
              ),
            ],
          ),
          if (performance.bonusBalance > 0 ||
              performance.incentiveBalance > 0) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                if (performance.bonusBalance > 0)
                  Expanded(
                    child: _MiniStat(
                      label: l10n.bonusBalance,
                      value: l10n.amountWithCurrency(
                          performance.bonusBalance.toStringAsFixed(0),
                          l10n.currencySymbol),
                    ),
                  ),
                if (performance.bonusBalance > 0 &&
                    performance.incentiveBalance > 0)
                  const SizedBox(width: 8),
                if (performance.incentiveBalance > 0)
                  Expanded(
                    child: _MiniStat(
                      label: l10n.incentiveBalance,
                      value: l10n.amountWithCurrency(
                          performance.incentiveBalance
                              .toStringAsFixed(0),
                          l10n.currencySymbol),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _PerformanceGrid extends StatelessWidget {
  const _PerformanceGrid({required this.performance});
  final DriverPerformance performance;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest
            .withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.performance,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _MiniStat(
                  label: l10n.completedTrips,
                  value: '${performance.completedTrips}',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MiniStat(
                  label: l10n.acceptanceRate,
                  value:
                      '${performance.acceptanceRate.toStringAsFixed(0)}%',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MiniStat(
                  label: l10n.cancellationRate,
                  value:
                      '${performance.cancellationRate.toStringAsFixed(0)}%',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionGrid extends StatelessWidget {
  const _ActionGrid({required this.profile});
  final DriverProfile profile;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _ActionCard(
                icon: Icons.account_balance_wallet_rounded,
                label: l10n.wallet,
                onTap: () => context.push('/driver/earnings'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _ActionCard(
                icon: Icons.directions_car_rounded,
                label: l10n.vehicleManagement,
                onTap: () => context.push('/driver/vehicles'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ActionCard(
                icon: Icons.description_rounded,
                label: l10n.documentManagement,
                onTap: () => context.push('/driver/documents'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _VehicleInfoCard extends StatelessWidget {
  const _VehicleInfoCard({required this.profile});
  final DriverProfile profile;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest
            .withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.two_wheeler_rounded,
              color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.vehicleType ?? l10n.notSet,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
                if (profile.vehiclePlate != null)
                  Text(
                    profile.vehiclePlate!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerHighest
          .withValues(alpha: 0.3),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            children: [
              Icon(icon, color: theme.colorScheme.primary, size: 28),
              const SizedBox(height: 8),
              Text(
                label,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
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
                color: Theme.of(context).colorScheme.onPrimary,
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.8),
              ),
        ),
      ],
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value,
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color:
                      Theme.of(context).colorScheme.onSurfaceVariant,
                )),
      ],
    );
  }
}
