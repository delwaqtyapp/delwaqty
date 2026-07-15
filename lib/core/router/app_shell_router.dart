import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:delwaqty/shared/widgets/app_shell.dart';
import 'package:delwaqty/features/home/presentation/pages/home_page.dart';
import 'package:delwaqty/features/settings/presentation/pages/settings_page.dart';
import 'package:delwaqty/features/profile/presentation/pages/profile_page.dart';
import 'package:delwaqty/features/notifications/presentation/pages/notification_center_page.dart';
import 'package:delwaqty/features/expenses/presentation/pages/expenses_page.dart';
import 'package:delwaqty/features/expenses/presentation/pages/add_expense_page.dart';
import 'package:delwaqty/features/expenses/presentation/pages/expense_detail_page.dart';
import 'package:delwaqty/features/auth/presentation/pages/login_page.dart';
import 'package:delwaqty/features/auth/presentation/pages/register_page.dart';
import 'package:delwaqty/features/auth/presentation/pages/forgot_password_page.dart';
import 'package:delwaqty/features/splash/presentation/pages/splash_page.dart';
import 'package:delwaqty/features/onboarding/presentation/pages/onboarding_page.dart';
import 'package:delwaqty/features/welcome/presentation/pages/welcome_page.dart';
import 'package:delwaqty/features/categories/presentation/pages/categories_page.dart';
import 'package:delwaqty/features/categories/presentation/pages/add_category_page.dart';
import 'package:delwaqty/features/reports/presentation/pages/reports_page.dart';
import 'package:delwaqty/features/auth/domain/auth_state.dart';
import 'package:delwaqty/features/auth/presentation/auth_provider.dart';
import 'package:delwaqty/domain/entities/category.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'root');

final goRouterProvider = Provider<GoRouter>((ref) {
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

      final isSplash = state.matchedLocation == '/splash';
      final isOnboarding = state.matchedLocation == '/onboarding';
      final isWelcome = state.matchedLocation == '/welcome';
      final isAuthRoute = state.matchedLocation == '/login' ||
          state.matchedLocation == '/register' ||
          state.matchedLocation == '/forgot-password';

      if (isSplash || isOnboarding) return null;

      if (!isAuth && !isAuthRoute && !isWelcome) {
        return '/welcome';
      }
      if (isAuth && isAuthRoute) {
        return '/home';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        name: 'splash',
        builder: (context, state) => const SplashPage(),
      ),
      GoRoute(
        path: '/onboarding',
        name: 'onboarding',
        builder: (context, state) => const OnboardingPage(),
      ),
      GoRoute(
        path: '/welcome',
        name: 'welcome',
        builder: (context, state) => const WelcomePage(),
      ),
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: '/register',
        name: 'register',
        builder: (context, state) => const RegisterPage(),
      ),
      GoRoute(
        path: '/forgot-password',
        name: 'forgot-password',
        builder: (context, state) => const ForgotPasswordPage(),
      ),
      GoRoute(
        path: '/profile',
        name: 'profile',
        builder: (context, state) => const ProfilePage(),
      ),
      GoRoute(
        path: '/notifications',
        name: 'notifications',
        builder: (context, state) => const NotificationCenterPage(),
      ),
      GoRoute(
        path: '/categories',
        name: 'categories',
        builder: (context, state) => const CategoriesPage(),
      ),
      GoRoute(
        path: '/categories/add',
        name: 'add-category',
        builder: (context, state) {
          final category = state.extra as Category?;
          return AddCategoryPage(existingCategory: category);
        },
      ),
      GoRoute(
        path: '/reports',
        name: 'reports',
        builder: (context, state) => const ReportsPage(),
      ),
      GoRoute(
        path: '/expenses/add',
        name: 'add-expense',
        builder: (context, state) => const AddExpensePage(),
      ),
      GoRoute(
        path: '/expenses/:id/edit',
        name: 'edit-expense',
        builder: (context, state) => AddExpensePage(
          expenseId: state.pathParameters['id'],
        ),
      ),
      GoRoute(
        path: '/expenses/:id',
        name: 'expense-detail',
        builder: (context, state) => ExpenseDetailPage(
          expenseId: state.pathParameters['id']!,
        ),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return AppShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                name: 'home',
                builder: (context, state) => const HomePage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/expenses',
                name: 'expenses',
                builder: (context, state) => const ExpensesPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/settings',
                name: 'settings',
                builder: (context, state) => const SettingsPage(),
              ),
            ],
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text('Page not found: ${state.uri}'),
      ),
    ),
  );
});
