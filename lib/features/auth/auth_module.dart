import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:delwaqty/core/module/feature_module.dart';
import 'package:delwaqty/features/auth/presentation/pages/login_page.dart';
import 'package:delwaqty/features/auth/presentation/pages/register_page.dart';
import 'package:delwaqty/features/auth/presentation/pages/forgot_password_page.dart';

class AuthModule extends FeatureModule {
  @override
  String get id => 'auth';

  @override
  String name(BuildContext context) => 'Auth';

  @override
  IconData? get icon => Icons.login;

  @override
  bool get isNavModule => false;

  @override
  int get navPriority => 3;

  @override
  List<RouteBase> get standaloneRoutes => [
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
  ];
}
