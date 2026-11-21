import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart' as geolocator;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:delwaqty/features/_shared/auth/presentation/auth_provider.dart';
import 'package:delwaqty/features/_shared/auth/domain/auth_state.dart';
import 'package:delwaqty/features/driver/driver_module.dart';
import 'package:delwaqty/features/driver/domain/entities/driver_profile.dart';
import 'package:delwaqty/features/driver/domain/entities/vehicle.dart';
import 'package:delwaqty/features/driver/domain/entities/driver_performance.dart';
import 'package:delwaqty/shared/widgets/animated_fade_in.dart';
import 'package:delwaqty/shared/widgets/floating_glass_buttons.dart';
import 'package:delwaqty/shared/widgets/shimmer_loading.dart';
import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:delwaqty/core/errors/app_error_text.dart';
import 'package:delwaqty/core/theme/app_text_styles.dart';
import 'package:delwaqty/features/customer/driver/presentation/providers/dispatch_providers.dart';
import 'package:delwaqty/core/auth/platform_capabilities.dart';

final _performanceProvider = FutureProvider.family<DriverPerformance, String>((
  ref,
  driverId,
) async {
  final repo = ref.watch(driverRepositoryProvider);
  return repo.getPerformance(driverId);
});

class DriverDashboardPage extends ConsumerWidget {
  const DriverDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final authState = ref.watch(authStateProvider);
    // Resolves Owner operational contexts + triggers idempotent provisioning
    // so the same Owner identity works across all four apps.
    ref.watch(platformCapabilitiesProvider);

