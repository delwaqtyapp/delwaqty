import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:delwaqty/domain/entities/app_notification.dart';
import 'package:delwaqty/core/errors/app_error_text.dart';
import 'package:delwaqty/features/_shared/notifications/notifications_module.dart';
import 'package:delwaqty/shared/notifications/notification_localizer.dart';
import 'package:delwaqty/shared/notifications/notification_route_resolver.dart';
import 'package:delwaqty/shared/widgets/app_loader.dart';
import 'package:delwaqty/shared/widgets/premium_empty_state.dart';
import 'package:delwaqty/shared/widgets/animated_fade_in.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

import 'dart:async';

const _pageSize = 20;

class NotificationCenterPage extends ConsumerStatefulWidget {
  const NotificationCenterPage({super.key});

  @override
  ConsumerState<NotificationCenterPage> createState() =>
      _NotificationCenterPageState();
}

class _NotificationCenterPageState
    extends ConsumerState<NotificationCenterPage> {
  final List<AppNotification> _items = [];
  int _offset = 0;
  bool _loading = false;
  bool _hasMore = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _loadMore();
  }

  Future<void> _loadMore() async {
    if (_loading || !_hasMore) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = ref.read(notificationRepositoryProvider);
      final page = await repo.getNotifications(offset: _offset);
      if (!mounted) return;
      setState(() {
        _items.addAll(page);
        _offset += page.length;
        _hasMore = page.length == _pageSize;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e;
      });
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _items.clear();
      _offset = 0;
      _hasMore = true;
      _error = null;
    });
    await _loadMore();
  }

  void _showNotificationDetails(AppNotification notification) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  notification.title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  notification.body,
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                Text(
                  notification.createdAt.toLocal().toString().substring(0, 16),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _invalidateNotificationProviders() {
    ref.invalidate(unreadCountProvider);
    ref.invalidate(unreadCountStreamProvider);
    ref.invalidate(notificationsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    ref.listen<AsyncValue<int>>(unreadCountStreamProvider, (prev, next) {
      if (prev != null &&
          prev.hasValue &&
          next.hasValue &&
          prev.value != next.value) {
        _refresh();
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.notifications),
        actions: [
          TextButton(
            onPressed: () async {
              final repo = ref.read(notificationRepositoryProvider);
              await repo.markAllAsRead();
              if (!mounted) return;
              for (var i = 0; i < _items.length; i++) {
                _items[i] = _items[i].copyWith(isRead: true);
              }
              setState(() {});
              _invalidateNotificationProviders();
            },
            child: Text(l10n.markAllRead),
          ),
          IconButton(
            tooltip: l10n.deleteAllNotifications,
            icon: const Icon(Icons.delete_sweep_rounded),
            onPressed: () => _confirmDeleteAll(context),
          ),
        ],
      ),
      body: _items.isEmpty && _loading
          ? ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: 5,
              itemBuilder: (context, index) => const SkeletonListTile(),
            )
          : _items.isEmpty && _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      appErrorText(context, _error!),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: _refresh,
                      icon: const Icon(Icons.refresh_rounded),
                      label: Text(l10n.retry),
                    ),
                  ],
                ),
              ),
            )
          : _items.isEmpty
          ? PremiumEmptyState(
              icon: Icons.notifications_none_rounded,
              title: l10n.noNotifications,
              message: l10n.noNotificationsMessage,
            )
          : _buildList(),
    );
  }

  Widget _buildList() {
    final notifications = List<AppNotification>.from(_items);
    final grouped = _groupByDate(notifications);
    final sections = grouped.entries.toList();

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: sections.length + 1,
        itemBuilder: (context, sectionIndex) {
          if (sectionIndex == sections.length) {
            if (!_hasMore) return const SizedBox(height: 24);
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: _loading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : OutlinedButton(
                        onPressed: _loadMore,
                        child: Text(AppLocalizations.of(context).loadMore),
                      ),
              ),
            );
          }

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
                        final repo = ref.read(notificationRepositoryProvider);
                        await repo.markAsRead(notification.id);
                        if (!mounted) return;
                        final index = _items.indexWhere(
                          (n) => n.id == notification.id,
                        );
                        if (index != -1) {
                          _items[index] = _items[index].copyWith(isRead: true);
                          setState(() {});
                        }
                        _invalidateNotificationProviders();
                        if (context.mounted) {
                          final route =
                              NotificationRouteResolver.safeNotification(
                                notification,
                                context: NotificationRouteResolver.appContext,
                              );
                          if (route !=
                              NotificationRouteResolver.fallbackRoute) {
                            final matches = GoRouter.of(context)
                                .routeInformationParser
                                .configuration
                                .findMatch(Uri.parse(route))
                                .matches;
                            if (matches.isNotEmpty) {
                              unawaited(context.push(route));
                            } else {
                              _showNotificationDetails(notification);
                            }
                          } else {
                            // No deep link: tapping still opens the content.
                            _showNotificationDetails(notification);
                          }
                        }
                      },
                      onDelete: () async {
                        final repo = ref.read(notificationRepositoryProvider);
                        await repo.deleteNotification(notification.id);
                        if (!mounted) return;
                        _items.removeWhere((n) => n.id == notification.id);
                        _offset = _items.length;
                        setState(() {});
                        _invalidateNotificationProviders();
                      },
                    ),
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
  }

  Map<String, List<AppNotification>> _groupByDate(
    List<AppNotification> notifications,
  ) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    final l10n = AppLocalizations.of(context);

    final Map<String, List<AppNotification>> grouped = {};

    for (final n in notifications) {
      final date = DateTime(
        n.createdAt.year,
        n.createdAt.month,
        n.createdAt.day,
      );
      String label;
      if (!date.isBefore(today)) {
        label = l10n.notificationToday;
      } else if (!date.isBefore(yesterday)) {
        label = l10n.notificationYesterday;
      } else {
        label = l10n.notificationOlder;
      }
      grouped.putIfAbsent(label, () => []).add(n);
    }

    return grouped;
  }

  Future<void> _confirmDeleteAll(BuildContext context) async {
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
    if (confirmed != true || !mounted) return;

    final repo = ref.read(notificationRepositoryProvider);
    await repo.clearAll();
    setState(() {
      _items.clear();
      _offset = 0;
      _hasMore = false;
    });
    _invalidateNotificationProviders();
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.notification,
    this.onTap,
    this.onDelete,
  });

  final AppNotification notification;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final typeColor = NotificationLocalizer.typeColor(
      notification.type,
      colorScheme,
    );

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
                  NotificationLocalizer.typeIcon(notification.type),
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
                            NotificationLocalizer.title(context, notification),
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  fontWeight: notification.isRead
                                      ? FontWeight.normal
                                      : FontWeight.w600,
                                ),
                          ),
                        ),
                        if (notification.priority == NotificationPriority.high)
                          Container(
                            margin: const EdgeInsetsDirectional.only(end: 6),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: colorScheme.error.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              l10n.notificationPriorityHigh,
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    color: colorScheme.error,
                                    fontWeight: FontWeight.w700,
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
                      NotificationLocalizer.body(context, notification),
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: colorScheme.onSurfaceVariant),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      NotificationLocalizer.formatRelativeTime(
                        notification.createdAt,
                        l10n,
                      ),
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              if (onDelete != null)
                IconButton(
                  tooltip: l10n.deleteNotification,
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
}
