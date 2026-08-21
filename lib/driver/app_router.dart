import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:delwaqty/core/module/feature_registry.dart';
import 'package:delwaqty/features/_shared/auth/domain/auth_state.dart';
import 'package:delwaqty/features/_shared/auth/presentation/auth_provider.dart';
import 'package:delwaqty/features/_shared/device_lock/device_lock_provider.dart';
import 'package:delwaqty/features/_shared/device_lock/presentation/device_unlock_page.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

final GlobalKey<NavigatorState> driverRootNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'driver-root',
);

final driverGoRouterProvider = Provider<GoRouter>((ref) {
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
    navigatorKey: driverRootNavigatorKey,
    initialLocation: '/splash',
    refreshListenable: refreshNotifier,
    redirect: (context, state) {
      final authState = ref.read(authStateProvider);
      final isAuth = authState is AuthAuthenticated;
      final isGuest = authState is AuthGuest;
      final isPendingVerification =
          authState is AuthEmailConfirmationRequired ||
          authState is AuthPhoneVerification;
      final isVerificationPending = authState is AuthPendingVerification;
      final canAccess = isAuth || isGuest || isVerificationPending;

      final isSplash = state.matchedLocation == '/splash';
      final isOnboarding = state.matchedLocation == '/onboarding';
      final isWelcome = state.matchedLocation == '/welcome';
      final isAuthRoute =
          state.matchedLocation == '/login' ||
          state.matchedLocation == '/register' ||
          state.matchedLocation == '/forgot-password';
      final isVerificationPendingRoute =
          state.matchedLocation == '/pending-verification';

      if (isSplash || isOnboarding) return null;

      final lock = ref.read(deviceLockProvider);
      if (lock.hasDeviceAccount && !lock.unlocked) {
        if (state.matchedLocation != '/device-unlock' && !isAuthRoute) {
          return '/device-unlock';
        }
        return null;
      }

      if (isVerificationPending &&
          !isVerificationPendingRoute &&
          !isAuthRoute) {
        return '/pending-verification';
      }

      if (isPendingVerification && !isAuthRoute) {
        return '/register';
      }

      if (!canAccess && !isAuthRoute && !isWelcome) {
        return '/welcome';
      }
      if (isAuth && isAuthRoute) {
        return '/driver';
      }
      return null;
    },
    routes: [
      ...registry.allStandaloneRoutes,
      if (registry.navModules.isNotEmpty) registry.buildShellRoute(),
      ...registry.allShellSubRoutes,
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
