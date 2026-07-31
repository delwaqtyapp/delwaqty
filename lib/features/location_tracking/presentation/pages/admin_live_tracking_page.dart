import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delwaqty/features/location_tracking/presentation/location_providers.dart';
import 'package:delwaqty/shared/widgets/glass_card.dart';
import 'package:delwaqty/shared/widgets/app_loader.dart';
import 'package:delwaqty/shared/widgets/animated_fade_in.dart';
import 'package:delwaqty/shared/widgets/premium_empty_state.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

class AdminLiveTrackingPage extends ConsumerStatefulWidget {
  const AdminLiveTrackingPage({super.key});

  @override
  ConsumerState<AdminLiveTrackingPage> createState() => _AdminLiveTrackingPageState();
}

class _AdminLiveTrackingPageState extends ConsumerState<AdminLiveTrackingPage> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final driversAsync = ref.watch(activeDriversLocationProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.liveTracking),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.invalidate(activeDriversLocationProvider),
          ),
        ],
      ),
      body: driversAsync.when(
        loading: () => const Center(child: AppLoaderCircular()),
        error: (e, _) => PremiumEmptyState(
          icon: Icons.error_outline,
          title: l10n.error,
          message: e.toString(),
        ),
        data: (drivers) {
          if (drivers.isEmpty) {
            return PremiumEmptyState(
              icon: Icons.map_outlined,
              title: l10n.noActiveDrivers,
              message: l10n.noActiveDriversDescription,
            );
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: GlassCard(
                  borderRadius: 16,
                  child: SizedBox(
                    height: 300,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.map_rounded, size: 64, color: cs.primary.withValues(alpha: 0.4)),
                          const SizedBox(height: 12),
                          Text(l10n.mapView, style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 4),
                          Text(
                            '${drivers.length} ${l10n.activeDrivers}',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '${l10n.mapApiKeyRequired} (Google Maps / Mapbox)',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: cs.error,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  l10n.activeDriversList,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                  itemCount: drivers.length,
                  itemBuilder: (context, index) {
                    final d = drivers[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: AnimatedFadeIn(
                        child: GlassCard(
                          borderRadius: 16,
                          child: ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: cs.primary.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.local_shipping_rounded),
                            ),
                            title: Text(d.userId.substring(0, 8), maxLines: 1),
                            subtitle: Text(
                              '${d.latitude.toStringAsFixed(4)}, ${d.longitude.toStringAsFixed(4)}',
                            ),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                if (d.speed != null)
                                  Text('${d.speed!.toStringAsFixed(1)} km/h',
                                      style: Theme.of(context).textTheme.bodySmall),
                                if (d.heading != null)
                                  Text('${d.heading!.toStringAsFixed(0)}°',
                                      style: Theme.of(context).textTheme.bodySmall),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
