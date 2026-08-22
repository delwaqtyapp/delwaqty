import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delwaqty/features/provider/availability/presentation/providers/provider_availability_providers.dart';
import 'package:delwaqty/shared/widgets/app_loader.dart';
import 'package:delwaqty/shared/widgets/design/premium_card.dart';
import 'package:delwaqty/shared/widgets/premium_empty_state.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

class ProviderAvailabilityPage extends ConsumerStatefulWidget {
  const ProviderAvailabilityPage({super.key});

  @override
  ConsumerState<ProviderAvailabilityPage> createState() =>
      _ProviderAvailabilityPageState();
}

class _ProviderAvailabilityPageState
    extends ConsumerState<ProviderAvailabilityPage> {
  bool _saving = false;
  String? _error;

  Future<void> _toggle(bool nextOpen) async {
    if (_saving) return; // prevent double tap / race
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final repo = ref.read(providerAvailabilityRepositoryProvider);
      final res = await repo.setAvailability(nextOpen);
      if (res['ok'] != true) {
        throw Exception(res['code']?.toString() ?? 'failed');
      }
      ref.invalidate(providerAvailabilityProvider);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final availability = ref.watch(providerAvailabilityProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Availability')),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(providerAvailabilityProvider),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: availability.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: AppLoaderCircular(),
              ),
            ),
            error: (e, _) => PremiumCard(
              child: PremiumEmptyState(
                icon: Icons.error_outline_rounded,
                title: l10n.error,
                message: e.toString(),
                actionLabel: l10n.retry,
                onAction: () => ref.invalidate(providerAvailabilityProvider),
              ),
            ),
            data: (data) {
              final isOpen = data['is_open'] as bool? ?? true;
              final schedule = (data['schedule'] as List?)?.cast<Map>() ?? [];
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PremiumCard(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isOpen
                                ? const Color(0xFF34C759).withValues(alpha: 0.15)
                                : const Color(0xFFFF3B30).withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isOpen ? Icons.check_circle : Icons.cancel,
                            color: isOpen
                                ? const Color(0xFF34C759)
                                : const Color(0xFFFF3B30),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isOpen ? 'Open' : 'Closed',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              Text(
                                isOpen
                                    ? 'Customers can place orders'
                                    : 'Temporarily unavailable',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(color: cs.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  PremiumCard(
                    padding: const EdgeInsets.all(4),
                    child: SwitchListTile(
                      title: const Text('Store is open for business'),
                      subtitle: const Text(
                        'Turn off to apply a temporary closure. '
                        'Backend remains the source of truth.',
                      ),
                      value: isOpen,
                      onChanged: _saving ? null : _toggle,
                    ),
                  ),
                  if (_saving)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Center(child: AppLoaderCircular()),
                    ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: PremiumCard(
                        child: PremiumEmptyState(
                          icon: Icons.error_outline_rounded,
                          title: l10n.error,
                          message: _error!,
                          actionLabel: l10n.retry,
                          onAction: () => _toggle(!isOpen),
                        ),
                      ),
                    ),
                  const SizedBox(height: 20),
                  Text(
                    'Weekly schedule',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  if (schedule.isEmpty)
                    PremiumCard(
                      child: PremiumEmptyState(
                        icon: Icons.schedule_rounded,
                        title: 'No schedule set',
                        message:
                            'Configure working hours from the merchant settings.',
                      ),
                    )
                  else
                    PremiumCard(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          for (final row in schedule)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      _dayLabel(row['day_of_week'] as int? ?? 0),
                                      style: Theme.of(context).textTheme.bodySmall,
                                    ),
                                  ),
                                  Text(
                                    (row['is_closed'] as bool? ?? false)
                                        ? 'Closed'
                                        : '${row['open_time']} – ${row['close_time']}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  String _dayLabel(int day) {
    const days = [
      'Sunday',
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
    ];
    return days[day.clamp(0, 6)];
  }
}
