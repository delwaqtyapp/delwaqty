# Delwaqty - Environment Setup Guide

**Generated:** 2026-07-16

---

## Prerequisites

- Flutter SDK ^3.12.2
- Dart SDK ^3.12.2
- Android Studio / Xcode (for mobile)
- Git
- Node.js (for Supabase CLI)

## Quick Setup

```bash
# Clone
git clone https://github.com/delwaqtyapp/delwaqty.git
cd delwaqty

# Install dependencies
flutter pub get

# Run code generation
dart run build_runner build --delete-conflicting-outputs

# Verify
flutter analyze
flutter test
```

## Environment Files

| File | Purpose |
|------|---------|
| `.env.dev` | Development — configured with Supabase keys |
| `.env.staging` | Staging — template, needs values |
| `.env.prod` | Production — template, needs values |
| `.env.example` | Full template with all variable descriptions |

## Required Credentials

| Variable | Where to Get | Status |
|----------|-------------|--------|
| `SUPABASE_URL` | Supabase Dashboard → Settings → API | ✅ Configured |
| `SUPABASE_ANON_KEY` | Supabase Dashboard → Settings → API | ✅ Configured |
| `SUPABASE_SERVICE_ROLE_KEY` | Supabase Dashboard → Settings → API | ✅ Configured |
| `SUPABASE_DB_PASSWORD` | Supabase Dashboard → Settings → Database | ✅ Configured |
| `GOOGLE_MAPS_API_KEY` | Google Cloud Console → Credentials | ❌ Needed |
| Firebase credentials | Firebase Console → Project Settings | ❌ Needed |
| Cloudflare credentials | Cloudflare Dashboard | ❌ Needed |

## Platform-Specific Setup

### Android
- Ensure `android/local.properties` has correct SDK path
- Add `google-services.json` to `android/app/` when Firebase is ready
- Minimum SDK: check `android/app/build.gradle`

### iOS
- Run `cd ios && pod install`
- Add GoogleService-Info.plist when Firebase is ready

### Web
- No special setup needed

## Database Setup

1. Go to https://supabase.com/dashboard/project/bttnlkmwhorjamzemwda/sql/new
2. Paste contents of `supabase/migrations/001_initial_schema.sql`
3. Click "Run"
4. Verify tables exist in Table Editor

## Development Commands

```bash
# Scripts
bash scripts/build.sh              # Build current platform
bash scripts/build_all.sh          # Build all platforms
bash scripts/analyze.sh            # Static analysis
bash scripts/test.sh               # Run tests
bash scripts/codegen.sh            # Code generation
bash scripts/git_status.sh         # Git status
bash scripts/sprint_commit.sh      # Sprint commit helper

# Direct Flutter
flutter run                         # Run on connected device
flutter run -d chrome               # Run on Chrome
flutter build apk                   # Build Android APK
flutter build ios                   # Build iOS
flutter build web                   # Build web
```
