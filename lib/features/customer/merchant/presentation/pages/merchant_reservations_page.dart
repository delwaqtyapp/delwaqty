import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delwaqty/core/extensions/context_extensions.dart';
import 'package:delwaqty/features/customer/merchant/merchant_module.dart';
import 'package:delwaqty/features/customer/restaurant/restaurant_module.dart';
import 'package:delwaqty/features/customer/restaurant/domain/entities/reservation.dart';
import 'package:delwaqty/shared/widgets/animated_fade_in.dart';
import 'package:delwaqty/shared/widgets/premium_empty_state.dart';
import 'package:delwaqty/shared/widgets/shimmer_loading.dart';
import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:delwaqty/core/theme/app_colors.dart';
import 'package:delwaqty/core/theme/app_spacing.dart';
import 'package:delwaqty/core/theme/app_text_styles.dart';
import 'package:delwaqty/shared/widgets/design/premium_card.dart';

final _merchantIdProvider = Provider<String>((_) => 'current-merchant-id');

final _reservationsFilterProvider = StateProvider<ReservationStatus?>(
  (ref) => null,
);

final _reservationsProvider =
    FutureProvider<List<Reservation>>((ref) async {
  final repo = ref.watch(reservationRepositoryProvider);
  final merchantId = ref.watch(_merchantIdProvider);
  final status = ref.watch(_reservationsFilterProvider);
  return repo.getReservations(merchantId, status: status);
});

class MerchantReservationsPage extends ConsumerStatefulWidget {
  const MerchantReservationsPage({super.key});

  @override
  ConsumerState<MerchantReservationsPage> createState() =>
      _MerchantReservationsPageState();
}

class _MerchantReservationsPageState
    extends ConsumerState<MerchantReservationsPage> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final reservationsAsync = ref.watch(_reservationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.reservations),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(_reservationsProvider),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilterChips(ref, l10n),
          Expanded(
            child: reservationsAsync.when(
              loading: () => ListView.builder(
                padding: const EdgeInsets.all(AppSpacing.lg),
                itemCount: 5,
                itemBuilder: (_, __) => const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: ShimmerCard(height: 120),
                ),
              ),
              error: (e, _) => Center(
                child: PremiumEmptyState(
                  icon: Icons.error_outline_rounded,
                  title: l10n.error,
                  message: l10n.errorLoading,
                  actionLabel: l10n.retry,
                  onAction: () => ref.invalidate(_reservationsProvider),
                ),
              ),
              data: (reservations) {
                if (reservations.isEmpty) {
                  return Center(
                    child: PremiumEmptyState(
                      icon: Icons.calendar_today_outlined,
                      title: l10n.noReservations,
                      message: l10n.noReservations,
                    ),
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async =>
                      ref.invalidate(_reservationsProvider),
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      0,
                      AppSpacing.lg,
                      AppSpacing.lg,
                    ),
                    itemCount: reservations.length,
                    itemBuilder: (context, index) {
                      final reservation = reservations[index];
                      return AnimatedFadeIn(
                        delay: Duration(milliseconds: index * 50),
                        child: _ReservationCard(
                          reservation: reservation,
                          onConfirm: () =>
                              _updateStatus(reservation, ReservationStatus.confirmed),
                          onCancel: () =>
                              _cancelReservation(reservation),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips(WidgetRef ref, AppLocalizations l10n) {
    final currentFilter = ref.watch(_reservationsFilterProvider);
    final filters = <MapEntry<ReservationStatus?, String?>>[
      MapEntry(null, l10n.all),
      MapEntry(ReservationStatus.pending, l10n.pending),
      MapEntry(ReservationStatus.confirmed, l10n.confirmed),
      MapEntry(ReservationStatus.seated, 'Seated'),
      MapEntry(ReservationStatus.completed, 'Completed'),
      MapEntry(ReservationStatus.cancelled, l10n.cancelled),
    ];

    return SizedBox(
      height: 56,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, index) {
          final filter = filters[index];
          final isSelected = currentFilter == filter.key;
          return FilterChip(
            label: Text(filter.value ?? ''),
            selected: isSelected,
            onSelected: (_) {
              ref.read(_reservationsFilterProvider.notifier).state =
                  filter.key;
            },
          );
        },
      ),
    );
  }

  Future<void> _updateStatus(
    Reservation reservation,
    ReservationStatus status,
  ) async {
    final repo = ref.read(reservationRepositoryProvider);
    await repo.updateReservation(reservation.id, status);
    ref.invalidate(_reservationsProvider);
    if (mounted) {
      final l10n = AppLocalizations.of(context);
      context.showAppSnackBar(
        status == ReservationStatus.confirmed
            ? l10n.reservationConfirmed
            : 'Status updated',
      );
    }
  }

  Future<void> _cancelReservation(Reservation reservation) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.cancel),
        content: Text(l10n.cancelReservationConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.no),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text(l10n.yes),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      final repo = ref.read(reservationRepositoryProvider);
      await repo.cancelReservation(reservation.id);
      ref.invalidate(_reservationsProvider);
      if (mounted) {
        context.showAppSnackBar(l10n.reservationCancelled);
      }
    }
  }
}

