import 'package:delwaqty/core/config/build_channel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delwaqty/core/bootstrap/backend_bootstrap.dart';
import 'package:delwaqty/core/config/app_mode_provider.dart';
import 'package:delwaqty/core/router/admin_router.dart';
import 'package:delwaqty/core/theme/app_theme.dart';
import 'package:delwaqty/core/theme/theme_mode_provider.dart';
import 'package:delwaqty/features/_shared/auth/presentation/auth_provider.dart';
import 'package:delwaqty/features/_shared/device_lock/device_lock_provider.dart';
import 'package:delwaqty/core/localization/admin_locale_provider.dart';
import 'package:delwaqty/features/admin/support_chat/presentation/chat_providers.dart';
import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:delwaqty/services/ota/ota_update_dialog.dart';
import 'package:delwaqty/services/push_notification/push_notification_service.dart';

import 'dart:async';

class AppAdmin extends ConsumerStatefulWidget {
  const AppAdmin({super.key});

  @override
  ConsumerState<AppAdmin> createState() => _AppAdminState();
}

class _AppAdminState extends ConsumerState<AppAdmin>
    with WidgetsBindingObserver {
  late final AuthStateNotifier _authNotifier;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _authNotifier = ref.read(authStateProvider.notifier);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      try {
        await ref.read(deviceLockProvider.notifier).init();
      } catch (e) {
        debugPrint('Device lock init failed: $e');
      }

      if (!mounted) return;

      try {
        await ref
            .read(backendBootstrapProvider)
            .ready
            .timeout(const Duration(seconds: 20));
      } catch (_) {}

      if (!mounted) return;

      try {
        _authNotifier.startAuthListener();
      } catch (e) {
        debugPrint('Auth listener start failed: $e');
      }
      unawaited(_authNotifier.checkAuthStatus());
      unawaited(ref.read(pushNotificationServiceProvider).initialize());
      ref.read(chatCallAlertServiceProvider);

      unawaited(_checkOtaUpdate());
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_checkOtaUpdate());
  }

  Future<void> _checkOtaUpdate() async {
    if (kPlayBuild || !mounted) return;
    await Future<void>.delayed(const Duration(seconds: 4));
    if (!mounted) return;
    try {
      final flavor = ref.read(appFlavorProvider);
      await showOtaUpdateIfAvailable(flavor: flavor);
    } catch (e) {
      debugPrint('OTA check failed: $e');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _authNotifier.stopAuthListener();
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
