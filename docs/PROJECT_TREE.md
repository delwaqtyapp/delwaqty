# Project Tree

## Full Directory Structure

```
delwaqty/
├── android/                          # Android platform project
├── assets/                           # Asset directory (currently empty)
├── build/                            # Build output (git-ignored)
├── ios/                              # iOS platform project
├── lib/                              # Main Dart source code
├── linux/                            # Linux desktop platform
├── macos/                            # macOS desktop platform
├── test/                             # Unit and widget tests
├── web/                              # Web platform
├── windows/                          # Windows desktop platform
├── docs/                             # Project documentation
├── l10n.yaml                         # Localization generation config
├── pubspec.yaml                      # Project dependencies and metadata
├── analysis_options.yaml             # Dart analyzer and lint rules
├── pubspec.lock                      # Locked dependency versions
└── delwaqty.iml                      # IntelliJ module file
```

## Root Configuration Files

| File | Purpose |
|---|---|
| `pubspec.yaml` | Defines SDK constraint (^3.12.2), all dependencies, Flutter settings, `generate: true` for localization |
| `analysis_options.yaml` | Includes `package:flutter_lints/flutter.yaml`, excludes generated files, enables 22 lint rules |
| `l10n.yaml` | Configures ARB-based localization: `lib/l10n/` directory, `app_en.arb` template, `AppLocalizations` output class |

## `lib/` — Source Code

```
lib/
├── main.dart
├── app/
│   └── app.dart
├── core/
│   ├── constants/
│   │   ├── api_constants.dart
│   │   ├── app_constants.dart
│   │   └── storage_keys.dart
│   ├── errors/
│   │   ├── error_handler.dart
│   │   ├── exceptions.dart
│   │   ├── failures.dart
│   │   └── failures.freezed.dart
│   ├── extensions/
│   │   ├── context_extensions.dart
│   │   ├── date_extensions.dart
│   │   └── string_extensions.dart
│   ├── localization/
│   │   └── locale_provider.dart
│   ├── router/
│   │   └── app_shell_router.dart
│   ├── theme/
│   │   ├── app_colors.dart
│   │   ├── app_text_styles.dart
│   │   ├── app_theme.dart
│   │   └── theme_mode_provider.dart
│   └── utils/
│       └── validators.dart
├── data/
│   ├── datasources/
│   │   ├── local/
│   │   │   ├── secure_storage_service.dart
│   │   │   └── shared_preferences_service.dart
│   │   └── remote/
│   │       ├── supabase_auth_data_source.dart
│   │       └── supabase_profile_data_source.dart
│   ├── models/
│   │   ├── user_model.dart
│   │   ├── user_model.freezed.dart
│   │   └── user_model.g.dart
│   └── repositories/
│       ├── auth_repository_impl.dart
│       ├── profile_repository_impl.dart
│       └── user_repository_impl.dart
├── domain/
│   ├── entities/
│   │   ├── user.dart
│   │   ├── user.freezed.dart
│   │   └── user.g.dart
│   ├── repositories/
│   │   ├── auth_repository.dart
│   │   ├── profile_repository.dart
│   │   └── user_repository.dart
│   └── usecases/
│       ├── auth/
│       │   └── auth_usecases.dart
│       ├── profile/
│       │   └── profile_usecases.dart
│       └── user/
│           └── get_user.dart
├── features/
│   ├── auth/
│   │   ├── domain/
│   │   │   ├── auth_state.dart
│   │   │   └── auth_state.freezed.dart
│   │   └── presentation/
│   │       ├── auth_provider.dart
│   │       └── pages/
│   │           ├── forgot_password_page.dart
│   │           ├── login_page.dart
│   │           └── register_page.dart
│   ├── home/
│   │   └── presentation/
│   │       └── pages/
│   │           └── home_page.dart
│   └── settings/
│       └── presentation/
│           └── pages/
│               └── settings_page.dart
├── l10n/
│   ├── app_ar.arb
│   ├── app_en.arb
│   ├── app_localizations.dart
│   ├── app_localizations_ar.dart
│   └── app_localizations_en.dart
├── services/
│   ├── fcm/
│   │   └── fcm_service.dart
│   ├── logger/
│   │   └── app_logger.dart
│   └── supabase/
│       └── supabase_service.dart
└── shared/
    └── widgets/
        ├── app_button.dart
        ├── app_shell.dart
        ├── app_text_field.dart
        └── error_widget.dart
```

## File Explanations

### Entry Points

| File | Description |
|---|---|
| `lib/main.dart` | Application entry point. Initializes SharedPreferences, SecureStorage, and Supabase. Wraps the app in a `ProviderScope` with dependency overrides. Sets portrait orientation. |
| `lib/app/app.dart` | Root `ConsumerStatefulWidget`. Watches theme mode, locale, and GoRouter providers. Triggers `checkAuthStatus()` on init. Returns `MaterialApp.router` with localization delegates. |

### Core — `lib/core/`

