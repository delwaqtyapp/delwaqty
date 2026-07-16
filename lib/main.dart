import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:delwaqty/app/app.dart';
import 'package:delwaqty/config/firebase_config.dart';
import 'package:delwaqty/data/datasources/local/shared_preferences_service.dart';
import 'package:delwaqty/data/datasources/local/secure_storage_service.dart';
import 'package:delwaqty/data/repositories/auth_repository_impl.dart';
import 'package:delwaqty/data/repositories/user_repository_impl.dart';
import 'package:delwaqty/data/repositories/profile_repository_impl.dart';
import 'package:delwaqty/domain/usecases/auth/auth_usecases.dart';
import 'package:delwaqty/domain/usecases/user/get_user.dart';
import 'package:delwaqty/domain/usecases/profile/profile_usecases.dart';
import 'package:delwaqty/module_registry.dart';
import 'package:delwaqty/services/connectivity/connectivity_service.dart';
import 'package:delwaqty/services/supabase/supabase_initializer.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  final sharedPreferences = await SharedPreferences.getInstance();
  const secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  final sharedPrefsService = SharedPreferencesService(sharedPreferences);
  final secureStorageService = SecureStorageService(secureStorage);

  if (FirebaseConfig.isConfigured) {
    try {
      await Firebase.initializeApp(
        options: const FirebaseOptions(
          apiKey: '',
          appId: '',
          messagingSenderId: '',
          projectId: '',
        ),
      );
      if (FirebaseConfig.enableCrashlytics) {
        FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
      }
    } catch (e) {
      debugPrint('Firebase initialization failed: $e');
      debugPrint('App running without Firebase.');
    }
  }

  try {
    await SupabaseInitializer.initialize();
  } catch (e) {
    debugPrint('Supabase initialization failed: $e');
    debugPrint('App running without backend connectivity.');
  }

  final connectivityService = ConnectivityService();
  await connectivityService.initialize();

  registerAllModules();

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(sharedPrefsService),
        secureStorageServiceProvider.overrideWithValue(secureStorageService),
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
      child: const App(),
    ),
  );
}