class _ReservationCard extends StatelessWidget {
  const _ReservationCard({
    required this.reservation,
    required this.onConfirm,
    required this.onCancel,
  });

  final Reservation reservation;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    final statusColor = switch (reservation.status) {
      ReservationStatus.pending => AppColors.warningLight,
      ReservationStatus.confirmed => AppColors.infoLight,
      ReservationStatus.seated => AppColors.brandPurple,
      ReservationStatus.completed => AppColors.successLight,
      ReservationStatus.cancelled => AppColors.errorLight,
    };

    final statusLabel = switch (reservation.status) {
      ReservationStatus.pending => l10n.pending,
      ReservationStatus.confirmed => l10n.confirmed,
      ReservationStatus.seated => 'Seated',
      ReservationStatus.completed => 'Completed',
      ReservationStatus.cancelled => l10n.cancelled,
    };

    final dateTime = reservation.reservationTime;
    final dateStr =
        '${dateTime.day.toString().padLeft(2, '0')}/${dateTime.month.toString().padLeft(2, '0')}/${dateTime.year}';
    final timeStr =
        '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: PremiumCard(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${reservation.userId}',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    statusLabel,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Icon(
                  Icons.people_outline,
                  size: 16,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Text(
                  '${reservation.partySize} guests',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: AppSpacing.lg),
                Icon(
                  Icons.calendar_today_outlined,
                  size: 16,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Text(
                  '$dateStr at $timeStr',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            if (reservation.specialRequests != null &&
                reservation.specialRequests!.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                reservation.specialRequests!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            if (reservation.status == ReservationStatus.pending ||
                reservation.status == ReservationStatus.confirmed)
              Row(
                children: [
                  if (reservation.status == ReservationStatus.pending)
                    FilledButton.tonal(
                      onPressed: onConfirm,
                      style: FilledButton.styleFrom(
                        backgroundColor:
                            AppColors.successLight.withValues(alpha: 0.1),
                        foregroundColor: AppColors.successLight,
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.lg,
                          vertical: AppSpacing.sm,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppSpacing.radiusMd,
                          ),
                        ),
                      ),
                      child: Text(
                        l10n.confirm,
                        style: AppTextStyles.labelMedium.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  if (reservation.status == ReservationStatus.pending)
                    const SizedBox(width: AppSpacing.sm),
                  FilledButton.tonal(
                    onPressed: onCancel,
                    style: FilledButton.styleFrom(
                      backgroundColor:
                          theme.colorScheme.error.withValues(alpha: 0.1),
                      foregroundColor: theme.colorScheme.error,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                        vertical: AppSpacing.sm,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          AppSpacing.radiusMd,
                        ),
                      ),
                    ),
                    child: Text(
                      l10n.cancel,
                      style: AppTextStyles.labelMedium.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
