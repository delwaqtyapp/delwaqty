# Delwaqty - Credential Report

**Generated:** 2026-07-16
**SECURITY: No secret values are exposed in this document.**

---

## Required Credentials

| Variable | Purpose | Status | Storage |
|----------|---------|--------|---------|
| `SUPABASE_URL` | Supabase project URL | **Configured** | `.env.dev` |
| `SUPABASE_ANON_KEY` | Supabase anonymous (public) key | **Configured** | `.env.dev`, `supabase_config_v2.dart` |
| `SUPABASE_SERVICE_ROLE_KEY` | Supabase admin key (NOT a JWT) | **Configured** | `.env.dev` |
| `SUPABASE_DB_PASSWORD` | PostgreSQL database password | **Configured** | `.env.dev` |
| `GITHUB_REPO` | GitHub repository URL | **Configured** | `.git/config` |
| `GOOGLE_MAPS_API_KEY` | Google Maps SDK key | **Missing** | Add to `.env.dev` |
| `FIREBASE_API_KEY` | Firebase Web API key | **Missing** | Add to `google-services.json` |
| `FIREBASE_PROJECT_ID` | Firebase project ID | **Missing** | Add to `google-services.json` |
| `FIREBASE_APP_ID` | Firebase App ID | **Missing** | Add to `google-services.json` |
| `FIREBASE_MESSAGING_SENDER_ID` | FCM sender ID | **Missing** | Add to `google-services.json` |
| `CLOUDFLARE_ACCOUNT_ID` | Cloudflare account | **Missing** | Add to `.env.dev` |
| `CLOUDFLARE_API_TOKEN` | Cloudflare API token | **Missing** | Add to `.env.dev` |
| `CLOUDFLARE_R2_BUCKET` | Cloudflare R2 storage bucket | **Missing** | Add to `.env.dev` |

## Storage Locations

| File | Contents |
|------|----------|
| `.env.dev` | Development environment variables |
| `.env.staging` | Staging environment (template) |
| `.env.prod` | Production environment (template) |
| `.env.example` | Full template with descriptions |
| `lib/config/supabase_config_v2.dart` | Supabase initialization config |
| `lib/config/firebase_config.dart` | Firebase initialization config |
| `lib/config/maps_config_v2.dart` | Google Maps config |
| `lib/config/cloudflare_config_v2.dart` | Cloudflare config |
| `lib/config/platform_config.dart` | Platform readiness aggregator |

## Priority for Next Steps

1. **Run SQL migration** in Supabase Dashboard (unblocks everything)
2. **Google Maps API key** (needed for delivery/tracking)
3. **Firebase project** (needed for push notifications, analytics)
4. **Cloudflare credentials** (needed for CDN, image optimization, R2 storage)
