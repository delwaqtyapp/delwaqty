import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:delwaqty/core/auth/admin_access.dart';
import 'package:delwaqty/core/errors/app_error_text.dart';
import 'package:delwaqty/domain/entities/app_notification.dart';
import 'package:delwaqty/features/_shared/auth/domain/auth_state.dart';
import 'package:delwaqty/features/_shared/auth/presentation/auth_provider.dart';
import 'package:delwaqty/features/_shared/notifications/notifications_module.dart';
import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:delwaqty/shared/notifications/notification_localizer.dart';
import 'package:delwaqty/shared/notifications/notification_route_resolver.dart';

/// Opens the notifications center as a floating, frosted-glass bubble that
/// bursts from the tapped bell button (anchor rect), matching [GlassSideMenuController].
class GlassNotificationsMenuController {
  GlassNotificationsMenuController._();

  static OverlayEntry? _entry;

  static bool get isOpen => _entry != null;

  @visibleForTesting
  static void resetForTesting() {
    _entry?.remove();
    _entry = null;
  }

  static void open(
    BuildContext context,
    WidgetRef ref, {
    Rect? anchor,
  }) {
    if (_entry != null) return;

    final router = GoRouter.maybeOf(context);
    final overlay = Overlay.of(context, rootOverlay: true);

    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _GlassNotificationsMenuOverlay(
        anchor: anchor,
        router: router,
        onDismiss: () {
          entry.remove();
          _entry = null;
        },
      ),
    );

    _entry = entry;
    overlay.insert(entry);
  }
}

class _GlassNotificationsMenuOverlay extends StatefulWidget {
  const _GlassNotificationsMenuOverlay({
    this.anchor,
    this.router,
    required this.onDismiss,
  });

  final Rect? anchor;
  final GoRouter? router;
  final VoidCallback onDismiss;

  @override
  State<_GlassNotificationsMenuOverlay> createState() =>
      _GlassNotificationsMenuOverlayState();
}

