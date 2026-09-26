import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delwaqty/core/bootstrap/backend_bootstrap.dart';
import 'package:delwaqty/core/config/app_mode_provider.dart';
import 'package:delwaqty/core/localization/locale_provider.dart';
import 'package:delwaqty/core/deep_link/deep_link_resolver.dart';
import 'package:delwaqty/provider/app_router.dart';
import 'package:delwaqty/core/theme/app_theme.dart';
import 'package:delwaqty/core/theme/theme_mode_provider.dart';
import 'package:delwaqty/features/_shared/auth/presentation/auth_provider.dart';
import 'package:delwaqty/features/_shared/device_lock/device_lock_provider.dart';
import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:delwaqty/services/deep_link/deep_link_service.dart';
import 'package:delwaqty/services/ota/ota_update_dialog.dart';
import 'package:delwaqty/services/push_notification/push_notification_service.dart';

class ProviderApp extends ConsumerStatefulWidget {
  const ProviderApp({super.key});

  @override
  ConsumerState<ProviderApp> createState() => _ProviderAppState();
}

class _ProviderAppState extends ConsumerState<ProviderApp> {
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
      ref.read(pushNotificationServiceProvider).initialize();
      _startDeepLinkListener();
      _checkOtaUpdate();
    });
  }

  Future<void> _checkOtaUpdate() async {
    if (!mounted) return;
    await Future<void>.delayed(const Duration(seconds: 4));
    if (!mounted) return;
    try {
      final flavor = ref.read(appFlavorProvider);
      await showOtaUpdateIfAvailable(flavor: flavor);
    } catch (e) {
      debugPrint('OTA check failed: $e');
    }
  }

  void _startDeepLinkListener() {
    final service = ref.read(deepLinkServiceProvider);
    service.start();
    service.routes.listen((route) {
      if (route == DeepLinkRoute.loginCallback) {
        ref.read(authStateProvider.notifier).checkAuthStatus();
      }
    });
    Future<void>.delayed(const Duration(milliseconds: 800), () async {
      final route = await service.initialRoute;
      if (route == DeepLinkRoute.loginCallback && mounted) {
        ref.read(authStateProvider.notifier).checkAuthStatus();
      }
    });
  }

  @override
  void dispose() {
    ref.read(authStateProvider.notifier).stopAuthListener();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final goRouter = ref.watch(providerGoRouterProvider);
    final themeMode = ref.watch(themeModeProvider);
    final locale = ref.watch(localeProvider);

    return MaterialApp.router(
      title: 'Delwaqty Provider',
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
