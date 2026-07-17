import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:delwaqty/core/module/feature_registry.dart';
import 'package:delwaqty/features/auth/domain/auth_state.dart';
import 'package:delwaqty/features/auth/presentation/auth_provider.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'root',
);

final goRouterProvider = Provider<GoRouter>((ref) {
  final registry = FeatureRegistry.instance;
  final refreshNotifier = ValueNotifier<int>(0);

  ref.listen<AuthState>(authStateProvider, (previous, next) {
    refreshNotifier.value++;
  });

  ref.onDispose(refreshNotifier.dispose);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/splash',
    refreshListenable: refreshNotifier,
    redirect: (context, state) {
      final authState = ref.read(authStateProvider);
      final isAuth = authState is AuthAuthenticated;
      final isGuest = authState is AuthGuest;
      final isPendingVerification =
          authState is AuthEmailConfirmationRequired ||
          authState is AuthPhoneVerification;
      final canAccess = isAuth || isGuest || isPendingVerification;

      final isSplash = state.matchedLocation == '/splash';
      final isOnboarding = state.matchedLocation == '/onboarding';
      final isWelcome = state.matchedLocation == '/welcome';
      final isAuthRoute =
          state.matchedLocation == '/login' ||
          state.matchedLocation == '/register' ||
          state.matchedLocation == '/forgot-password';

      final restrictedRoutes = ['/market/checkout', '/market/orders', '/market/favorites'];
      final isRestricted = restrictedRoutes.any(
        (r) => state.matchedLocation.startsWith(r),
      );

      final isAdminRoute = state.matchedLocation.startsWith('/admin');
      final isAdmin = isAuth &&
          authState.whenOrNull(
                authenticated: (user) => user.role == 'admin' || user.role == 'owner',
              ) ==
              true;

      if (isSplash || isOnboarding) return null;

      if (isPendingVerification && !isAuthRoute) {
        return '/register';
      }

      if (!canAccess && !isAuthRoute && !isWelcome) {
        return '/welcome';
      }
      if (isGuest && isRestricted) {
        return '/login';
      }
      if (isAdminRoute && !isAdmin) {
        return '/home';
      }
      if (isAuth && isAuthRoute) {
        return '/home';
      }
      return null;
    },
    routes: [
      ...registry.allStandaloneRoutes,
      registry.buildShellRoute(),
      ...registry.allShellSubRoutes,
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text('${AppLocalizations.of(context).pageNotFound}: ${state.uri}'),
      ),
    ),
  );
});
