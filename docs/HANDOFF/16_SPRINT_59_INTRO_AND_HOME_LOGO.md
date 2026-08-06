# Sprint 59 — Home Page Logo + Intro Wordmark Flash Root-Cause Fix

**Date:** 2026-08-06 · **Commit:** `e1f364f` · **Branch:** master (pushed)

## User Reports

1. The home page header still showed the gradient square with the Arabic "دلوقتي" text where the app logo image should be, next to the sidebar (menu) button.
2. During the intro, while the English "Delwaqty" wordmark types letter-by-letter, a visible "crash"/flash occurs (the dark purple background briefly disappears).

## Diagnosis

### Wordmark "crash" is a rendering artifact, not a Dart exception

- Logcat during a full cold start (cleared data): the app process **stays alive** through the entire intro; no `FATAL`, no `AndroidRuntime`, no `E/flutter` exception. The intro runs its full 5.4 s sequence and lands on the login page.
- The engine logs `[ERROR:flutter/lib/ui/window/platform_configuration.cc(448)] Reported frame time is older than the last one; clamping` during the wordmark window (1.5–2.5 s) → UI-thread jank/frame drop during that phase.
- **Root cause:** `_AmbientPainter` recreated **3 radial gradient shaders every frame** (`ui.Gradient.radial`) even though the glows are static — only the particles move. On Impeller (Vulkan) this per-frame shader churn during the simultaneous wordmark animation produces a dropped frame where the gradient surface fails to composite → the background "disappears" for a frame.

### Fix: split the ambient painter

| Before | After |
|--------|-------|
| `_AmbientPainter(progress)` — repainted every tick, recreating 3 radial shaders + 30 circles | **`_GlowPainter`** (const) — draws the 3 static radial glows once; `shouldRepaint => false`; raster-cached in its own `RepaintBoundary` |
| — | **`_ParticlePainter(progress)`** — animated layer draws only 30 tiny white circles (no shaders); still wrapped in its own `RepaintBoundary` |

Per-frame cost is now ~30 circles. Zero per-frame shader creation.

## Verification (on device, DNP NX9)

I cannot render images in this session, so verification was done programmatically:

- **Per-frame luma via `ffmpeg signalstats`** on a screenrecord of a cleared-data cold start:
  - Splash window (frames ~70–320): **max frame-to-frame luma diff < 1.0** → the background never disappears during the wordmark. No flash frame.
  - Frames 28–68 (luma dipping toward 17.6): the native Android 12+ launch crossfade **before** Flutter's first frame — normal cold-start transition, unrelated to the wordmark.
  - Frame 323→324 (diff ~72): the expected splash→login transition.
- **Home logo:** `assets/logo app/logo.png` (1.27 MB) is bundled in the APK; the identical asset path already renders on the splash + login pages; logcat shows no `Unable to load asset`.

## Home Page Logo

`_LogoMark` (home_page.dart) now renders the official logo image:
- White 46×46 tile, `BorderRadius.circular(14)`, existing purple shadow, `ClipRRect`, `Image.asset('assets/logo app/logo.png', fit: BoxFit.contain)`.
- `errorBuilder` falls back to the previous gradient square with "دلوقتي" if the asset ever fails to load.
- Sits in the header `Row` directly after the `_GlassCircleButton` (sidebar/menu), before the greeting.

## Quality Gates

- `flutter analyze` — **0 errors** (changed files introduce no new lints).
- `flutter test` — **542/542 passing**.
- `flutter build apk --debug --dart-define-from-file=.env.dev` — ✅ built + installed on DNP NX9.

## Files Changed

- `lib/features/splash/presentation/pages/splash_page.dart` — painter split (`_GlowPainter` + `_ParticlePainter`).
- `lib/features/home/presentation/pages/home_page.dart` — `_LogoMark` renders the real logo image.
- `SESSION_STATUS.md` — session 21o entry + milestone M13j.
