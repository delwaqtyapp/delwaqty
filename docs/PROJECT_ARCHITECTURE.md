# Project Architecture

## Overview

Delwaqty follows **Clean Architecture** with a **feature-first** directory organization. The codebase separates concerns into four primary layers: Presentation, Domain, Data, and Core. Each feature module contains its own data/domain/presentation subdirectories where applicable.

The architecture is designed for Supabase as the backend, Riverpod for state management and dependency injection, and GoRouter for declarative navigation with authentication guards.

## Architectural Pattern

```
┌─────────────────────────────────────────────────────┐
│                  PRESENTATION                        │
│  Features (auth, home, settings)                     │
│  Widgets, Pages, Providers (Riverpod Notifiers)      │
├─────────────────────────────────────────────────────┤
│                    DOMAIN                            │
│  Entities (Freezed), Repository Interfaces (abstract)│
│  Use Cases (one class per business action)           │
├─────────────────────────────────────────────────────┤
│                     DATA                             │
│  Data Sources (local + remote), Models (Freezed)     │
│  Repository Implementations                          │
├─────────────────────────────────────────────────────┤
│                     CORE                             │
│  Constants, Errors, Extensions, Theme, Router,       │
│  Localization, Validators                            │
├─────────────────────────────────────────────────────┤
│                  SHARED                              │
│  Reusable Widgets, Services (Logger, Supabase, FCM)  │
└─────────────────────────────────────────────────────┘
```

## Layer Responsibilities

### Presentation Layer
- **Location:** `lib/features/*/presentation/` and `lib/shared/widgets/`
- **Responsibility:** UI rendering, user interaction handling, state display
- **Dependencies:** Domain layer only (never Data or Core directly for business logic)
- **Key components:**
  - `pages/` — Full-screen routes (LoginPage, RegisterPage, etc.)
  - `widgets/` — Feature-specific reusable components
  - `auth_provider.dart` — Riverpod `NotifierProvider` managing `AuthState`

### Domain Layer
- **Location:** `lib/domain/`
- **Responsibility:** Business rules, entity definitions, repository contracts, use case logic
- **Dependencies:** No external dependencies (pure Dart + Freezed)
- **Key components:**
  - `entities/` — Freezed immutable data classes (`User`)
  - `repositories/` — Abstract interfaces (`AuthRepository`, `UserRepository`, `ProfileRepository`)
  - `usecases/` — Single-responsibility business operations (`SignInUseCase`, `GetProfileUseCase`)

### Data Layer
- **Location:** `lib/data/`
- **Responsibility:** Data fetching, storage, model conversion, repository implementation
- **Dependencies:** Domain layer entities + external packages (Supabase, SharedPreferences)
- **Key components:**
  - `datasources/local/` — SharedPreferencesService, SecureStorageService
  - `datasources/remote/` — SupabaseAuthDataSource, SupabaseProfileDataSource
  - `models/` — `UserModel` with Supabase-specific serialization (`fromSupabase`/`toSupabaseJson`)
  - `repositories/` — Concrete implementations of domain repository interfaces

### Core Layer
- **Location:** `lib/core/`
- **Responsibility:** Cross-cutting concerns, app-wide configuration
- **Key components:**
  - `constants/` — API URLs, storage keys, app constants
  - `errors/` — Sealed `AppException` hierarchy, Freezed `Failure` union, error handler
  - `extensions/` — Context, String, DateTime extension methods
  - `router/` — GoRouter configuration with auth redirect and shell route
  - `theme/` — Material 3 light/dark themes, color palette, text styles
  - `localization/` — Locale provider with persistence
  - `utils/` — Validators

### Services Layer
- **Location:** `lib/services/`
- **Responsibility:** External service abstractions
- **Key components:**
  - `logger/` — Logger wrapper with Riverpod provider
  - `supabase/` — Supabase client provider
  - `fcm/` — Firebase Cloud Messaging service (built, not yet wired)

## Dependency Flow

