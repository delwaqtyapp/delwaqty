import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:delwaqty/core/errors/app_error_text.dart';
import 'package:delwaqty/features/provider/merchant/presentation/providers/merchant_providers.dart';
import 'package:delwaqty/core/extensions/context_extensions.dart';
import 'package:delwaqty/features/customer/restaurant/restaurant_module.dart';
import 'package:delwaqty/features/customer/restaurant/domain/entities/reservation.dart';
import 'package:delwaqty/services/supabase/supabase_service.dart';
import 'package:delwaqty/shared/widgets/animated_fade_in.dart';
import 'package:delwaqty/shared/widgets/premium_empty_state.dart';
import 'package:delwaqty/shared/widgets/shimmer_loading.dart';
import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:delwaqty/core/theme/app_colors.dart';
import 'package:delwaqty/core/theme/app_spacing.dart';
import 'package:delwaqty/core/theme/app_text_styles.dart';
import 'package:delwaqty/shared/widgets/design/premium_card.dart';

final _merchantIdProvider = providerMerchantIdProvider;

final _reservationsFilterProvider = StateProvider<ReservationStatus?>(
  (ref) => null,
);

final _reservationsProvider =
    FutureProvider<List<Reservation>>((ref) async {
  final repo = ref.watch(reservationRepositoryProvider);
  final merchantId = await ref.watch(_merchantIdProvider.future);
  final status = ref.watch(_reservationsFilterProvider);
  return repo.getReservations(merchantId, status: status);
});

