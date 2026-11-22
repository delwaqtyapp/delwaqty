import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:delwaqty/core/module/feature_registry.dart';
import 'package:delwaqty/core/auth/admin_access.dart';
import 'package:delwaqty/features/_shared/auth/domain/auth_state.dart';
import 'package:delwaqty/features/_shared/auth/presentation/auth_provider.dart';
import 'package:delwaqty/features/_shared/device_lock/device_lock_provider.dart';
import 'package:delwaqty/features/_shared/device_lock/presentation/device_unlock_page.dart';
import 'package:delwaqty/features/_shared/notifications/presentation/pages/notification_center_page.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

final GlobalKey<NavigatorState> adminNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'admin-root',
);

final adminGoRouterProvider = Provider<GoRouter>((ref) {
  final registry = FeatureRegistry.instance;
  final refreshNotifier = ValueNotifier<int>(0);

  ref.listen<AuthState>(authStateProvider, (previous, next) {
    refreshNotifier.value++;
  });

  ref.listen(deviceLockProvider, (previous, next) {
    refreshNotifier.value++;
  });

  ref.onDispose(refreshNotifier.dispose);

  return GoRouter(
    navigatorKey: adminNavigatorKey,
    initialLocation: '/admin',
    refreshListenable: refreshNotifier,
    redirect: (context, state) {
      final authState = ref.read(authStateProvider);
      final isAuth = authState is AuthAuthenticated;
      final isAdmin =
          isAuth &&
          authState.whenOrNull(authenticated: (user) => user.isAdmin) == true;

      final isAuthRoute =
          state.matchedLocation == '/login' ||
          state.matchedLocation == '/register' ||
          state.matchedLocation == '/forgot-password';

      // App Lock gate: re-verify on every cold start when a device account
      // (locally stored credentials) exists.
      final lock = ref.read(deviceLockProvider);
      // App Lock is a device-credential gate; it does not apply to web
      // sessions (B01: the gate was locking admin web users out).
      if (!kIsWeb && lock.hasDeviceAccount && !lock.unlocked) {
        if (state.matchedLocation != '/device-unlock' && !isAuthRoute) {
          return '/device-unlock';
        }
        return null;
      }

      if (!isAuth && !isAuthRoute) return '/login';
      if (isAuth && isAuthRoute) return '/admin';
      if (isAuth && !isAdmin) return '/login';
      return null;
    },
    routes: [
      ...registry.allStandaloneRoutes,
      // The admin router wires only standalone routes; module shell routes
      // like /notifications must be registered explicitly or notification
      // taps (push deep links, bell menu) hit the error page.
      GoRoute(
        path: '/notifications',
        name: 'notifications',
        builder: (context, state) => const NotificationCenterPage(),
      ),
      GoRoute(
        path: '/device-unlock',
        builder: (context, state) => const DeviceUnlockPage(),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text(
          '${AppLocalizations.of(context).pageNotFound}: ${state.uri}',
        ),
      ),
    ),
  );
});
