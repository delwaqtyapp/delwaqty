# Sprint 61 — Location Accuracy: "0 m" Claimed When Accuracy Was Unknown

**Date:** 2026-08-07 — **Branch:** master — **Session:** 21r

## Feature

The app used to report the user's location as accurate to **0 meters** when the platform actually provided **no accuracy estimate at all** — so a potentially-off-by-hundreds-of-meters network/fused fix was delivered with the same confidence as a real 1 m GNSS fix. Unknown accuracy is now typed as `null` everywhere, every accuracy gate requires `accuracy > 0`, and the deep-lock prefers measured fixes. The Google Geocoding HTTP call now also sends the Android package/certificate headers so an app-restricted Maps key can authorize direct REST geocoding.

## Root cause fixed

| Symptom | Root cause |
|---------|-----------|
| App shows/uses location at "0 m" while the real position is far off | `geolocator` reports `accuracy = 0.0` when `hasAccuracy == false` (typical of network/fused cell fixes). Every engine gate treated `0` as a perfect sub-metre fix: `_isFreshAndPrecise` accepted `>= 0 && <= 1` (instant "≤ 1 m" lock), `_isUsableLastKnown` accepted `>= 0 && <= 500`, `refreshDeepLocked()` early-returned on `accuracy <= 1`, and `UserLocation.accuracyMeters` carried raw `0.0` so callers' `> 1 m` warning guard never fired |
| Google Geocoding always `REQUEST_DENIED` from the app | The raw `http.get` to `maps.googleapis.com` never sent `X-Android-Package`/`X-Android-Cert`, which is the only mechanism that authorizes an Android-app-restricted Maps key for direct REST calls (the Maps SDK sends them automatically; raw HTTP does not) |

## What shipped this session

### Location engine (`lib/features/location/presentation/providers/location_provider.dart`)

- **`_isFreshAndPrecise`** — requires `accuracy > 0 && accuracy <= 1` (was `>= 0`). An unmeasured fix can no longer short-circuit acquisition as "≤ 1 m".
- **`_isUsableLastKnown`** — non-GNSS last-known usable only when `accuracy > 0 && accuracy <= 500` (GNSS-verified last-known still passes on satellite count alone).
- **`refreshDeepLocked()`** — best-fix tracking across the 3 attempts now **prefers known accuracy**: an unknown-accuracy value is kept only as last-resort and can never displace a measured fix or trigger the sub-metre early return.
- **`_acquirePreciseFix()`** — `best` is only replaced by a strictly-known-accuracy sample (`accuracy > 0`), and the early-complete shortcut still requires live GNSS + `accuracy > 0 && <= targetMeters`.
- **`UserLocation.accuracyMeters`** — `position.accuracy > 0 ? position.accuracy : null`. Unknown accuracy is now typed `null`; the delivery (`_useCurrentLocation`) and ride-booking consumers already null-guard, so they can no longer trust a fake "0 m".

### Geocoding headers

- Google geocoding GET now sends `X-Android-Package: com.delwaqty.app` and `X-Android-Cert: 5337185A52F0B615A3388ECC03B6576D61F34EEF` (debug SHA-1, colons removed, per Google's documented format) guarded to Android via `defaultTargetPlatform`.

### Tests (`test/features/location/presentation/providers/location_provider_test.dart`)

3 new regression tests (suite 567 → **570**):

1. **Quick mode rejects** a fresh non-GNSS last-known with unknown (0.0) accuracy → falls through to the stream instead of accepting an unmeasured fix.
2. **Deep mode reports `null`** (not 0 m) for a GNSS last-known with unknown accuracy (was: instant "0.0 m" lock).
3. **Deep mode reports `null`** for a 0.0-accuracy stream sample (was: "0.0 m").

## Quality gates

- `flutter analyze` — 0 errors; **0 new issues** from touched files (repo-wide info lints are pre-existing and untouched).
- `flutter test` — **570/570 passing**.
- `flutter build apk --debug --dart-define-from-file=.env.dev` — built.
- `flutter install --debug` on DNP NX9 (`A3SQUT5A28003808`) — installed; app launches clean (Map SurfaceView active, no FATAL, no ConfigValidator crash).

## Remaining — external blocker (user action in Google Cloud Console)

The Geocoding API itself still needs to be **enabled** for the API key's project: **APIs & Services → Library → Geocoding API → Enable** (billing active). If the key is Application-restricted to Android, confirm the allowed app is package `com.delwaqty.app` with debug SHA-1 `53:37:18:5A:52:F0:B6:15:A3:38:8E:CC:03:B6:57:6D:61:F3:4E:EF` (colon-delimited in the Console UI; the app sends it colons-removed). Until enabled, the Photon/Nominatim fallback chain continues to produce Arabic addresses without Google-level POI depth.

On-device E2E of the fixed accuracy behavior needs a login + delivery-flow walk (fingerprint is enrolled from Session 21q); unit tests + clean install already cover the logic.
