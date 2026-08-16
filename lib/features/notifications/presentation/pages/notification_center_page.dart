import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:delwaqty/domain/entities/app_notification.dart';
import 'package:delwaqty/features/notifications/notifications_module.dart';
import 'package:delwaqty/shared/widgets/app_loader.dart';
import 'package:delwaqty/shared/widgets/premium_empty_state.dart';
import 'package:delwaqty/shared/widgets/animated_fade_in.dart';
import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:delwaqty/core/theme/app_colors.dart';

class NotificationCenterPage extends ConsumerWidget {
  const NotificationCenterPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final notificationsAsync = ref.watch(notificationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.notifications),
        actions: [
          TextButton(
            onPressed: () async {
              final repo = ref.read(notificationRepositoryProvider);
              await repo.markAllAsRead();
              ref.invalidate(notificationsProvider);
              ref.invalidate(unreadCountProvider);
            },
            child: Text(l10n.markAllRead),
          ),
          IconButton(
            tooltip: l10n.deleteAllNotifications,
            icon: const Icon(Icons.delete_sweep_rounded),
            onPressed: () => _confirmDeleteAll(context, ref),
          ),
        ],
      ),
      body: notificationsAsync.when(
        data: (notifications) {
          if (notifications.isEmpty) {
            return PremiumEmptyState(
              icon: Icons.notifications_none_rounded,
              title: l10n.noNotifications,
              message: l10n.noNotificationsMessage,
            );
          }

          final grouped = _groupByDate(notifications);
          final sections = grouped.entries.toList();

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: sections.length,
            itemBuilder: (context, sectionIndex) {
              final section = sections[sectionIndex];
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 16, bottom: 8),
                    child: Text(
                      section.key,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ),
                  ...List.generate(section.value.length, (index) {
                    final notification = section.value[index];
                    return AnimatedFadeIn(
                      delay: Duration(milliseconds: index * 30),
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _NotificationCard(
                          notification: notification,
                          onTap: () async {
                            final repo =
                                ref.read(notificationRepositoryProvider);
                            await repo.markAsRead(notification.id);
                            ref.invalidate(notificationsProvider);
                            ref.invalidate(unreadCountProvider);
                            if (notification.deepLink != null &&
                                context.mounted) {
                              context.push(notification.deepLink!);
                            }
                          },
                          onDelete: () async {
                            final repo =
                                ref.read(notificationRepositoryProvider);
                            await repo.deleteNotification(notification.id);
                            ref.invalidate(notificationsProvider);
                            ref.invalidate(unreadCountProvider);
                          },
                        ),
                      ),
                    );
                  }),
                ],
              );
            },
          );
        },
        loading: () => ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: 5,
          itemBuilder: (context, index) => const SkeletonListTile(),
        ),
        error: (e, _) => PremiumEmptyState(
          icon: Icons.error_outline_rounded,
          title: l10n.error,
          message: e.toString(),
          actionLabel: l10n.retry,
          onAction: () => ref.invalidate(notificationsProvider),
        ),
      ),
    );
  }

  Map<String, List<AppNotification>> _groupByDate(
    List<AppNotification> notifications,
  ) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    final Map<String, List<AppNotification>> grouped = {};

    for (final n in notifications) {
      final date = DateTime(n.createdAt.year, n.createdAt.month, n.createdAt.day);
      String label;
      if (!date.isBefore(today)) {
        label = 'اليوم';
      } else if (!date.isBefore(yesterday)) {
        label = 'أمس';
      } else {
        label = 'أقدم';
      }
      grouped.putIfAbsent(label, () => []).add(n);
    }

    return grouped;
  }
}

Future<void> _confirmDeleteAll(BuildContext context, WidgetRef ref) async {
  final l10n = AppLocalizations.of(context);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n.deleteAllNotifications),
      content: Text(l10n.deleteAllNotificationsConfirm),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n.delete),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;

  final repo = ref.read(notificationRepositoryProvider);
  await repo.clearAll();
  ref.invalidate(notificationsProvider);
  ref.invalidate(unreadCountProvider);
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({required this.notification, this.onTap, this.onDelete});

  final AppNotification notification;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final typeColor = _getTypeColor(notification.type, colorScheme);

    return Material(
      color: notification.isRead
          ? Colors.transparent
          : colorScheme.primaryContainer.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: typeColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  _getTypeIcon(notification.type),
                  size: 20,
                  color: typeColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  fontWeight: notification.isRead
                                      ? FontWeight.normal
                                      : FontWeight.w600,
                                ),
                          ),
                        ),
                        if (!notification.isRead)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: colorScheme.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notification.body,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _formatTime(notification.createdAt),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (onDelete != null)
                IconButton(
                  tooltip: AppLocalizations.of(
                    context,
                  ).deleteNotification,
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.delete_outline_rounded, size: 20),
                  color: colorScheme.onSurfaceVariant,
                  onPressed: onDelete,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getTypeColor(NotificationType type, ColorScheme colorScheme) {
    switch (type) {
      case NotificationType.system:
        return colorScheme.primary;
      case NotificationType.order:
        return AppColors.brandPurple;
      case NotificationType.payment:
        return AppColors.successLight;
      case NotificationType.promotion:
        return AppColors.warningLight;
      case NotificationType.service:
        return AppColors.serviceRestaurant;
      case NotificationType.account:
        return colorScheme.tertiary;
      case NotificationType.security:
        return AppColors.errorLight;
      case NotificationType.message:
        return colorScheme.secondary;
      case NotificationType.info:
        return colorScheme.primary;
      case NotificationType.warning:
        return AppColors.warningLight;
      case NotificationType.success:
        return AppColors.successLight;
      case NotificationType.reminder:
        return AppColors.orderPreparing;
      case NotificationType.reward:
        return AppColors.brandPurple;
    }
  }

  IconData _getTypeIcon(NotificationType type) {
    switch (type) {
      case NotificationType.system:
        return Icons.info_outline_rounded;
      case NotificationType.order:
        return Icons.shopping_bag_outlined;
      case NotificationType.payment:
        return Icons.payment_rounded;
      case NotificationType.promotion:
        return Icons.local_offer_outlined;
      case NotificationType.service:
        return Icons.home_repair_service_outlined;
      case NotificationType.account:
        return Icons.person_outline_rounded;
      case NotificationType.security:
        return Icons.shield_outlined;
      case NotificationType.message:
        return Icons.chat_bubble_outline_rounded;
      case NotificationType.info:
        return Icons.info_outline_rounded;
      case NotificationType.warning:
        return Icons.warning_amber_rounded;
      case NotificationType.success:
        return Icons.check_circle_outline_rounded;
      case NotificationType.reminder:
        return Icons.alarm_rounded;
      case NotificationType.reward:
        return Icons.card_giftcard_rounded;
    }
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);

    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
  }
}