    final userId = authState is AuthAuthenticated ? authState.user.id : null;
    if (userId == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.driverDashboard)),
        body: Center(child: Text(l10n.pleaseLogIn)),
      );
    }

    final profileAsync = ref.watch(driverProfileProvider(userId));

    return Scaffold(
      appBar: AppBar(
        leadingWidth: 56,
        leading: const Padding(
          padding: EdgeInsetsDirectional.only(start: 12),
          child: Center(child: FloatingMenuCircleButton(size: 40)),
        ),
        title: Text(l10n.driverDashboard),
        actions: [
          const Center(
            child: Padding(
              padding: EdgeInsetsDirectional.only(end: 6),
              child: FloatingNotificationCircleButton(size: 40),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: l10n.settings,
            onPressed: () => context.push('/settings/privacy-security'),
          ),
          IconButton(
            icon: const Icon(Icons.support_agent_rounded),
            tooltip: l10n.support,
            onPressed: () => context.push('/support'),
          ),
          IconButton(
            icon: const Icon(Icons.shield_outlined),
            tooltip: l10n.deliveryAccess,
            onPressed: () => context.push('/driver/access'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(driverProfileProvider(userId));
        },
        child: profileAsync.when(
          data: (profile) {
            if (profile == null) {
              return _RegistrationPrompt(userId: userId);
            }
            if (!profile.onboardingCompleted &&
                profile.verificationStatus != 'verified') {
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
          error: (e, _) => Center(child: Text(appErrorText(context, e))),
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
              color: Theme.of(context).colorScheme.primary
                  .withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.onboardingTitle,
              style: Theme.of(context).textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.registrationPendingApproval,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
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
    BuildContext context,
    WidgetRef ref,
    DriverProfile profile,
  ) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final performanceAsync = ref.watch(_performanceProvider(profile.id));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        performanceAsync.when(
          loading: () => const SizedBox.shrink(),
          error: (e, _) => const SizedBox.shrink(),
          data: (perf) => Column(
            children: [
              AnimatedFadeIn(child: _TodayEarningsHero(performance: perf)),
              const SizedBox(height: 16),
            ],
          ),
        ),
        AnimatedFadeIn(
          delay: const Duration(milliseconds: 50),
          child: _OnlineHeader(profile: profile),
        ),
        const SizedBox(height: 16),
        performanceAsync.when(
          loading: () => const SizedBox.shrink(),
          error: (e, _) => const SizedBox.shrink(),
          data: (perf) => Column(
            children: [
              AnimatedFadeIn(
                delay: const Duration(milliseconds: 100),
                child: _EarningsOverviewCard(performance: perf),
              ),
              const SizedBox(height: 12),
              AnimatedFadeIn(
                delay: const Duration(milliseconds: 150),
                child: _PerformanceGrid(
                  performance: perf,
                  rating: profile.rating,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        AnimatedFadeIn(
          delay: const Duration(milliseconds: 200),
          child: _ActionGrid(profile: profile),
        ),
        const SizedBox(height: 16),
        AnimatedFadeIn(
          delay: const Duration(milliseconds: 250),
          child: Text(
            l10n.vehicleInfo,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 8),
        AnimatedFadeIn(
          delay: const Duration(milliseconds: 300),
          child: _VehicleInfoCard(profile: profile),
        ),
      ],
    );
  }
}

class _RegistrationPrompt extends ConsumerStatefulWidget {
  const _RegistrationPrompt({required this.userId});
  final String userId;

  @override
  ConsumerState<_RegistrationPrompt> createState() =>
      _RegistrationPromptState();
}

class _RegistrationPromptState extends ConsumerState<_RegistrationPrompt> {
  bool _registering = false;

  Future<void> _register() async {
    if (_registering) return;
    setState(() => _registering = true);
    try {
      final repo = ref.read(driverRepositoryProvider);
      await repo.registerProfile(
        widget.userId,
        fullName: ref
            .read(authStateProvider)
            .maybeWhen(
              authenticated: (u) => u.fullName?.trim().isNotEmpty == true
                  ? u.fullName!
                  : 'Driver',
              orElse: () => 'Driver',
            ),
        vehicleType: 'motorcycle',
      );
      ref.invalidate(driverProfileProvider(widget.userId));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(appErrorText(context, e))));
      }
    } finally {
      if (mounted) setState(() => _registering = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
              color: Theme.of(context).colorScheme.primary
                  .withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.becomeADriver,
              style: Theme.of(context).textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
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
              onPressed: _registering ? null : _register,
              icon: _registering
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.app_registration_rounded),
              label: Text(l10n.registerNow),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnlineHeader extends ConsumerWidget {
  const _OnlineHeader({required this.profile});
  final DriverProfile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final onlineState = ref.watch(driverOnlineProvider(profile.id));
    final isOnline = onlineState.value ?? false;

    ref.listen<AsyncValue<bool>>(driverOnlineProvider(profile.id), (
      prev,
      next,
    ) {
      if (next.hasError && next.error != null) {
        // Web has no app-settings screen: the "Open Settings" action is a
        // dead end there, and the browser re-prompts on the next attempt
        // anyway, so the nag adds nothing (UI batch 15).
        if (kIsWeb) return;
        final error = next.error!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(appErrorText(context, error)),
            // Location denials get a way out: open the system app settings.
            action: classifyAppError(error) == AppErrorKind.location
                ? SnackBarAction(
                    label: l10n.openSettings,
                    onPressed: () {
                      geolocator.Geolocator.openAppSettings();
                    },
                  )
                : null,
          ),
        );
      }
    });

    // Full-width 56dp switch card (sunlight rule: primary control >= 48dp).
    return Container(
      constraints: const BoxConstraints(minHeight: 56),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary,
            theme.colorScheme.primary.withValues(alpha: 0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  isOnline ? l10n.online : l10n.offline,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  isOnline
                      ? l10n.onlineReadyForOrders
                      : l10n.offlineTapToGoOnline,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onPrimary.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: isOnline,
            activeThumbColor: theme.colorScheme.onPrimary,
            onChanged: onlineState.isLoading
                ? null
                : (value) async {
                    await ref
                        .read(driverOnlineProvider(profile.id).notifier)
                        .setOnline(value);
                    ref.invalidate(driverProfileProvider(profile.userId));
                  },
          ),
        ],
      ),
    );
  }
}

/// Today's earnings as the top hero (32sp price style).
class _TodayEarningsHero extends StatelessWidget {
  const _TodayEarningsHero({required this.performance});
  final DriverPerformance performance;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.todayEarnings,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.amountWithCurrency(
              performance.todayEarnings.toStringAsFixed(2),
              l10n.currencySymbol,
            ),
            style: AppTextStyles.price.copyWith(
              fontSize: 32,
              color: theme.colorScheme.onSurface,
            ),
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
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Labelled "Available balance" (not "Wallet"): period tiles show
          // GROSS earnings, this card shows the withdrawable remainder,
          // and identical labels read as a contradiction (UI batch 15).
          Text(
            l10n.availableBalance,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            l10n.amountWithCurrency(
              performance.balance.toStringAsFixed(2),
              l10n.currencySymbol,
            ),
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _MiniStat(
                  label: l10n.todayEarnings,
                  value: l10n.amountWithCurrency(
                    performance.todayEarnings.toStringAsFixed(0),
                    l10n.currencySymbol,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MiniStat(
                  label: l10n.weeklyEarnings,
                  value: l10n.amountWithCurrency(
                    performance.weekEarnings.toStringAsFixed(0),
                    l10n.currencySymbol,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MiniStat(
                  label: l10n.monthlyEarnings,
                  value: l10n.amountWithCurrency(
                    performance.monthEarnings.toStringAsFixed(0),
                    l10n.currencySymbol,
                  ),
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
                        l10n.currencySymbol,
                      ),
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
                        performance.incentiveBalance.toStringAsFixed(0),
                        l10n.currencySymbol,
                      ),
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
  const _PerformanceGrid({required this.performance, this.rating});
  final DriverPerformance performance;
  final double? rating;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.performance,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
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
                  value: '${performance.acceptanceRate.toStringAsFixed(0)}%',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MiniStat(
                  label: l10n.cancellationRate,
                  value: '${performance.cancellationRate.toStringAsFixed(0)}%',
                ),
              ),
              if (rating != null) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: _MiniStat(
                    label: l10n.rating,
                    value: rating!.toStringAsFixed(1),
                  ),
                ),
              ],
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
                icon: Icons.local_shipping_rounded,
                label: l10n.deliveryHub,
                onTap: () => context.push('/driver/hub'),
              ),
            ),
            const SizedBox(width: 12),
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

/// The vehicles table is the single source of truth for the driver's
/// vehicle; the dashboard card and the management page must agree.
final _activeVehicleProvider = FutureProvider.family<Vehicle?, String>((
  ref,
  driverId,
) async {
  final vehicles = await ref
      .watch(driverRepositoryProvider)
      .getVehicles(driverId);
  final active = vehicles.where((v) => v.isActive);
  return active.isEmpty ? null : active.first;
});

class _VehicleInfoCard extends ConsumerWidget {
  const _VehicleInfoCard({required this.profile});
  final DriverProfile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.two_wheeler_rounded, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Builder(
                  builder: (context) {
                    final vehicle = ref
                        .watch(_activeVehicleProvider(profile.id))
                        .value;
                    final title = vehicle != null
                        ? [
                            vehicle.category,
                            if (vehicle.make != null) vehicle.make,
                            if (vehicle.model != null) vehicle.model,
                          ].join(' ')
                        : (profile.vehicleType ?? l10n.notSet);
                    final plate = vehicle?.plateNumber ?? profile.vehiclePlate;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (plate != null)
                          Text(
                            plate,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    );
                  },
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
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
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
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
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
            color: Theme.of(context).colorScheme.onPrimary
                .withValues(alpha: 0.8),
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
        Text(
          value,
          style: Theme.of(context).textTheme.titleSmall
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}
