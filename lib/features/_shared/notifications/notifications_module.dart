import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:delwaqty/core/module/feature_module.dart';
import 'package:delwaqty/domain/entities/app_notification.dart';
import 'package:delwaqty/domain/repositories/notification_repository.dart';
import 'package:delwaqty/data/repositories/supabase_notification_repository_impl.dart';
import 'package:delwaqty/features/_shared/notifications/presentation/pages/notification_center_page.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return ref.watch(supabaseNotificationRepositoryImplProvider);
});

final notificationsProvider = FutureProvider.autoDispose<List<AppNotification>>(
  (ref) async {
    final repo = ref.watch(notificationRepositoryProvider);
    return repo.getNotifications();
  },
);

final unreadCountProvider = FutureProvider.autoDispose<int>((ref) async {
  final repo = ref.watch(notificationRepositoryProvider);
  return repo.getUnreadCount();
});

final unreadCountStreamProvider = StreamProvider<int>((ref) {
  final controller = StreamController<int>();

  Future<void> check() async {
    try {
      final repo = ref.read(notificationRepositoryProvider);
      final count = await repo.getUnreadCount();
      if (!controller.isClosed) controller.add(count);
    } catch (_) {
      if (!controller.isClosed) controller.add(0);
    }
  }

  check();

  final sub = Stream.periodic(const Duration(minutes: 1), (_) => null).listen(
    (_) => check(),
  );

  ref.onDispose(() {
    sub.cancel();
    controller.close();
  });

  return controller.stream;
});

class NotificationsModule extends FeatureModule {
  @override
  String get id => 'notifications';

  @override
  String name(BuildContext context) =>
      AppLocalizations.of(context).notifications;

  @override
  IconData? get icon => Icons.notifications_outlined;

  @override
  bool get isNavModule => false;

  @override
  int get navPriority => 55;

  @override
  Set<ModuleCapability> get capabilities => {ModuleCapability.hasNotifications};

  @override
  List<RouteBase> get shellSubRoutes => [
    GoRoute(
      path: '/notifications',
      name: 'notifications',
      builder: (context, state) => const NotificationCenterPage(),
    ),
  ];

  @override
  Stream<int>? badgeStream(Ref ref) {
    return ref.watch(unreadCountStreamProvider).whenOrNull(
          data: (count) => Stream.value(count),
        );
  }

  @override
  List<DrawerEntry> get drawerEntries => [
    DrawerEntry(
      id: 'notifications',
      label: (ctx) => AppLocalizations.of(ctx).notifications,
      icon: Icons.notifications_outlined,
      badgeStream: (ref) {
        final controller = StreamController<int>();

        Future<void> check() async {
          try {
            final repo = ref.read(notificationRepositoryProvider);
            final count = await repo.getUnreadCount();
            if (!controller.isClosed) controller.add(count);
          } catch (_) {
            if (!controller.isClosed) controller.add(0);
          }
        }

        check();

        final sub =
            Stream.periodic(const Duration(minutes: 1), (_) => null).listen(
          (_) => check(),
        );

        ref.onDispose(() {
          sub.cancel();
          controller.close();
        });

        return controller.stream;
      },
      onTap: (ctx, ref) {
        Navigator.of(ctx).pop();
        ctx.push('/notifications');
      },
    ),
  ];
}
