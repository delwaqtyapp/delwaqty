import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delwaqty/core/localization/locale_provider.dart';
import 'package:delwaqty/core/deep_link/deep_link_resolver.dart';
import 'package:delwaqty/core/router/app_router.dart';
import 'package:delwaqty/core/theme/app_theme.dart';
import 'package:delwaqty/core/theme/theme_mode_provider.dart';
import 'package:delwaqty/features/_shared/auth/presentation/auth_provider.dart';
import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:delwaqty/services/deep_link/deep_link_service.dart';
import 'package:delwaqty/services/push_notification/push_notification_service.dart';

class App extends ConsumerStatefulWidget {
  const App({super.key});

  @override
  ConsumerState<App> createState() => _AppState();
}

class _AppState extends ConsumerState<App> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final authNotifier = ref.read(authStateProvider.notifier);
      authNotifier.startAuthListener();
      authNotifier.checkAuthStatus();
      ref.read(pushNotificationServiceProvider).initialize();
      _startDeepLinkListener();
    });
  }

  void _startDeepLinkListener() {
    final service = ref.read(deepLinkServiceProvider);
    service.start();
    service.routes.listen((route) {
      if (route == DeepLinkRoute.loginCallback) {
        // supabase_flutter already exchanges the PKCE code; re-resolve the
        // session so the router lands the user on the correct page.
        ref.read(authStateProvider.notifier).checkAuthStatus();
      }
    });
    // Cold start: the platform delivers the launching URI through the stream
    // on mobile, but guard the process-dead case explicitly.
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
    final goRouter = ref.watch(goRouterProvider);
    final themeMode = ref.watch(themeModeProvider);
    final locale = ref.watch(localeProvider);

    return MaterialApp.router(
      title: 'Delwaqty',
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
