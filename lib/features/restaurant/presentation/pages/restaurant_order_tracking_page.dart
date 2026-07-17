import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delwaqty/features/restaurant/domain/entities/order_tracking.dart';
import 'package:delwaqty/features/restaurant/restaurant_module.dart';
import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:delwaqty/shared/widgets/animated_fade_in.dart';
import 'package:delwaqty/shared/widgets/empty_state.dart';
import 'package:delwaqty/shared/widgets/error_state.dart';
import 'package:delwaqty/shared/widgets/app_loader.dart';
import 'package:delwaqty/core/extensions/context_extensions.dart';

final _trackingProvider =
    FutureProvider.family<List<OrderTracking>, String>((ref, orderId) async {
  final repo = ref.watch(orderTrackingRepositoryProvider);
  return repo.getTracking(orderId);
});

class RestaurantOrderTrackingPage extends ConsumerWidget {
  const RestaurantOrderTrackingPage({required this.orderId, super.key});

  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final trackingAsync = ref.watch(_trackingProvider(orderId));

    return Scaffold(
      appBar: AppBar(title: Text(l10n.orderTracking)),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(_trackingProvider(orderId)),
        child: trackingAsync.when(
          data: (entries) {
            if (entries.isEmpty) {
              return ListView(
                children: [
                  SizedBox(
                    height: MediaQuery.sizeOf(context).height * 0.7,
                    child: EmptyState(
                      icon: Icons.timeline_outlined,
                      title: 'No tracking data',
                      message: 'Tracking updates will appear here.',
                    ),
                  ),
                ],
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: entries.length,
              itemBuilder: (context, index) {
                final entry = entries[index];
                final isFirst = index == 0;
                final isLast = index == entries.length - 1;

                return AnimatedFadeIn(
                  delay: Duration(milliseconds: 80 * index),
                  child: _TrackingTile(
                    entry: entry,
                    isFirst: isFirst,
                    isLast: isLast,
                    l10n: l10n,
                  ),
                );
              },
            );
          },
          loading: () => const Center(child: AppLoaderCircular()),
          error: (e, _) => ErrorState(
            title: l10n.error,
            message: e.toString(),
            onRetry: () => ref.invalidate(_trackingProvider(orderId)),
            retryLabel: l10n.retry,
          ),
        ),
      ),
    );
  }
}

class _TrackingTile extends StatelessWidget {
  const _TrackingTile({
    required this.entry,
    required this.isFirst,
    required this.isLast,
    required this.l10n,
  });

  final OrderTracking entry;
  final bool isFirst;
  final bool isLast;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final textTheme = context.textTheme;

    final isActive = isFirst;
    final statusColor = isActive ? colorScheme.primary : colorScheme.outline;
    final icon = isActive ? Icons.circle : Icons.check_circle_outline;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: statusColor,
                  shape: BoxShape.circle,
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: colorScheme.outlineVariant,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Card(
                elevation: isActive ? 2 : 0,
                color: isActive
                    ? colorScheme.primaryContainer.withValues(alpha: 0.3)
                    : colorScheme.surfaceContainerLow,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(icon, size: 18, color: statusColor),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              entry.status.toUpperCase(),
                              style: textTheme.labelLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: statusColor,
                              ),
                            ),
                          ),
                          Text(
                            _formatTime(entry.createdAt),
                            style: textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      if (entry.estimatedMinutes != null) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              Icons.timer_outlined,
                              size: 14,
                              color: colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '~${entry.estimatedMinutes} min',
                              style: textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (entry.notes != null && entry.notes!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          entry.notes!,
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
