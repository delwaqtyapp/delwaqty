import 'package:flutter/widgets.dart';
import 'package:delwaqty/core/config/app_mode_provider.dart';
import 'package:delwaqty/core/router/app_router.dart';
import 'package:delwaqty/core/router/admin_router.dart';
import 'package:delwaqty/driver/app_router.dart';
import 'package:delwaqty/provider/app_router.dart';

/// Returns the mounted navigator context for the CURRENT flavor.
///
/// Each flavor binds its go_router to a different navigator key:
/// customer -> rootNavigatorKey, admin -> adminNavigatorKey,
/// driver -> driverRootNavigatorKey, provider -> providerRootNavigatorKey.
/// Anything shared (push notifications, deep links, call alerts) must
/// resolve the active key; hard-coding the customer key made notification
/// taps and FCM-open routing dead in the other three apps because
/// `currentContext` was permanently null.
BuildContext? activeNavigatorContext(AppFlavor flavor) {
  switch (flavor) {
    case AppFlavor.admin:
      return adminNavigatorKey.currentContext;
    case AppFlavor.driver:
      return driverRootNavigatorKey.currentContext;
    case AppFlavor.provider:
      return providerRootNavigatorKey.currentContext;
    case AppFlavor.customer:
      return rootNavigatorKey.currentContext;
  }
}