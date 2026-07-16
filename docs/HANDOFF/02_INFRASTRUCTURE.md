# Delwaqty - Infrastructure Report

**Generated:** 2026-07-16

---

## External Services

| Service | Status | Config Location |
|---------|--------|-----------------|
| Supabase | Connected (DB tables pending) | `lib/config/supabase_config_v2.dart`, `.env.dev` |
| Firebase | Configured (credentials needed) | `lib/config/firebase_config.dart` |
| Google Maps | Configured (API key needed) | `lib/config/maps_config_v2.dart` |
| Cloudflare | Configured (credentials needed) | `lib/config/cloudflare_config_v2.dart` |
| GitHub | Active | `.github/workflows/` |

## Supabase

- **Project ID:** `bttnlkmwhorjamzemwda`
- **URL:** `https://bttnlkmwhorjamzemwda.supabase.co`
- **Region:** EU (based on pooler endpoints)
- **PostgreSQL Version:** 14.5
- **Status:** REST API functional, database tables NOT YET CREATED
- **Migration:** `supabase/migrations/001_initial_schema.sql` (370 lines)

### Database Connection
- **Direct Host:** `db.bttnlkmwhorjamzemwda.supabase.co` (IPv6-only)
- **Pooler:** Not available for this project
- **BLOCKER:** Tables must be created via Supabase Dashboard SQL Editor

## Build System

| Script | Purpose |
|--------|---------|
| `build.sh` | Build current platform |
| `scripts/build_all.sh` | Build all platforms |
| `scripts/analyze.sh` | Static analysis |
| `scripts/test.sh` | Run tests |
| `scripts/codegen.sh` | Run build_runner codegen |
| `scripts/git_status.sh` | Git status summary |
| `scripts/sprint_commit.sh` | Sprint commit helper |

## CI/CD

- **CI Pipeline:** `.github/workflows/ci.yml` — analyze → build (debug+release APK) → GitHub Release
- **Auto Sync:** `.github/workflows/auto_sync.yml` — test → build → upload artifacts

## Environment Management

| File | Purpose | Status |
|------|---------|--------|
| `.env.dev` | Development | Configured with Supabase keys |
| `.env.staging` | Staging | Template only |
| `.env.prod` | Production | Template only |
| `.env.example` | Template | Full documentation |

## Platform Readiness

| Platform | Status | Notes |
|----------|--------|-------|
| Android | Build-ready | `android/` configured |
| iOS | Build-ready | `ios/` configured |
| Linux | Build-ready | `linux/` configured |
| macOS | Build-ready | `macos/` configured |
| Windows | Build-ready | `windows/` configured |
| Web | Build-ready | `web/` configured |

## Missing Credentials

See `04_API_KEYS.md` for full credential status.