| File | Description |
|---|---|
| `constants/api_constants.dart` | Compile-time environment variables for Supabase URL and anon key. API version path. Values come from `--dart-define` at build time. |
| `constants/app_constants.dart` | App-wide constants: app name, HTTP timeouts (30s), pagination page size (20). |
| `constants/storage_keys.dart` | String key constants for SharedPreferences and SecureStorage (accessToken, refreshToken, locale, themeMode, userId, onboardingComplete). |
| `errors/exceptions.dart` | Sealed `AppException` hierarchy: `ServerException`, `CacheException`, `NetworkException`, `AuthException`, `UnexpectedException`. Each carries a message string. |
| `errors/failures.dart` | Freezed union `Failure` with 7 variants: Server, Cache, Network, Auth, Unexpected, NotFound, Validation. Each carries a message string. Used for type-safe error representation. |
| `errors/error_handler.dart` | `handleException(Object) → Failure` function. Maps `AppException` subtypes to `Failure` variants. Used by presentation layer to convert exceptions to typed failures. |
| `extensions/context_extensions.dart` | Extension on `BuildContext`: theme accessors, screen size (width/height/padding), responsive breakpoints (isMobile/tablet/desktop), RTL check, `showAppSnackBar()` helper. |
| `extensions/string_extensions.dart` | Extension on `String`: `capitalize`, `capitalizeAll`, `containsArabic`, `truncate()`, `isValidEmail`, `isValidPhone`. |
| `extensions/date_extensions.dart` | Extension on `DateTime`: `isToday`, `isYesterday`, `isCurrentYear`, `timeAgo()` (returns human-readable relative time). |
| `localization/locale_provider.dart` | `localeProvider` (NotifierProvider<LocaleNotifier, Locale>). Persists selected locale to SharedPreferences. Supports toggling between English and Arabic. |
| `router/app_shell_router.dart` | `goRouterProvider` creates GoRouter with auth redirect logic and `refreshListenable` for efficient rebuilds. Unauthenticated users go to `/login`. Auth routes: `/login`, `/register`, `/forgot-password`. Authenticated shell: `/home`, `/settings` with bottom navigation. |
| `theme/app_colors.dart` | `AppColors` abstract final class with 12 static Color constants for light/dark palettes. |
| `theme/app_text_styles.dart` | `AppTextStyles` abstract final class with 15 static methods returning Material 3 text styles from theme. |
| `theme/app_theme.dart` | `AppTheme` with `lightTheme()` and `darkTheme()` static methods. Creates `ThemeData` with Material 3, custom `ColorScheme.fromSeed`, and configured component themes (AppBar, Card, Button, Input, SnackBar, Divider, BottomNav). |
| `theme/theme_mode_provider.dart` | `themeModeProvider` (NotifierProvider<ThemeModeNotifier, ThemeMode>). Persists theme mode to SharedPreferences. Toggles between light and dark. |
| `utils/validators.dart` | `AppValidators` abstract final class with 7 static form validators: `required`, `email`, `phone`, `minLength`, `maxLength`, `password`, `confirmPassword`. |

### Data Layer — `lib/data/`

| File | Description |
|---|---|
| `datasources/local/shared_preferences_service.dart` | Wraps SharedPreferences with typed get/set methods. Provides `isOnboardingComplete` convenience getter. |
| `datasources/local/secure_storage_service.dart` | Wraps FlutterSecureStorage with `write`, `read`, `delete`, `clearAll`. Also defines an unused `secureStorageProvider`. |
| `datasources/remote/supabase_auth_data_source.dart` | Wraps Supabase `GoTrueClient`. Methods: `signInWithEmail`, `signUpWithEmail`, `signOut`, `resetPassword`, `refreshSession`. Exposes `currentSupabaseUser`, `currentSession`, `authStateChanges` stream. |
| `datasources/remote/supabase_profile_data_source.dart` | Wraps Supabase `PostgrestQueryBuilder`. Methods: `getProfile`, `updateProfile`, `uploadAvatar`. Table: `profiles`. Storage bucket: `profiles`. |
| `models/user_model.dart` | Freezed `UserModel` with `fromSupabase()` (snake_case), `toEntity()` (domain User), `toSupabaseJson()`. Private constructor prevents external instantiation. |
| `repositories/auth_repository_impl.dart` | Implements `AuthRepository`. Delegates to `SupabaseAuthDataSource`. Maps Supabase `AuthResponse` to domain `AuthResult`. Properly implements `refreshSession()` using Supabase SDK. Catches `sb.AuthException` and rethrows as app exceptions. |
| `repositories/user_repository_impl.dart` | Implements `UserRepository`. Uses both `SupabaseAuthDataSource` (for current user) and `SupabaseProfileDataSource` (for profile data). `deleteUser()` is a no-op stub. |
| `repositories/profile_repository_impl.dart` | Implements `ProfileRepository`. Delegates to `SupabaseProfileDataSource`. `watchProfile()` creates a broadcast stream with proper controller cleanup via `onCancel`. |

### Domain Layer — `lib/domain/`

