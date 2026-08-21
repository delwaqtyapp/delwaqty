import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:delwaqty/driver/app.dart';
import 'package:delwaqty/config/app_config.dart';
import 'package:delwaqty/config/config_validator.dart';
import 'package:delwaqty/config/firebase_config.dart';
import 'package:delwaqty/data/datasources/local/shared_preferences_service.dart';
import 'package:delwaqty/data/datasources/local/hive_cache_service.dart';
import 'package:delwaqty/data/repositories/auth_repository_impl.dart';
import 'package:delwaqty/data/repositories/user_repository_impl.dart';
import 'package:delwaqty/data/repositories/profile_repository_impl.dart';
import 'package:delwaqty/domain/usecases/auth/auth_usecases.dart';
import 'package:delwaqty/domain/usecases/user/get_user.dart';
import 'package:delwaqty/domain/usecases/profile/profile_usecases.dart';
import 'package:delwaqty/driver/module_registry.dart';
import 'package:delwaqty/services/connectivity/connectivity_service.dart';
import 'package:delwaqty/services/supabase/supabase_initializer.dart';
import 'package:delwaqty/services/push_notification/push_notification_service.dart';
import 'package:delwaqty/services/logger/app_logger.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

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
            '',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
          ),
        ),
      ),
    );
  };

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  if (kDebugMode) AppConfig.logConfig();
  ConfigValidator.validateOrThrow();

  final results = await Future.wait([
    SharedPreferences.getInstance(),
    _initFirebase(),
    _initSupabase(),
    Hive.initFlutter(),
  ]);

  final sharedPreferences = results[0] as SharedPreferences;

  final sharedPrefsService = SharedPreferencesService(sharedPreferences);

  final hiveCacheService = HiveCacheService(AppLogger());
  await hiveCacheService.initialize();

  final connectivityService = ConnectivityService();
  await connectivityService.initialize();

  if (FirebaseConfig.isConfigured) {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  }

  registerDriverModules();

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(sharedPrefsService),
        authRepositoryProvider.overrideWith(
          (ref) => ref.watch(authRepositoryImplProvider),
        ),
        userRepositoryProvider.overrideWith(
          (ref) => ref.watch(userRepositoryImplProvider),
        ),
        profileRepositoryProvider.overrideWith(
          (ref) => ref.watch(profileRepositoryImplProvider),
        ),
      ],
      child: const DriverApp(),
    ),
  );
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
    );
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
    await SupabaseInitializer.initialize();
  } catch (e) {
    debugPrint('Supabase initialization failed: $e');
    debugPrint('App running without backend connectivity.');
  }
}
