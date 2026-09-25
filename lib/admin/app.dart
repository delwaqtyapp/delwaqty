import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delwaqty/core/bootstrap/backend_bootstrap.dart';
import 'package:delwaqty/core/router/admin_router.dart';
import 'package:delwaqty/core/theme/app_theme.dart';
import 'package:delwaqty/core/theme/theme_mode_provider.dart';
import 'package:delwaqty/features/_shared/auth/presentation/auth_provider.dart';
import 'package:delwaqty/features/_shared/device_lock/device_lock_provider.dart';
import 'package:delwaqty/core/localization/admin_locale_provider.dart';
import 'package:delwaqty/features/admin/support_chat/presentation/chat_providers.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

class AppAdmin extends ConsumerStatefulWidget {
  const AppAdmin({super.key});

  @override
  ConsumerState<AppAdmin> createState() => _AppAdminState();
}

class _AppAdminState extends ConsumerState<AppAdmin> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      try {
        await ref.read(deviceLockProvider.notifier).init();
      } catch (e) {
        debugPrint('Device lock init failed: $e');
      }

      if (!mounted) return;

      try {
        await ref.read(backendBootstrapProvider).ready
            .timeout(const Duration(seconds: 20));
      } catch (_) {}

      if (!mounted) return;

      final authNotifier = ref.read(authStateProvider.notifier);
      try {
        authNotifier.startAuthListener();
      } catch (e) {
        debugPrint('Auth listener start failed: $e');
      }
      authNotifier.checkAuthStatus();
      ref.read(chatCallAlertServiceProvider);
    });
  }

  @override
  void dispose() {
    ref.read(authStateProvider.notifier).stopAuthListener();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final goRouter = ref.watch(adminGoRouterProvider);
    final themeMode = ref.watch(themeModeProvider);
    final locale = ref.watch(adminLocaleProvider);

    return MaterialApp.router(
      title: 'DelwaQty Admin',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme(),
      darkTheme: AppTheme.darkTheme(),
      themeMode: themeMode,
      routerConfig: goRouter,
      locale: locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en'), Locale('ar')],
    );
  }
}