class _GlassNotificationsMenuOverlayState
    extends State<_GlassNotificationsMenuOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final CurvedAnimation _pop;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
      reverseDuration: const Duration(milliseconds: 200),
    );
    _pop = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
      reverseCurve: Curves.easeInCubic,
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _pop.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _close([VoidCallback? afterClose]) async {
    if (_closing) return;
    _closing = true;
    await _controller.reverse();
    if (!mounted) return;
    widget.onDismiss();
    afterClose?.call();
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final size = mq.size;
    final safeTop = mq.padding.top;
    final safeBottom = mq.padding.bottom;
    final isRtl = Directionality.of(context) == TextDirection.rtl;

    final panelWidth = (size.width * 0.84).clamp(270.0, 340.0);
    const margin = 12.0;

    final anchor = widget.anchor;
    double left;
    double top;
    Alignment scaleAlignment;

    if (anchor != null) {
      top = (anchor.bottom + 6).clamp(safeTop + 8, size.height * 0.50);
      final anchorCenterX = anchor.center.dx;
      final isOnRightHalf = anchorCenterX >= size.width / 2;
      if (isOnRightHalf) {
        left = (anchor.right - panelWidth).clamp(
          margin,
          size.width - panelWidth - margin,
        );
        scaleAlignment = Alignment.topRight;
      } else {
        left = anchor.left.clamp(margin, size.width - panelWidth - margin);
        scaleAlignment = Alignment.topLeft;
      }
    } else {
      top = safeTop + 60;
      left = isRtl ? margin : size.width - panelWidth - margin;
      scaleAlignment = isRtl ? Alignment.topLeft : Alignment.topRight;
    }

    final maxPanelHeight = (size.height - top - safeBottom - 24).clamp(
      260.0,
      480.0,
    );

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: _close,
              behavior: HitTestBehavior.translucent,
              child: const SizedBox.expand(),
            ),
          ),
          Positioned(
            top: top,
            left: left,
            width: panelWidth,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxPanelHeight),
              child: AnimatedBuilder(
                animation: _pop,
                builder: (context, child) {
                  final t = _pop.value;
                  final opacity = t.clamp(0.0, 1.0);
                  final scale = 0.35 + 0.65 * t;
                  return Opacity(
                    opacity: opacity,
                    child: FractionalTranslation(
                      translation: Offset(0, -0.06 * (1 - t)),
                      child: Transform.scale(
                        scale: scale,
                        alignment: scaleAlignment,
                        child: child,
                      ),
                    ),
                  );
                },
                child: _GlassNotificationsPanel(
                  onClose: _close,
                  router: widget.router,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlassNotificationsPanel extends ConsumerWidget {
  const _GlassNotificationsPanel({
    required this.onClose,
    required this.router,
  });

  final Future<void> Function([VoidCallback? afterClose]) onClose;
  final GoRouter? router;

  void _invalidateAll(WidgetRef ref) {
    ref.invalidate(unreadCountProvider);
    ref.invalidate(unreadCountStreamProvider);
    ref.invalidate(notificationsProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;

    ref.listen<AsyncValue<int>>(unreadCountStreamProvider, (prev, next) {
      if (prev != null &&
          prev.hasValue &&
          next.hasValue &&
          prev.value != next.value) {
        ref.invalidate(notificationsProvider);
      }
    });

    final notificationsAsync = ref.watch(notificationsProvider);
    final unreadCount = ref.watch(unreadCountStreamProvider).value ??
        ref.watch(unreadCountProvider).value ??
        0;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.42 : 0.14),
            blurRadius: 44,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.34)
                  : Colors.white.withValues(alpha: 0.62),
              borderRadius: BorderRadius.circular(26),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.14)
                    : Colors.black.withValues(alpha: 0.06),
                width: 0.5,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 10, 10),
                  child: Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: cs.primary.withValues(alpha: 0.14),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.notifications_rounded,
                          size: 18,
                          color: cs.primary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Row(
                          children: [
                            Flexible(
                              child: Text(
                                l10n.notifications,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w800),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (unreadCount > 0) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: cs.error,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  unreadCount > 99 ? '99+' : '$unreadCount',
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelSmall
                                      ?.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: l10n.markAllRead,
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.done_all_rounded, size: 19),
                        onPressed: () async {
                          try {
                            await ref
                                .read(notificationRepositoryProvider)
                                .markAllAsRead();
                            _invalidateAll(ref);
                          } catch (_) {}
                        },
                      ),
                      IconButton(
                        tooltip: l10n.deleteAllNotifications,
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.delete_sweep_rounded, size: 19),
                        onPressed: () async {
                          try {
                            await ref
                                .read(notificationRepositoryProvider)
                                .clearAll();
                            _invalidateAll(ref);
                          } catch (_) {}
                        },
                      ),
                    ],
                  ),
                ),
                Divider(
                  height: 0.5,
                  thickness: 0.5,
                  color: cs.onSurface.withValues(alpha: 0.08),
                ),
                Flexible(
                  child: notificationsAsync.when(
                    loading: () => const Padding(
                      padding: EdgeInsets.symmetric(vertical: 36),
                      child: Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2.2),
                        ),
                      ),
                    ),
                    error: (err, _) => Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            appErrorText(context, err),
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 8),
                          TextButton.icon(
                            onPressed: () => ref.invalidate(notificationsProvider),
                            icon: const Icon(Icons.refresh_rounded, size: 16),
                            label: Text(l10n.retry),
                          ),
                        ],
                      ),
                    ),
                    data: (items) {
                      if (items.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 34,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.notifications_none_rounded,
                                size: 36,
                                color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                l10n.noNotifications,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                l10n.noNotificationsMessage,
                                textAlign: TextAlign.center,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(color: cs.onSurfaceVariant),
                              ),
                            ],
                          ),
                        );
                      }

                      return ListView.separated(
                        shrinkWrap: true,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        itemCount: items.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 6),
                        itemBuilder: (context, index) {
                          final n = items[index];
                          return _GlassNotificationItem(
                            notification: n,
                            onTap: () async {
                              try {
                                await ref
                                    .read(notificationRepositoryProvider)
                                    .markAsRead(n.id);
                                _invalidateAll(ref);
                              } catch (_) {}

                              final authState = ref.read(authStateProvider);
                              final isAdmin = authState is AuthAuthenticated &&
                                  authState.user.isAdmin;
                              final route = NotificationRouteResolver.safe(
                                deepLink: n.deepLink,
                                context: isAdmin
                                    ? AppContext.admin
                                    : NotificationRouteResolver.appContext,
                              );
                              await onClose(() {
                                if (route != '/notifications') {
                                  unawaited(router?.push(route));
                                }
                              });
                            },
                            onDelete: () async {
                              try {
                                await ref
                                    .read(notificationRepositoryProvider)
                                    .deleteNotification(n.id);
                                _invalidateAll(ref);
                              } catch (_) {}
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
                Divider(
                  height: 0.5,
                  thickness: 0.5,
                  color: cs.onSurface.withValues(alpha: 0.08),
                ),
                InkWell(
                  onTap: () => onClose(() {
                    unawaited(router?.push('/notifications'));
                  }),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 11,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.open_in_new_rounded,
                          size: 16,
                          color: cs.primary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          l10n.viewAll,
                          style:
                              Theme.of(context).textTheme.labelLarge?.copyWith(
                                    color: cs.primary,
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GlassNotificationItem extends StatelessWidget {
  const _GlassNotificationItem({
    required this.notification,
    required this.onTap,
    required this.onDelete,
  });

  final AppNotification notification;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final typeColor = NotificationLocalizer.typeColor(notification.type, cs);
    final title = NotificationLocalizer.title(context, notification);
    final body = NotificationLocalizer.body(context, notification);

    return Material(
      color: notification.isRead
          ? cs.surface.withValues(alpha: 0.28)
          : cs.primaryContainer.withValues(alpha: 0.34),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 6, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: typeColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  NotificationLocalizer.typeIcon(notification.type),
                  size: 18,
                  color: typeColor,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  fontWeight: notification.isRead
                                      ? FontWeight.w600
                                      : FontWeight.w800,
                                  color: cs.onSurface,
                                ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (!notification.isRead)
                          Container(
                            width: 7,
                            height: 7,
                            margin: const EdgeInsetsDirectional.only(start: 6),
                            decoration: BoxDecoration(
                              color: cs.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      body,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontSize: 11.5,
                            color: cs.onSurfaceVariant,
                          ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      NotificationLocalizer.formatRelativeTime(
                        notification.createdAt,
                        l10n,
                      ),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            fontSize: 10,
                            color: cs.onSurfaceVariant.withValues(alpha: 0.8),
                          ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: l10n.deleteNotification,
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                icon: Icon(
                  Icons.close_rounded,
                  size: 16,
                  color: cs.onSurfaceVariant,
                ),
                onPressed: onDelete,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
