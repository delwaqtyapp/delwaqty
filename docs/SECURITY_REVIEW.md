# Security Review

## 1. Secrets Management

### Current Implementation
Secrets are managed via Dart compile-time environment variables using `--dart-define`:

```dart
// lib/core/constants/api_constants.dart
static const String baseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'https://your-project.supabase.co',
);
static const String supabaseAnonKey = String.fromEnvironment(
  'SUPABASE_ANON_KEY',
);
```

### Assessment
- **Good:** No hardcoded secrets in source code. Values are injected at build time.
- **Good:** The `pubspec.yaml` has `publish_to: 'none'`, preventing accidental publishing.
- **Risk:** The `defaultValue` for `baseUrl` is a placeholder (`your-project.supabase.co`). If a developer runs the app without providing `--dart-define`, the app will attempt to connect to this placeholder URL.
- **Risk:** The `supabaseAnonKey` defaults to empty string. If not provided, Supabase initialization will fail silently (caught by try/catch in `main.dart`).
- **Missing:** No `.env` file or `--dart-define-from-file` configuration documented. Developers need to know to provide these values.

### Recommendations
1. Create a `.env.example` file documenting required variables.
2. Add `--dart-define-from-file` support for easier local development.
3. Consider using `flutter_dotenv` for runtime-configurable values if needed.
4. Never commit actual `.env` files. Add `.env` to `.gitignore`.

---

## 2. Storage Review

### SharedPreferences (Public Storage)
Used for: theme mode, locale, onboarding completion flag.

- **Assessment:** Safe. These are non-sensitive UI preferences. Storing them in plaintext SharedPreferences is appropriate.
- **Risk:** None. These values have no security implications.

### FlutterSecureStorage (Encrypted Storage)
Used for: access tokens, refresh tokens.

```dart
const secureStorage = FlutterSecureStorage(
  aOptions: AndroidOptions(encryptedSharedPreferences: true),
  iOptions: IOSOptions(
    accessibility: KeychainAccessibility.first_unlock_this_device,
  ),
);
```

- **Assessment:** Good implementation.
  - Android: Uses EncryptedSharedPreferences (AES-256 encryption via Tink).
  - iOS: Uses Keychain with `first_unlock_this_device` accessibility (available after first device unlock).
- **Missing:** No key rotation or migration strategy. If the storage schema changes, there is no upgrade path.
- **Missing:** `clearAll()` on logout only clears SecureStorage in the service layer. SharedPreferences is not cleared on logout (theme/locale should persist, so this may be intentional).

### Recommendations
1. Verify `FlutterSecureStorage` version supports the latest Android Keystore changes.
2. Consider adding a migration mechanism for storage schema changes.
3. Document what data persists across sessions and what is cleared on logout.

---

## 3. Authentication Review

### Current Flow
1. User submits credentials via `LoginPage`.
2. `AuthStateNotifier.signIn()` calls `SignInUseCase`.
3. Use case calls `AuthRepository.signInWithEmail()`.
4. Repository delegates to `SupabaseAuthDataSource.signInWithEmail()`.
5. Supabase SDK handles authentication and returns tokens.
6. Tokens are managed by Supabase SDK internally.

### Assessment
- **Good:** Authentication is delegated to Supabase, which handles password hashing, token generation, and token refresh server-side.
- **Good:** `refreshSession()` now properly delegates to Supabase's `refreshSession()` API, allowing token recovery.
- **Good:** Auth state is checked on app startup via `checkAuthStatus()`.
- **Good:** GoRouter redirect prevents unauthenticated access to protected routes.
- **Good:** `handleException()` is now wired into the auth provider for typed error mapping.

### Vulnerabilities Found

| Issue | Severity | Status |
|---|---|---|
| No token refresh logic | High | **FIXED** — `refreshSession()` now calls Supabase SDK |
| Silent auth failure | Medium | Partially addressed — Supabase init failure still caught silently |
| No rate limiting on client | Low | Not addressed — limited by Supabase server-side |
| No password complexity enforcement | Low | Business decision, not a security bug |

### Recommendations
1. Consider adding a network connectivity check before auth attempts.
2. Add a `SecureScreen` wrapper to prevent screenshots on sensitive screens (login, profile).
3. Surface Supabase initialization failure to the user.

---

## 4. API Security

### Current State
All API communication goes through the Supabase client, which handles:
- HTTPS transport (TLS 1.2+)
- JWT-based authentication
- Row Level Security (RLS) on Supabase tables
- API key injection via `apikey` header

### Assessment
- **Good:** Supabase enforces RLS policies at the database level. Even if the client makes incorrect requests, the server rejects unauthorized data access.
- **Good:** The `apikey` (anon key) is designed to be public — it is not a secret. Security is enforced by RLS policies, not the key itself.
- **Risk:** No evidence that RLS policies are configured. The `profiles` table operations (`select`, `update`, `insert`) will only work if proper RLS policies exist on the Supabase project. This is a deployment configuration concern, not a code issue.
- **Missing:** No request validation on the client side before sending to Supabase.

### Recommendations
1. Verify RLS policies are configured on all Supabase tables before production deployment.
2. Add client-side data validation before Supabase operations.
3. Implement proper error handling for RLS policy violations (403 errors from Supabase).

---

## 5. Potential Vulnerabilities

### Token Handling
- Access tokens are managed by Supabase SDK internally. The `SecureStorageService` wrapper exists but is only used for potential future custom API layer.
- **Risk:** Low. Supabase SDK handles token storage and refresh internally.

### Input Validation
- Form validation exists via `AppValidators` for email, phone, password fields.
- **Risk:** Low. Validators are applied on all form fields.

### Code Injection
- No use of `eval()`, `dart:ffi` dynamic loading, or WebView with JavaScript channels.
- **Risk:** None.

### Local Data Exposure
- User data (email, name) is stored only in memory via Riverpod state, not persisted locally.
- **Risk:** Low. No local data exposure beyond tokens in SecureStorage.

### Build Security
- No ProGuard/R8 rules configured for Android release builds. Sensitive SDK internals may be visible in decompiled APK.
- **Risk:** Medium for release builds.

### Recommendations
1. Add Android ProGuard/R8 rules for release obfuscation.
2. Verify iOS App Transport Security settings.
3. Add certificate pinning if using custom API endpoints beyond Supabase.
4. Implement screenshot prevention on sensitive screens.
5. Add jailbreak/root detection for high-security requirements.
