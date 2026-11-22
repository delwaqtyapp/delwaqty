import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delwaqty/core/theme/app_colors.dart';
import 'package:delwaqty/core/theme/app_spacing.dart';
import 'package:delwaqty/features/customer/home_services/domain/entities/service_booking.dart';
import 'package:delwaqty/features/customer/home_services/data/repositories/service_booking_repository_impl.dart';
import 'package:delwaqty/shared/widgets/animated_fade_in.dart';
import 'package:delwaqty/shared/widgets/app_loader.dart';
import 'package:delwaqty/shared/widgets/glass_card.dart';
import 'package:delwaqty/shared/widgets/premium_empty_state.dart';
import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:delwaqty/core/errors/app_error_text.dart';

final myServiceBookingsProvider = FutureProvider<List<ServiceBooking>>((
  ref,
) async {
  final repo = ref.watch(serviceBookingRepositoryProvider);
  return repo.getUserBookings();
});

class MyServiceBookingsPage extends ConsumerWidget {
  const MyServiceBookingsPage({super.key});

  Future<void> _cancelBooking(
    BuildContext context,
    WidgetRef ref,
    ServiceBooking booking,
  ) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        title: Text(l10n.cancel),
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
          .read(serviceBookingRepositoryProvider)
          .cancelBooking(booking.id);
      ref.invalidate(myServiceBookingsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l10n.reservationCancelled)));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(appErrorText(context, e))));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final bookingsAsync = ref.watch(myServiceBookingsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.myBookings)),
      body: bookingsAsync.when(
        loading: () => const Center(child: AppLoaderCircular()),
        error: (e, _) => PremiumEmptyState(
          icon: Icons.error_outline,
          title: l10n.error,
          message: appErrorText(context, e),
        ),
        data: (bookings) {
          if (bookings.isEmpty) {
            return PremiumEmptyState(
              icon: Icons.event_busy_outlined,
              title: l10n.noBookingsYet,
              message: '',
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(myServiceBookingsProvider),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: bookings.length,
              itemBuilder: (context, index) {
                return AnimatedFadeIn(
                  delay: Duration(milliseconds: index * 50),
                  child: _BookingCard(
                    booking: bookings[index],
                    onCancel: () =>
                        _cancelBooking(context, ref, bookings[index]),
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

class _BookingCard extends StatelessWidget {
  const _BookingCard({required this.booking, required this.onCancel});

  final ServiceBooking booking;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    final statusColor = switch (booking.status) {
      BookingStatus.pending => AppColors.warningLight,
      BookingStatus.confirmed => AppColors.infoLight,
      BookingStatus.inProgress => AppColors.brandPurple,
      BookingStatus.completed => AppColors.successLight,
      BookingStatus.cancelled => theme.colorScheme.error,
    };
    final statusLabel = switch (booking.status) {
      BookingStatus.pending => l10n.pending,
      BookingStatus.confirmed => l10n.confirmed,
      BookingStatus.inProgress => l10n.inProgress,
      BookingStatus.completed => l10n.completed,
      BookingStatus.cancelled => l10n.cancelled,
    };

    final price = booking.finalPrice ?? booking.estimatedPrice;
    final dateStr =
        '${booking.scheduledDate.day.toString().padLeft(2, '0')}/'
        '${booking.scheduledDate.month.toString().padLeft(2, '0')}/'
        '${booking.scheduledDate.year}';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    booking.providerName.isNotEmpty
                        ? booking.providerName
                        : booking.categoryType.name,
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
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              [
                dateStr,
                if (booking.scheduledTime.isNotEmpty) booking.scheduledTime,
              ].join(' · '),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              price != null
                  ? '${price.toStringAsFixed(0)} ${l10n.currencySymbol}'
                  : l10n.bookingQuotePending,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.brandPurple,
              ),
            ),
            if (booking.status == BookingStatus.pending) ...[
              const SizedBox(height: 8),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton(
                  onPressed: onCancel,
                  style: TextButton.styleFrom(
                    foregroundColor: theme.colorScheme.error,
                  ),
                  child: Text(l10n.cancel),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
