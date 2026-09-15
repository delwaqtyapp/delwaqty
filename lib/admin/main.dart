import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:delwaqty/admin/app.dart';
import 'package:delwaqty/config/app_config.dart';
import 'package:delwaqty/config/config_validator.dart';
import 'package:delwaqty/config/firebase_config.dart';
import 'package:delwaqty/core/config/app_mode_provider.dart';
import 'package:delwaqty/core/bootstrap/backend_bootstrap.dart';
import 'package:delwaqty/core/bootstrap/startup_error_page.dart';
import 'package:delwaqty/data/datasources/local/shared_preferences_service.dart';
import 'package:delwaqty/data/datasources/local/hive_cache_service.dart';
import 'package:delwaqty/data/repositories/auth_repository_impl.dart';
import 'package:delwaqty/data/repositories/user_repository_impl.dart';
import 'package:delwaqty/data/repositories/profile_repository_impl.dart';
import 'package:delwaqty/domain/usecases/auth/auth_usecases.dart';
import 'package:delwaqty/domain/usecases/user/get_user.dart';
import 'package:delwaqty/domain/usecases/profile/profile_usecases.dart';
import 'package:delwaqty/admin/module_registry.dart';
import 'package:delwaqty/core/theme/theme_mode_provider.dart';
import 'package:delwaqty/services/connectivity/connectivity_service.dart';
import 'package:delwaqty/services/supabase/supabase_initializer.dart';
import 'package:delwaqty/shared/notifications/notification_route_resolver.dart';
import 'package:delwaqty/services/push_notification/push_notification_service.dart';
import 'package:delwaqty/services/logger/app_logger.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  NotificationRouteResolver.appContext = AppContext.admin;

  FlutterError.onError = (details) {
    debugPrint('FlutterError: ${details.exception}');
    debugPrint(details.stack.toString());
  };

  ErrorWidget.builder = (details) {
    return Material(
      color: const Color(0xFF241E44),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            '${details.exception}',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.9)),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  };

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // ── Validate configuration before any service init ──────────
  if (kDebugMode) AppConfig.logConfig();
  final configResult = ConfigValidator.validate();
  if (configResult.warnings.isNotEmpty && kDebugMode) {
    for (final warning in configResult.warnings) {
      debugPrint('⚠ Config warning: $warning');
    }
  }

  if (configResult.hasErrors) {
    debugPrint(configResult.toString());
    runApp(
      ProviderScope(child: StartupErrorPage(result: configResult)),
    );
    return;
  }

  // ── Local services (fast, no network) ───────────────────────
  SharedPreferencesService? sharedPrefsService;
  final connectivityService = ConnectivityService();
  try {
    final sharedPreferences = await SharedPreferences.getInstance();
    sharedPrefsService = SharedPreferencesService(sharedPreferences);

    await Hive.initFlutter();
    final hiveCacheService = HiveCacheService(AppLogger());
    await hiveCacheService.initialize();
  } catch (e) {
    debugPrint('Local startup initialization failed: $e');
  }

  try {
    registerAdminModules();
  } catch (e) {
    debugPrint('Module registration failed: $e');
  }

  // ── Backends initialize in the background; the first frame is NOT
  //    gated on the network, so the splash always clears. ─────────
  final backendBootstrap = BackendBootstrap();
  unawaited(_bootstrapBackends(backendBootstrap, connectivityService));

  runApp(
    ProviderScope(
      overrides: [
        isAdminAppProvider.overrideWithValue(true),
        if (sharedPrefsService != null)
          sharedPreferencesProvider.overrideWithValue(sharedPrefsService),
        connectivityServiceProvider.overrideWithValue(connectivityService),
        authRepositoryProvider.overrideWith(
          (ref) => ref.watch(authRepositoryImplProvider),
        ),
        userRepositoryProvider.overrideWith(
          (ref) => ref.watch(userRepositoryImplProvider),
        ),
        profileRepositoryProvider.overrideWith(
          (ref) => ref.watch(profileRepositoryImplProvider),
        ),
        themeModeProvider.overrideWith(() => AdminThemeModeNotifier()),
        backendBootstrapProvider.overrideWithValue(backendBootstrap),
      ],
      child: const AppAdmin(),
    ),
  );
}

Future<void> _bootstrapBackends(
  BackendBootstrap bootstrap,
  ConnectivityService connectivityService,
) async {
  try {
    if (FirebaseConfig.isConfigured) {
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    }

    await Future.wait<void>([
      _initFirebase(),
      _initSupabase(),
      connectivityService.initialize().timeout(const Duration(seconds: 6)),
    ]);
  } catch (e) {
    debugPrint('Backend bootstrap gave up: $e');
  } finally {
    bootstrap.complete();
  }
}

Future<void> _initFirebase() async {
  if (!FirebaseConfig.isConfigured) return;
  try {
    await Firebase.initializeApp(
      options: FirebaseOptions(
        apiKey: FirebaseConfig.apiKey,
        appId: FirebaseConfig.androidAppId,
        messagingSenderId: FirebaseConfig.messagingSenderId,
        projectId: FirebaseConfig.projectId,
        storageBucket: FirebaseConfig.storageBucket,
      ),
    ).timeout(const Duration(seconds: 10));
    if (FirebaseConfig.enableCrashlytics) {
      FlutterError.onError =
          FirebaseCrashlytics.instance.recordFlutterFatalError;
    }
  } catch (e) {
    debugPrint('Firebase initialization failed: $e');
    debugPrint('App running without Firebase.');
  }
}

Future<void> _initSupabase() async {
  try {
    await SupabaseInitializer.initialize()
        .timeout(const Duration(seconds: 10));
  } catch (e) {
    debugPrint('Supabase initialization failed: $e');
    debugPrint('App running without backend connectivity.');
  }
}