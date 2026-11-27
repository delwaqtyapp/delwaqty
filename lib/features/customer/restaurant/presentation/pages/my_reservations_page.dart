import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delwaqty/core/errors/app_error_text.dart';
import 'package:delwaqty/core/theme/app_colors.dart';
import 'package:delwaqty/core/theme/app_spacing.dart';
import 'package:delwaqty/features/_shared/auth/presentation/auth_provider.dart';
import 'package:delwaqty/features/customer/commerce/commerce_module.dart';
import 'package:delwaqty/features/customer/restaurant/domain/entities/reservation.dart';
import 'package:delwaqty/features/customer/restaurant/restaurant_module.dart';
import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:delwaqty/shared/widgets/animated_fade_in.dart';
import 'package:delwaqty/shared/widgets/app_loader.dart';
import 'package:delwaqty/shared/widgets/premium_empty_state.dart';

/// The signed-in customer's reservations, newest first. Cancellable while the
/// restaurant has not seated the party.
final myReservationsProvider = FutureProvider<List<Reservation>>((ref) async {
  final auth = ref.watch(authStateProvider);
  final userId = auth is AuthAuthenticated ? auth.user.id : null;
  if (userId == null) return const [];
  return ref.watch(reservationRepositoryProvider).getUserReservations(userId);
});

final reservationMerchantNameProvider = FutureProvider.family<String?, String>(
  (ref, merchantId) async {
    final merchant = await ref
        .watch(merchantRepositoryProvider)
        .getMerchantById(merchantId);
    return merchant?.name;
  },
);

/// A reservation can be cancelled by the customer until the restaurant
/// seats the party.
bool isReservationCancellable(ReservationStatus status) =>
    status == ReservationStatus.pending ||
    status == ReservationStatus.confirmed;

class MyReservationsPage extends ConsumerWidget {
  const MyReservationsPage({super.key});

  Future<void> _cancelReservation(
    BuildContext context,
    WidgetRef ref,
    Reservation reservation,
  ) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        title: Text(l10n.cancelReservation),
        content: Text(l10n.cancelReservationConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dlgCtx).pop(false),
            child: Text(l10n.no),
          ),
          TextButton(
            onPressed: () => Navigator.of(dlgCtx).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(dlgCtx).colorScheme.error,
            ),
            child: Text(l10n.yes),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await ref
          .read(reservationRepositoryProvider)
          .cancelReservation(reservation.id);
      ref.invalidate(myReservationsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.reservationCancelled)));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(appErrorText(context, e))));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final reservationsAsync = ref.watch(myReservationsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.myReservations)),
      body: reservationsAsync.when(
        loading: () => const Center(child: AppLoaderCircular()),
        error: (e, _) => PremiumEmptyState(
          icon: Icons.error_outline,
          title: l10n.error,
          message: appErrorText(context, e),
        ),
        data: (reservations) {
          if (reservations.isEmpty) {
            return PremiumEmptyState(
              icon: Icons.event_busy_outlined,
              title: l10n.noReservations,
              message: l10n.noReservationsMessage,
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(myReservationsProvider),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: reservations.length,
              itemBuilder: (context, index) {
                final reservation = reservations[index];
                return AnimatedFadeIn(
                  delay: Duration(milliseconds: 80 * index),
                  child: _ReservationCard(
                    reservation: reservation,
                    onCancel: () =>
                        _cancelReservation(context, ref, reservation),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _ReservationCard extends ConsumerWidget {
  const _ReservationCard({required this.reservation, required this.onCancel});

  final Reservation reservation;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final merchantNameAsync = ref.watch(
      reservationMerchantNameProvider(reservation.merchantId),
    );

    final statusColor = switch (reservation.status) {
      ReservationStatus.pending => AppColors.warningLight,
      ReservationStatus.confirmed => AppColors.infoLight,
      ReservationStatus.seated => AppColors.brandPurple,
      ReservationStatus.completed => AppColors.successLight,
      ReservationStatus.cancelled => theme.colorScheme.error,
    };
    final statusLabel = switch (reservation.status) {
      ReservationStatus.pending => l10n.pending,
      ReservationStatus.confirmed => l10n.confirmed,
      ReservationStatus.seated => l10n.seated,
      ReservationStatus.completed => l10n.completed,
      ReservationStatus.cancelled => l10n.cancelled,
    };
    final cancellable = isReservationCancellable(reservation.status);

    final time = reservation.reservationTime;
    final dateStr =
        '${time.day.toString().padLeft(2, '0')}/'
        '${time.month.toString().padLeft(2, '0')}/'
        '${time.year}';
    final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
    final timeStr =
        '${hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')} '
        '${time.hour < 12 ? 'AM' : 'PM'}';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    merchantNameAsync.asData?.value ?? l10n.restaurant,
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
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  ),
                  child: Text(
                    statusLabel,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: statusColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.event_outlined,
                  size: 16,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Text('$dateStr - $timeStr', style: theme.textTheme.bodySmall),
                const SizedBox(width: 16),
                Icon(
                  Icons.group_outlined,
                  size: 16,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Text(
                  '${reservation.partySize} ${l10n.guests}',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
            if (reservation.tableNumber != null) ...[
              const SizedBox(height: 4),
              Text(
                l10n.table(reservation.tableNumber!),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            if (reservation.specialRequests != null &&
                reservation.specialRequests!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                '${l10n.specialRequests}: ${reservation.specialRequests}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            if (cancellable) ...[
              const SizedBox(height: 8),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton.icon(
                  onPressed: onCancel,
                  icon: const Icon(Icons.cancel_outlined, size: 18),
                  label: Text(l10n.cancelReservation),
                  style: TextButton.styleFrom(
                    foregroundColor: theme.colorScheme.error,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