| File | Description |
|---|---|
| `entities/user.dart` | Freezed `User` entity: id, email, fullName, phone, avatarUrl, language, isOnboarded, createdAt, updatedAt. |
| `repositories/auth_repository.dart` | Abstract `AuthRepository` interface: signIn, signUp, signOut, resetPassword, getCurrentSession, refreshSession. Also defines `AuthResult` data class. |
| `repositories/user_repository.dart` | Abstract `UserRepository` interface: getCurrentUser, getUserById, updateUser, deleteUser, updateLanguage. |
| `repositories/profile_repository.dart` | Abstract `ProfileRepository` interface: getProfile, updateProfile, uploadAvatar, watchProfile. |
| `usecases/auth/auth_usecases.dart` | 4 use case classes: `SignInUseCase`, `SignUpUseCase`, `SignOutUseCase`, `ResetPasswordUseCase`. Plus 4 Riverpod providers. Defines `authRepositoryProvider` (throws by default). |
| `usecases/user/get_user.dart` | 2 use case classes: `GetCurrentUserUseCase`, `GetUserByIdUseCase`. Plus 2 providers. Defines `userRepositoryProvider`. |
| `usecases/profile/profile_usecases.dart` | 3 use case classes: `GetProfileUseCase`, `UpdateProfileUseCase`, `UploadAvatarUseCase`. Plus `watchProfileUseCaseProvider` (StreamProvider.family). Defines `profileRepositoryProvider`. |

### Features — `lib/features/`

| File | Description |
|---|---|
| `auth/domain/auth_state.dart` | Freezed union `AuthState`: initial, loading, authenticated(User), unauthenticated, error(String). |
| `auth/presentation/auth_provider.dart` | `AuthStateNotifier extends Notifier<AuthState>`. Methods: `checkAuthStatus()`, `signIn()`, `signUp()`, `signOut()`, `resetPassword()`. Uses `handleException()` for typed error mapping. Central auth state management. |
| `auth/presentation/pages/login_page.dart` | Login form with email/password, visibility toggle, validation, auth error snackbars, navigation to register/forgot-password. |
| `auth/presentation/pages/register_page.dart` | Registration form with full name, email, password, confirm password, dual visibility toggles, validation. |
| `auth/presentation/pages/forgot_password_page.dart` | Password reset form with email, success state showing confirmation message, link back to login. |
| `home/presentation/pages/home_page.dart` | Simple welcome page with icon and text. No functional content. |
| `settings/presentation/pages/settings_page.dart` | Settings page with dark mode SwitchListTile and language RadioGroup (English/Arabic). |

### Services — `lib/services/`

| File | Description |
|---|---|
| `logger/app_logger.dart` | `AppLogger` wrapping the `logger` package. Methods: d, i, w, e. Provided via `loggerProvider`. |
| `supabase/supabase_service.dart` | `supabaseClientProvider` returns `Supabase.instance.client`. |
| `fcm/fcm_service.dart` | `FCMService` with `initialize()`, `getToken()`, `dispose()`. Handles permission, token management, foreground/background messages. Currently unused. |

### Shared Widgets — `lib/shared/widgets/`

| File | Description |
|---|---|
| `app_shell.dart` | Main app scaffold with AppBar (title, theme/locale/logout buttons) and NavigationBar (Home, Settings). Logout shows confirmation dialog. |
| `app_button.dart` | Reusable button with 3 variants (filled/outlined/text), loading spinner, expanded mode. |
| `app_text_field.dart` | Reusable `TextFormField` wrapper with label, hint, icons, obscure text, validation, all standard form callbacks. |
| `error_widget.dart` | Error display with icon, message, optional retry button. |

### Localization — `lib/l10n/`

| File | Description |
|---|---|
| `app_en.arb` | English translation strings (32 keys). |
| `app_ar.arb` | Arabic translation strings (32 keys). |
| `app_localizations.dart` | Generated abstract `AppLocalizations` class with delegate and factory methods. |
| `app_localizations_en.dart` | Generated English implementation. |
| `app_localizations_ar.dart` | Generated Arabic implementation. |

### Tests — `test/`

| File | Description |
|---|---|
| `widget_test.dart` | Smoke test: pumps a Directionality+SizedBox and verifies it exists. Does not test the actual app. |
| `core/validators_test.dart` | 23 unit tests covering all 7 AppValidators methods with valid/invalid/null cases. |
| `core/error_handler_test.dart` | 6 unit tests covering exception-to-failure mapping for all AppException subtypes. |
| `core/string_extensions_test.dart` | 9 unit tests covering capitalize, containsArabic, truncate, isValidEmail, isValidPhone. |
| `core/date_extensions_test.dart` | 8 unit tests covering isToday, isYesterday, timeAgo with various time deltas. |

### Generated Files

| File | Generator | Description |
|---|---|---|
| `*.freezed.dart` | `freezed` | Immutable copyWith, ==, hashCode, pattern matching for Freezed classes |
| `*.g.dart` | `json_serializable` | JSON serialization (fromJson/toJson) for annotated classes |
| `app_localizations*.dart` | `flutter gen-l10n` | Localization class implementations from ARB files |
