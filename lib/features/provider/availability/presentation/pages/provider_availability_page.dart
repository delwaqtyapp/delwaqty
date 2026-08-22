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
      appBar: AppBar(title: Text(l10n.availability)),
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
                                isOpen ? l10n.open : l10n.closed,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              Text(
                                isOpen
                                    ? l10n.customersCanPlaceOrders
                                    : l10n.temporarilyUnavailable,
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
                      title: Text(l10n.storeOpenForBusiness),
                      subtitle: Text(l10n.availabilityHint),
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
                    l10n.weeklySchedule,
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
                        title: l10n.noScheduleSet,
                        message: l10n.configureWorkingHours,
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
                                         ? l10n.closed
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
    final l10n = AppLocalizations.of(context);
    const days = [
      'sunday',
      'monday',
      'tuesday',
      'wednesday',
      'thursday',
      'friday',
      'saturday',
    ];
    final name = days[day.clamp(0, 6)];
    switch (name) {
      case 'sunday':
        return l10n.sunday;
      case 'monday':
        return l10n.monday;
      case 'tuesday':
        return l10n.tuesday;
      case 'wednesday':
        return l10n.wednesday;
      case 'thursday':
        return l10n.thursday;
      case 'friday':
        return l10n.friday;
      case 'saturday':
        return l10n.saturday;
      default:
        return name;
    }
  }
}
