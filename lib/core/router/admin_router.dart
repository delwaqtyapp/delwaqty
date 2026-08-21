import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:delwaqty/core/module/feature_registry.dart';
import 'package:delwaqty/core/auth/admin_access.dart';
import 'package:delwaqty/features/_shared/auth/domain/auth_state.dart';
import 'package:delwaqty/features/_shared/auth/presentation/auth_provider.dart';
import 'package:delwaqty/features/_shared/device_lock/device_lock_provider.dart';
import 'package:delwaqty/features/_shared/device_lock/presentation/device_unlock_page.dart';
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
      final isAdmin = isAuth &&
          authState.whenOrNull(
                authenticated: (user) => user.isAdmin,
              ) ==
              true;

      final isAuthRoute =
          state.matchedLocation == '/login' ||
          state.matchedLocation == '/register' ||
          state.matchedLocation == '/forgot-password';

      // App Lock gate: re-verify on every cold start when a device account
      // (locally stored credentials) exists.
      final lock = ref.read(deviceLockProvider);
      if (lock.hasDeviceAccount && !lock.unlocked) {
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