final _serviceBookingsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  SupabaseClient client;
  try {
    client = ref.watch(supabaseClientProvider);
  } catch (_) {
    client = Supabase.instance.client;
  }
  final spIdRaw = await client.rpc('resolve_my_service_provider');
  final spId = spIdRaw as String? ?? '';
  if (spId.isEmpty) return const <Map<String, dynamic>>[];
  final res = await client
      .from('service_bookings')
      .select()
      .eq('provider_id', spId)
      .order('created_at', ascending: false);
  return (res as List)
      .map((e) => Map<String, dynamic>.from(e as Map))
      .toList();
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
    final serviceBookingsAsync = ref.watch(_serviceBookingsProvider);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.reservations),
          actions: [
            IconButton(
              tooltip: l10n.refresh,
              icon: const Icon(Icons.refresh),
              onPressed: () {
                ref.invalidate(_reservationsProvider);
                ref.invalidate(_serviceBookingsProvider);
              },
            ),
          ],
          bottom: TabBar(
            tabs: [
              Tab(text: l10n.tableReservationsTitle),
              Tab(text: l10n.serviceBookingsTitle),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            Column(
              children: [
                _buildFilterChips(ref, l10n),
                Expanded(
                  child: reservationsAsync.when(
                    loading: () => ListView.builder(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      itemCount: 5,
                      itemBuilder: (_, _) => const Padding(
                        padding: EdgeInsets.only(bottom: 12),
                        child: ShimmerCard(),
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
                                onConfirm: () => _updateStatus(
                                  reservation,
                                  ReservationStatus.confirmed,
                                ),
                                onMarkSeated: () => _updateStatus(
                                  reservation,
                                  ReservationStatus.seated,
                                ),
                                onMarkCompleted: () => _updateStatus(
                                  reservation,
                                  ReservationStatus.completed,
                                ),
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
            serviceBookingsAsync.when(
              loading: () => ListView.builder(
                padding: const EdgeInsets.all(AppSpacing.lg),
                itemCount: 5,
                itemBuilder: (_, _) => const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: ShimmerCard(),
                ),
              ),
              error: (e, _) => Center(
                child: PremiumEmptyState(
                  icon: Icons.error_outline_rounded,
                  title: l10n.error,
                  message: l10n.errorLoading,
                  actionLabel: l10n.retry,
                  onAction: () => ref.invalidate(_serviceBookingsProvider),
                ),
              ),
              data: (bookings) {
                if (bookings.isEmpty) {
                  return Center(
                    child: PremiumEmptyState(
                      icon: Icons.handyman_outlined,
                      title: l10n.serviceBookingsTitle,
                      message: l10n.noReservations,
                    ),
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async =>
                      ref.invalidate(_serviceBookingsProvider),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    itemCount: bookings.length,
                    itemBuilder: (context, index) {
                      final booking = bookings[index];
                      return AnimatedFadeIn(
                        delay: Duration(milliseconds: index * 50),
                        child: _ServiceBookingCard(
                          booking: booking,
                          onUpdateStatus: (status) => _updateBookingStatus(
                            booking['id'] as String? ?? '',
                            status,
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChips(WidgetRef ref, AppLocalizations l10n) {
    final currentFilter = ref.watch(_reservationsFilterProvider);
    final filters = <MapEntry<ReservationStatus?, String?>>[
      MapEntry(null, l10n.all),
      MapEntry(ReservationStatus.pending, l10n.pending),
      MapEntry(ReservationStatus.confirmed, l10n.confirmed),
      MapEntry(ReservationStatus.seated, l10n.markSeated),
      MapEntry(ReservationStatus.completed, l10n.markCompleted),
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
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
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
    try {
      await repo.updateReservation(reservation.id, status);
      ref.invalidate(_reservationsProvider);
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        context.showAppSnackBar(
          status == ReservationStatus.confirmed
              ? l10n.reservationConfirmed
              : l10n.updatedSuccessfully,
        );
      }
    } catch (e) {
      if (mounted) {
        context.showAppSnackBar(
          appErrorText(context, e),
          isError: true,
        );
      }
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
      try {
        await repo.cancelReservation(reservation.id);
        ref.invalidate(_reservationsProvider);
        if (mounted) {
          context.showAppSnackBar(l10n.reservationCancelled);
        }
      } catch (e) {
        if (mounted) {
          context.showAppSnackBar(
            appErrorText(context, e),
            isError: true,
          );
        }
      }
    }
  }

  Future<void> _updateBookingStatus(String bookingId, String status) async {
    if (bookingId.isEmpty) return;
    try {
      SupabaseClient client;
      try {
        client = ref.read(supabaseClientProvider);
      } catch (_) {
        client = Supabase.instance.client;
      }
      await client
          .from('service_bookings')
          .update({
            'status': status,
            if (status == 'completed')
              'completed_at': DateTime.now().toIso8601String(),
          })
          .eq('id', bookingId);
      ref.invalidate(_serviceBookingsProvider);
      if (mounted) {
        context.showAppSnackBar(
          AppLocalizations.of(context).updatedSuccessfully,
        );
      }
    } catch (e) {
      if (mounted) {
        context.showAppSnackBar(
          appErrorText(context, e),
          isError: true,
        );
      }
    }
  }
}

class _ReservationCard extends StatelessWidget {
  const _ReservationCard({
    required this.reservation,
    required this.onConfirm,
    required this.onMarkSeated,
    required this.onMarkCompleted,
    required this.onCancel,
  });

  final Reservation reservation;
  final VoidCallback onConfirm;
  final VoidCallback onMarkSeated;
  final VoidCallback onMarkCompleted;
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
      ReservationStatus.seated => l10n.markSeated,
      ReservationStatus.completed => l10n.markCompleted,
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
                    reservation.userId,
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
                  l10n.guestsCount(reservation.partySize),
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
                  '$dateStr · $timeStr',
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
                reservation.status == ReservationStatus.confirmed ||
                reservation.status == ReservationStatus.seated)
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
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
                  if (reservation.status == ReservationStatus.confirmed)
                    FilledButton.tonal(
                      onPressed: onMarkSeated,
                      style: FilledButton.styleFrom(
                        backgroundColor:
                            AppColors.brandPurple.withValues(alpha: 0.1),
                        foregroundColor: AppColors.brandPurple,
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
                        l10n.markSeated,
                        style: AppTextStyles.labelMedium.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  if (reservation.status == ReservationStatus.seated)
                    FilledButton.tonal(
                      onPressed: onMarkCompleted,
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
                        l10n.markCompleted,
                        style: AppTextStyles.labelMedium.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  if (reservation.status == ReservationStatus.pending ||
                      reservation.status == ReservationStatus.confirmed)
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

class _ServiceBookingCard extends StatelessWidget {
  const _ServiceBookingCard({
    required this.booking,
    required this.onUpdateStatus,
  });

  final Map<String, dynamic> booking;
  final ValueChanged<String> onUpdateStatus;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    final status = (booking['status'] as String?) ?? 'pending';
    final description = (booking['description'] as String?)?.isNotEmpty == true
        ? booking['description'] as String
        : ((booking['category_type'] as String?) ?? l10n.serviceBookingsTitle);
    final scheduledDateRaw = booking['scheduled_date'] as String?;
    final scheduledTime = booking['scheduled_time'] as String? ?? '';
    final address = booking['address'] as String? ?? '';
    final estimatedPrice = (booking['estimated_price'] as num?)?.toDouble();

    String dateStr = '';
    if (scheduledDateRaw != null && scheduledDateRaw.isNotEmpty) {
      final parsed = DateTime.tryParse(scheduledDateRaw);
      if (parsed != null) {
        dateStr =
            '${parsed.day.toString().padLeft(2, '0')}/${parsed.month.toString().padLeft(2, '0')}/${parsed.year}';
      } else {
        dateStr = scheduledDateRaw;
      }
    }

    final statusColor = switch (status) {
      'pending' => AppColors.warningLight,
      'confirmed' => AppColors.infoLight,
      'in_progress' => AppColors.brandPurple,
      'completed' => AppColors.successLight,
      'cancelled' => AppColors.errorLight,
      _ => AppColors.infoLight,
    };

    final statusLabel = switch (status) {
      'pending' => l10n.pending,
      'confirmed' => l10n.confirmed,
      'in_progress' => l10n.inProgress,
      'completed' => l10n.completed,
      'cancelled' => l10n.cancelled,
      _ => status,
    };

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
                    description,
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
            if (dateStr.isNotEmpty || scheduledTime.isNotEmpty)
              Row(
                children: [
                  Icon(
                    Icons.calendar_today_outlined,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    [
                      if (dateStr.isNotEmpty) dateStr,
                      if (scheduledTime.isNotEmpty) scheduledTime,
                    ].join(' · '),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            if (address.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    Icons.location_on_outlined,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      address,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            if (estimatedPrice != null) ...[
              const SizedBox(height: 4),
              Text(
                '${estimatedPrice.toStringAsFixed(0)} ${l10n.currencySymbol}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.brandPurple,
                ),
              ),
            ],
            if (status != 'completed' && status != 'cancelled') ...[
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  if (status == 'pending')
                    FilledButton.tonal(
                      onPressed: () => onUpdateStatus('confirmed'),
                      child: Text(l10n.confirm),
                    ),
                  if (status == 'pending' || status == 'confirmed')
                    FilledButton.tonal(
                      onPressed: () => onUpdateStatus('in_progress'),
                      child: Text(l10n.inProgress),
                    ),
                  if (status == 'confirmed' || status == 'in_progress')
                    FilledButton.tonal(
                      onPressed: () => onUpdateStatus('completed'),
                      child: Text(l10n.markCompleted),
                    ),
                  FilledButton.tonal(
                    onPressed: () => onUpdateStatus('cancelled'),
                    style: FilledButton.styleFrom(
                      backgroundColor:
                          theme.colorScheme.error.withValues(alpha: 0.1),
                      foregroundColor: theme.colorScheme.error,
                    ),
                    child: Text(l10n.cancel),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