The dependency flow follows the Dependency Rule: outer layers depend on inner layers, never the reverse.

```
Presentation → Domain ← Data
                   ↑
                  Core
```

Concrete flow in this project:

1. **Presentation** (pages/widgets) reads Riverpod providers
2. **Riverpod providers** are overridden in `main.dart` at the ProviderScope level
3. **Use cases** (domain) call repository interfaces
4. **Repository implementations** (data) call data sources and return domain entities
5. **Data sources** (data) interact with Supabase SDK, SharedPreferences, SecureStorage
6. **Core** provides utilities used across all layers (validators, extensions, theme, errors)

### Dependency Injection Pattern

Riverpod is used for all DI. The pattern is:

1. Domain defines abstract providers that throw `UnimplementedError`:
   ```dart
   final authRepositoryProvider = Provider<AuthRepository>((ref) {
     throw UnimplementedError('Must be overridden');
   });
   ```

2. Data provides concrete implementations:
   ```dart
   final authRepositoryImplProvider = Provider<AuthRepositoryImpl>((ref) { ... });
   ```

3. `main.dart` wires them at the ProviderScope level:
   ```dart
   ProviderScope(
     overrides: [
       authRepositoryProvider.overrideWith(
         (ref) => ref.watch(authRepositoryImplProvider),
       ),
     ],
   )
   ```

## Data Flow

### Authentication Flow
```
User taps Login
  → LoginPage calls authStateProvider.notifier.signIn()
    → AuthStateNotifier sets state = AuthLoading
    → Calls SignInUseCase (domain)
      → Calls AuthRepository.signInWithEmail()
        → AuthRepositoryImpl delegates to SupabaseAuthDataSource
          → Supabase SDK: signInWithPassword()
        ← Returns AuthResponse
      ← Maps to AuthResult
    ← AuthStateNotifier calls GetCurrentUserUseCase
      → Gets user profile from SupabaseProfileDataSource
    ← Sets state = AuthAuthenticated(user)
  → GoRouter redirect detects AuthAuthenticated
    → Redirects to /home
```

### Error Handling Flow
```
Repository catches exception
  → Throws AppException subtype (AuthException, ServerException, etc.)
  → Provider catches AppException
    → Calls handleException(appException) → Failure
    → Stores Failure.message in AuthState.error
  → UI reads error message from state
```

### Profile Update Flow
```
User edits profile
  → Screen calls UpdateProfileUseCase
    → ProfileRepository.updateProfile()
      → ProfileRepositoryImpl calls SupabaseProfileDataSource.updateProfile()
        → Supabase SDK: .from('profiles').update(data).eq('id', userId)
      ← Returns UserModel
    ← UserModel.toEntity() converts to domain User
  ← Returns User to presentation layer
```

## Feature Flow

Features follow this internal structure:

```
features/
└── auth/
    ├── domain/
    │   └── auth_state.dart          # Freezed union (AuthState)
    └── presentation/
        ├── auth_provider.dart       # NotifierProvider (AuthStateNotifier)
        └── pages/
            ├── login_page.dart
            ├── register_page.dart
            └── forgot_password_page.dart
```

1. The feature defines its **state model** as a Freezed union in `domain/`
2. A **Riverpod Notifier** in `presentation/` manages state transitions
3. **Pages** are `ConsumerWidget` or `ConsumerStatefulWidget` that read the provider
4. Pages call provider methods which delegate to **use cases**
5. Use cases delegate to **repository interfaces** (abstract, in domain)
6. Repository **implementations** (in data) handle the actual work

## Current Limitations

1. **FCM service is built but not wired** — The FCM architecture exists but is never initialized or called from anywhere. Will be activated when push notifications are needed.

2. **Several shared widgets are unused** — `AppButton`, `AppTextField`, `AppLoading`, `EmptyStateWidget`, `ResponsiveLayout` are implemented but not yet rendered in production pages.

3. **Stub implementations exist** — `deleteUser()` in `UserRepositoryImpl` is a no-op stub.
