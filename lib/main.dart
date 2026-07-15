import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:delwaqty/app/app.dart';
import 'package:delwaqty/core/constants/api_constants.dart';
import 'package:delwaqty/data/datasources/local/shared_preferences_service.dart';
import 'package:delwaqty/data/datasources/local/secure_storage_service.dart';
import 'package:delwaqty/data/repositories/auth_repository_impl.dart';
import 'package:delwaqty/data/repositories/user_repository_impl.dart';
import 'package:delwaqty/data/repositories/profile_repository_impl.dart';
import 'package:delwaqty/domain/usecases/auth/auth_usecases.dart';
import 'package:delwaqty/domain/usecases/user/get_user.dart';
import 'package:delwaqty/domain/usecases/profile/profile_usecases.dart';
import 'package:delwaqty/services/connectivity/connectivity_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

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

  bool supabaseInitialized = false;

  if (ApiConstants.baseUrl.isEmpty || ApiConstants.supabaseAnonKey.isEmpty) {
    debugPrint(
      'WARNING: Supabase credentials not provided. '
      'Run with --dart-define=API_BASE_URL=... --dart-define=SUPABASE_ANON_KEY=...',
    );
  } else {
    try {
      await sb.Supabase.initialize(
        url: ApiConstants.baseUrl,
        publishableKey: ApiConstants.supabaseAnonKey,
      );
      supabaseInitialized = true;
    } catch (e) {
      debugPrint('Supabase initialization failed: $e');
    }
  }

  if (!supabaseInitialized) {
    debugPrint('App running without backend connectivity.');
  }

  final connectivityService = ConnectivityService();
  await connectivityService.initialize();

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
