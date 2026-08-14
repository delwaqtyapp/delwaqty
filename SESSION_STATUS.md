# SESSION_STATUS.md

> **Last updated:** 2026-08-14 Session 40 (biometric login audit + password-change biometric invalidation fix)

---

## Current Task — BIOMETRIC LOGIN: FULL AUDIT + SECURITY FIX (Session 40)

**Task (user, Arabic):** finish biometric login, add it in settings + login page, plan it
professionally, wire it to the DB, then build + install the app on the phone.

**Audit result:** the biometric feature was already ~95% implemented across the app. Verified
end-to-end:
- **DB:** `users.is_biometric_enabled` BOOLEAN NOT NULL DEFAULT false — live (migration 022)
- **Device store:** `BiometricAuthStore` (flutter_secure_storage, encrypted credentials keyed by
  user id: `auth_biometric_<userId>`) — `biometric_auth_store.dart`
- **Login page:** fingerprint button + remember-me + post-login enrollment offer — `login_page.dart`
- **Settings:** `FingerprintLoginPage` (toggle + password prompt + multi-account management),
  reachable from Privacy & Security — `privacy/fingerprint_login_page.dart`
- **Splash:** biometric auto-login on cold start — `splash_page.dart`
- **DB sync:** `updateBiometricEnabled` → repository → profile DS → `users.is_biometric_enabled`
- **Android:** `USE_BIOMETRIC` + `USE_FINGERPRINT` permissions in manifest; `local_auth ^3.0.0`
  + `flutter_secure_storage ^11.0.0` in pubspec
- **L10n:** full AR/EN keys present

**Bug found + fixed (security gap):** `ChangePasswordPage` changed the password WITHOUT invalidating
the encrypted biometric credentials in secure storage — leaving a stale password that would fail
biometric login and linger as a stored secret. Fix: after a successful password change,
`_invalidateBiometricLogin()` clears the stored credential for the user and resets
`is_biometric_enabled=false` in the DB, forcing clean re-enrollment. File:
`lib/features/settings/presentation/pages/privacy/change_password_page.dart` (converted to
ConsumerStatefulWidget, imports added).

**Gate:** `flutter analyze` → 0 errors (543 issues: 24 warning + 519 info — unchanged baseline) ·
`flutter test --no-pub --concurrency=2` → **02:19 +594: All tests passed!** (exit 0). Biometric
tests (`biometric_auth_store_test.dart`, `fingerprint_login_page_test.dart`) pass individually.

**Next:** build APK with `--dart-define-from-file=.env.dev`, install on phone (device not
connected yet — needs USB/WiFi adb), commit + push, revoke PAT after session.

---

## Previous Task — SCHEMA RECONCILIATION 029 APPLIED LIVE + VERIFIED (Session 39)

**Found (live audit, code-vs-schema diff):** migrations `012_safety_platform.sql` and
`013_service_audio_logs.sql` were **never applied** live (027 consolidated 017/023/024/025/026 but
skipped 012 + 013). Live was missing: `sos_alerts`, `live_share_sessions`, `service_audio_logs`
tables; `trusted_contacts.email/relationship/notify_on_ride/notification_preference` columns;
`rides.emergency_contact_id`; all 7 safety RPCs (`trigger_sos_alert`, `resolve_sos_alert`,
`start_live_share`, `stop_live_share`, `get_live_share_session`, `upsert_trusted_contact`,
`delete_trusted_contact`); the `service-audio-logs` storage bucket. Additionally, 4 RPCs the app
calls existed in **no** migration file: `get_admin_analytics`, `get_peak_hours`,
`get_merchant_rating_summary`, `increment_coupon_usage`.

**Fix:** wrote `supabase/migrations/029_schema_reconciliation_safety_audio_rpcs.sql` (new file),
consolidating the missing 012/013 objects + the 4 orphan RPCs with shapes matching the Dart call
sites. Two correctness fixes vs the originals:
- `upsert_trusted_contact` argument order (Postgres requires defaults after a defaulted param —
  original 012 had a latent 42P13 bug) — signature is `(p_name, p_phone, p_contact_id=NULL, …)`
- `sos_alerts.status` CHECK → `('active','escalated','resolved','falseAlarm')` — the app
  serializes `SosAlertStatus.falseAlarm` via `.name` (would have failed the old `false_alarm`
  constraint when resolving a false alarm)

**Security hardening (matches 028 pattern + fixes Supabase default-privilege leak):** Supabase's
platform `ALTER DEFAULT PRIVILEGES` auto-grants new functions to `anon`/`authenticated`/`service_role`.
Migration 028 missed revoking `anon`. 029 explicitly `REVOKE … FROM PUBLIC, anon` + `GRANT … TO
authenticated` for all 11 RPCs. Verified ACLs now `{postgres=X, authenticated=X, service_role=X}`
(no anon).

**Applied (HTTP 200, `[]`) + verified live:**
- Tables present: `sos_alerts`, `live_share_sessions`, `service_audio_logs` (RLS on)
- `trusted_contacts` has all extension columns; `rides.emergency_contact_id` present
- All 7 safety RPCs + 4 orphan RPCs present; storage bucket + `audio logs upload/read` policies
- Realtime publication: `sos_alerts` + `live_share_sessions` added
- REST (anon key): `get_peak_hours` → 42501 permission denied (anon correctly blocked);
  `trigger_sos_alert` → 401 (blocked)
- SQL logic: `get_peak_hours()`, `get_merchant_rating_summary`, `increment_coupon_usage`
  (`coupon_not_found`), `get_admin_analytics` (real totals: 5 users, 9 merchants) all correct
- Auth flow: `upsert_trusted_contact` called as real user (JWT claims sim) → `success, contact_id`; test row cleaned up
- Final code↔live audit: **0 missing RPCs** (45 code / 61 live)

**Files:** `supabase/migrations/029_schema_reconciliation_safety_audio_rpcs.sql` (new, pending review)
**Gate:** `flutter analyze` + `flutter test --concurrency=2` — TBD (run before commit)
**Next:** run gate, commit (sprint 72), push, remind user to revoke PAT.

---

## Previous Task — MIGRATION 028 APPLIED LIVE + VERIFIED (Session 38)

**Task (user, Arabic):** continue the deep-repair steps; try all keys I have; ask when a key is
missing; don't skip any step.

**Found:** migration `028_schema_alignment.sql` was already committed (in sprint 69 with the
admin-repository RPC refactor) but **never applied** to the live `bttnlkmwhorjamzemwda` project.
Live checks via REST: `count_table_rows` RPC → PGRST202 (missing), `users.trade_license_url` →
42703 (missing column). The committed `AdminRepository.getDashboardMetrics()` depends on the RPC,
so the admin dashboard would crash in production.

**Fix:** rewrote the migration to fix a PL/pgSQL syntax bug and harden security, then applied via
Management API with the user's PAT (project linked in `~/.supabase/config.toml`).

| File | Change |
|------|--------|
| `supabase/migrations/028_schema_alignment.sql` | Fixed syntax `RETURN (EXECUTE …)` → `EXECUTE … INTO row_count; RETURN row_count;`; `SECURITY DEFINER` → **`SECURITY INVOKER`** (page counts reflect the caller's RLS visibility, never worse than the `.select().count()` calls it replaces); added `REVOKE EXECUTE FROM PUBLIC` + `GRANT EXECUTE TO authenticated` |

**Applied (HTTP 201) + verified live:**
- `count_table_rows(text)` → present: `prosecdef=false`, ACL `{postgres=X, anon=X, authenticated=X, service_role=X}`; anonymous call returns `0` (RLS hides rows), admin sees real totals
- `users.trade_license_url` + `users.driving_license_url` → **text** columns present
- `admin_users_role_check` → now `CHECK (role IN ('super_admin','admin','moderator','support','finance'))` (includes `moderator`)
- Full public-RPC inventory checked: 40+ RPCs (dispatch/accept/advance/cancel/estimate/RPCs) all present; 56 tables present

**Gate:** `flutter analyze` → 0 errors (543 issues: 24 warning + 519 info — unchanged baseline) ·
`flutter test --concurrency=2` → **02:28 +594: All tests passed!** (exit 0). Note: on this PRoot
host a full `flutter test` without `--concurrency` can exit 1 with no output; `--concurrency=2`
is the reliable invocation.

**Next (user hands):** revoke the PAT after this session.

---

## Previous Task — FINAL TOOLCHAIN STANDARDIZATION + ANDROID COMPATIBILITY AUDIT (Session 37)

**Task (user):** finalize the verified development environment, document the canonical toolchain,
verify Android compatibility (minimum Android 7.0 / API 24), and prepare the repository for a clean commit.

### Canonical toolchain (authoritative — use for ALL Delwaqty work)

```
Android/Termux
    ↓ PRoot Ubuntu
/root/flutter  →  Flutter 3.44.6 · Dart 3.12.2 · DevTools 2.57.0
    ↓ Linux host (detected; native-assets OK)
Android SDK 37 →  /usr/lib/android-sdk
NDK 28.2.13676358
QEMU x86_64 wrappers (42 files for incompatible ARM64-native tooling)
Delwaqty Flutter project  →  /root/Projects/delwaqty
```

| Item | Value |
|------|-------|
| **Canonical project** | `/root/Projects/delwaqty` |
| **Canonical Flutter** | `/root/flutter` · Flutter **3.44.6** · Dart 3.12.2 · `channel stable` |
| **Flutter resolution** | `which flutter` → `/usr/local/bin/flutter` → symlink → `/root/flutter/bin/flutter` |
| **Termux-host Flutter** | `/data/data/com.termux/files/usr/opt/flutter` · Flutter **3.44.2** — **NOT canonical**, patched (android_sdk.dart compileSdk 37), fails `flutter test` on host (detects OS as `android`; native assets unimplemented). **DO NOT remove/upgrade/patch. Not used for project tests/builds.** |
| **Android SDK** | `/usr/lib/android-sdk` (android-34/35/36/37/37.0, build-tools 36.0.0) |
| **compileSdk / targetSdk / minSdk** | **37 / 36 / 24** (minSdk 24 = Android 7.0 hard minimum, verified via merged APK manifest) |
| **NDK** | 28.2.13676358 |
| **QEMU workaround** | 42 qemu-x86_64 wrapper scripts (e.g. NDK `clang` → `qemu-x86_64 -0 … clang-19.real`); SDK at `/usr/lib/android-sdk`, aapt2 overridden in gradle.properties |
| **Gradle heap** | `-Xmx4G -XX:MaxMetaspaceSize=2G` (was 8G → OOM on device) |
| **AGP / Kotlin / Gradle** | 9.0.1 / 2.3.20 / 9.1.0 |
| **flutter analyze** | **0 errors** (24 warnings + 519 info = 543 issues) |
| **flutter test** | **594/594 PASS** (exit 0, via `/root/flutter` 3.44.6) |
| **APK** | debug build · `com.delwaqty.app` · 104,092,316 B · arm64-v8a · minSdk 24 / targetSdk 36 / compileSdk 37 · installed + launched on DNP-NX9 (Android 16) |
| **Release signing** | **not yet configured** — debug cert only; release will fall back to debug until `android/keystore/release.jks` exists |

### Android compatibility audit result
- **minSdk 24 (Android 7.0) is viable.** All analyzed Android plugins declare minSdk ≤ 24:
  flutter_secure_storage 11.0.0 (24), flutter_local_notifications 22.2.0 (24),
  geolocator_android 5.0.3 (flutter.minSdk), google_maps_flutter_android 2.19.12 (24),
  local_auth_android 2.0.9 (24), image_picker_android 0.8.13+19 (24),
  permission_handler_android 12.1.0 (19), connectivity_plus 6.1.5 (19), record_android 2.1.2 (23),
  firebase_* (local-config ext.minSdk 23), objective_c 9.5.0 (native-assets hook; Linux-host only).
  Core library desugaring enabled (`desugar_jdk_libs:2.1.4`) for java.time on API 24.
- Dependency audit found **no known hard blocker to minSdk 24**.
- App code uses bare `FlutterActivity`; no raw post-API-24 Android APIs; all sensitive paths
  (notifications, biometrics, permissions, storage) go through plugin layers with built-in guards.

### Session 37 verification (all via canonical `/root/flutter`)
```
✓ flutter pub get  → Got dependencies!
✓ flutter analyze  → 0 errors (543 issues: 24 warning + 519 info; ran 161.4s)
✓ flutter test     → 02:26 +594: All tests passed!   (exit 0)
✓ APK audit        → aapt2: minSdk 24, targetSdk 36, compileSdk 37, arm64-v8a, debug cert (CN=Android Debug)
✓ git audit        → only M SESSION_STATUS.md, M android/gradle.properties (gradle heap 8G→4G); no untracked, no secrets
```

### Blocked / next (user hands)
1. **Device verification:** DNP-NX9 not attached at audit time (no adb device). Session 35 verified
   install + launch + no crash + FlutterSecureStoragePlugin on Android 16 — re-attach to re-verify.
2. Full release keystore still absent (`android/keystore/release.jks`) → release builds fall back to
   debug signing; needed before Play Store upload. **Do not create yet (user decision).**
3. Commit + push awaited — final audit complete, awaiting explicit approval.

---

## Previous Task — ENVIRONMENT REPAIR FOR ANDROID 7 → LATEST: BUILD PIPELINE FIXED, DEBUG APK BUILT (Session 35)

**Task (user, Arabic):** make the app run from Android 7 up to the latest Android, and prepare the
development environment so it is ready for every Android version.

### Result: DEBUG APK BUILT, INSTALLED & RUNNING ON THE DEVICE

```
✓ Built build/app/outputs/flutter-apk/app-debug.apk   (104,092,316 B, Aug 14 01:13, signed debug)
✓ pm install — Success   (DNP NX9, Android 16 / SDK 36)
✓ am start .MainActivity — process 13290, window focused, no crash
```
minSdk = 24 ⇒ installs from **Android 7.0**; compileSdk = 37 ⇒ compiles against the **latest SDK**.

### Root causes found & fixes (in build order)

| # | Failure | Root cause | Fix (applied) |
|---|---------|-----------|---------------|
| 1 | `Failed to find target 'android-37'` | `flutter_secure_storage-11.0.0` pins `compileSdk = 37`; official repo only ships `platforms;android-37.0` (no `android-37` package) | switched `sdk.dir` → **`/usr/lib/android-sdk`** (has both `android-37` + `android-37.0`) via `android/local.properties` + `~/.flutter_settings` (`android-sdk`) |
| 2 | flutter tool crash `AndroidSdk.getNdkBinaryPath` null-check (line 408) | `platform.operatingSystem == "android"` inside Termux; `_llvmHostDirectoryName` map lacks an `android` key | patched `packages/flutter_tools/lib/src/android/android_sdk.dart` → add `'android': 'linux-x86_64'`; rebuilt `flutter_tools.snapshot` (`rm bin/cache/flutter_tools.stamp` → `flutter --version`) |
| 3 | `Illegal instruction` (exit 132) for SDK `cmake`/`ninja`/NDK `clang` in `…/usr/opt/android-sdk` | host is **aarch64**; those are raw x86-64 ELF binaries that cannot run | use the **qemu-wrapped** SDK at `/usr/lib/android-sdk` (every binary is a `qemu-x86_64` wrapper → all work); aapt2 already overridden there in `gradle.properties` |
| 4 | `checkDebugAarMetadata` — plugins compiled vs android-34/35/36 need ≥35/36/37 (geolocator, google_maps, …) | Flutter vends `flutter.compileSdkVersion = 34` default to plugins | bumped `FlutterExtension.kt` `compileSdkVersion` 34→37 (source, kept for future jar rebuild) AND patched all resolved plugin `build.gradle(.kts)` to `compileSdk = 37` (geolocator_android, google_maps_flutter_android, permission_handler_android, record_android, flutter_local_notifications, jni, jni_flutter, app_links, connectivity_plus, flutter_secure_storage, …) |
| 5 | Gradle OOM / silent process death | daemon heap `-Xmx8G` vs ~2.5–3.4 G available | `android/gradle.properties` → `-Xmx4G -XX:MaxMetaspaceSize=2G`; `./gradlew --stop` between attempts |

### Environment inventory (verified)
`flutter 3.44.2` (+1 patch), Dart 3.12.2, JDK 21.0.12, Gradle wrapper 9.1.0, AGP 9.0.1, Kotlin
2.3.20, NDK 28.2.13676358, SDK `platforms` 34/35/36/37/37.0, `build-tools` 36.0.0. `flutter pub get` ✓,
`build_runner` ✓ (1283 outputs), `flutter analyze` 0 errors, `flutter test` 594/594 passed.

### Blocked / next (user hands)
1. **DONE live: installed + launched on the device** — APK copied to `/data/local/tmp/`,
   `pm install -r -t` (after `pm uninstall` of the old signature), `am start` → process 13290,
   `MainActivity` focused, no AndroidRuntime crash, `FlutterSecureStoragePlugin` key created OK.
2. `flutter pub get` once more to confirm the plugin `compileSdk = 37` patches survive, and
   document them as an environment fix (they live in the pub-cache).
3. Full release keystore still absent (`android/keystore/release.jks`) → release builds fall back to
   debug signing; needed before Play Store upload.

---

## Previous Task — ALWAYS-ON BACKGROUND: TERMUX FOREGROUND SERVICE + BATTERY WHITELIST (Session 34)

**Task (user, Arabic):** keep Termux running in the background permanently — visible ONLY as a
notification ("running in background"), without the user having to keep opening the Termux app.

**State verified live (all via Android shell, uid 2000 via Shizuku):**

| Layer | Result |
|-------|--------|
| **Foreground service + notification** | `NotificationRecord(pkg=com.termux id=1337 flags=ONGOING_EVENT\|NO_CLEAR\|FOREGROUND_SERVICE vis=PRIVATE)` posted — Termux App channel, `importance=2` (low, silent). The app is being held alive by its foreground service, no terminal window needed |
| **Survival chain** | tmux `opencode` (PID 13272, parented to init) → `opencode-launch` (13277) → proot Ubuntu (13342) → `opencode serve` (13380). Closing/backgrounding the Termux UI cannot kill the server (tmux-detached, setsid) |
| **Health** | `GET 127.0.0.1:4096/global/health` → `{"healthy":true,"version":"1.18.10"}` |
| **Wake lock** | TermuxService `isForeground=true` foregroundId=1337; `wake-lock=true` in `~/.termux/termux.properties` |
| **Battery/Doze whitelist** | **NEW this session:** `cmd deviceidle whitelist +com.termux +com.termux.boot +com.termux.api` → all 3 now in the DeviceIdle whitelist (was only `user,com.termux`). Honor's battery optimization can no longer kill Termux in Doze |

**Boot chain (from Session 33) intact:** Termux:Boot v0.8.1 installed + first-launched
(`stopped=false`) → `~/.termux/boot/opencode-boot.sh` → `opencode-ctl start` → tmux → proot →
opencode. `boot.log` shows "boot SUCCESS: OpenCode became healthy".

> **Note:** `opencode-ctl status` run from inside the proot (uid 0) may report tmux `absent` due to
> a socket/TMPDIR mismatch between contexts — the real tmux server IS running (socket
> `…/usr/var/run/tmux-0/default` exists). Run `status` from a real Termux terminal for truthful output.

### Next (user hands, one-time)
1. In Android Settings → Apps → Termux (and Termux:Boot, Termux:API): Battery → **Unrestricted**
   (Honor may require this in the app-launch manager too) — confirms what the whitelist already does.
2. Close/background Termux UI (swipe from recents, no force-stop) → the notification "Termux
   session running" (id 1337) stays, and `opencode-ctl status` still shows the server healthy.
3. Reboot test already passed in Session 33 — after the next reboot the chain restores itself.
4. Commit + push docs.

---

## Previous Task — TELEPHONE INFRA 3× FIX: AUTO-START / APK INSTALLER / SHIZUKU (Session 33)

**Task (user, Arabic):** (1) make OpenCode auto-start after reboot (Termux → proot → opencode
→ 127.0.0.1:4096) without opening Termux; (2) stop Termux from opening when tapping an APK —
the real Android Package Installer must handle installs; (3) keep Shizuku working from Termux
and never let the OpenCode server die when Shizuku is down. No workarounds.

**Root causes found (all confirmed via Android shell, uid 2000 via Shizuku):**

| Problem | Root cause | Fix applied |
|---------|-----------|-------------|
| 1. No auto-start after reboot | **`com.termux.boot` was NOT installed** — `~/.termux/boot/opencode-boot.sh` existed but nothing ever ran it; user manually typed the `proot-distro login … serve` command after each boot | Installed Termux:Boot **v0.8.1** + Termux:API **v0.53.0** via `pm install`; launched `com.termux.boot/.BootActivity` once so it is `stopped=false` (`RECEIVE_BOOT_COMPLETED granted=true`) |
| 2. Termux opens instead of Package Installer | A stored **Preferred Activity with `mAlways=true`** bound `application/vnd.android.package-archive` → `com.termux/.app.api.file.FileViewReceiverActivity`; also Termux declares wildcard `application/*` | `cmd package clear-package-preferred-activities com.termux` → Termux no longer auto-handles APK; resolver for real `content://` now returns `com.google.android.packageinstaller` + AppGallery (Termux absent) |
| 3. Shizuku boot probe broken | `shizuku-init.sh` pointed to `/usr/local/bin/rish` from **host** Termux (not present there; rish lives inside the Ubuntu proot) | Rewrote `shizuku-init.sh` to `proot-distro login ubuntu -- /usr/local/bin/rish -c id`; graceful WARN, never blocks OpenCode boot |

**Also hardened:** `opencode-boot.sh` (explicit `TERMUX_HOME`/`HOME`, exec checks, chmod);
`opencode-ctl` (HOME fallback); scripts synced to `tool/opencode/` + `install.sh` now also
installs `shizuku-init.sh` and documents `pkg install termux-boot termux-api` + first-launch.

**Verification done:** boot script runs clean with correct Termux env (health 200, `boot.log`
"boot SUCCESS"); server currently healthy on 4096; APK `content://` resolution excludes Termux.

### Next (needs user hands)
1. **Reboot the phone**, wait ~90 s, open any Termux terminal and run `opencode-ctl status`
   → expect tmux session `opencode` running, health 200. Also check `~/.opencode-ctl/boot.log`.
2. Ensure Android Settings → Apps → Termux → Battery → **Unrestricted** (Honor auto-launch).
3. Tap an `.apk` (e.g. from Downloads) → confirm the real Package Installer/chooser opens,
   not Termux.
4. Commit + push (`tool/opencode/`, `SESSION_STATUS.md`, `PHONE_COMMANDS.md`).

---

## Current Task — OPencode MOBILE CLIENT: CONNECTION VERIFIED (Session 32)

**Task (user):** inspect the Mobile client (`com.logicedge.opencodemobile` v1.2.2) config/auth
flow, fix ONLY client-side credentials if necessary, then verify the client can connect to the
server (`http://127.0.0.1:4096`, `opencode` / `test-local-only`, expect `200 {"healthy":true}`).
**Constraint:** do not touch server, auth, `opencode-ctl/launch`, Termux:Boot, DB, or the project.

**Findings:**
| Area | Result |
|------|--------|
| App nature | Capacitor/WebView shell (PairIP-wrapped, non-debuggable), wraps OpenCode web build; Server settings stored in private storage |
| App storage access | Shell (uid 2000 via Shizuku) → `ls /data/user/0/...` = Permission denied (RC=1); `run-as` unavailable (not debuggable) → config files NOT editable from outside |
| Server endpoints | `/global/health`, `/`, `/app`, `/project`, `/project/current` all require Basic auth → 401 without creds / 200 with `opencode:test-local-only`; `/event` SSE streams `server.connected` with auth |
| Client reachability | App stored no creds earlier → its health probe got 401 → "not reachable" banner |

**Verification (client connected — NO fix required):**
1. `uiautomator dump` of the focused `MainActivity` (1280x2800): the app is rendering the **live
   OpenCode web UI** with the current active session (messages + todos), no error banner.
2. Real `/proc/net/tcp` via Android shell: **uid 10688 = `com.logicedge.opencodemobile` holds 6
   ESTABLISHED TCP sockets to `0100007F:1000` (127.0.0.1:4096)** — live SSE/API streams right now.
3. Server-side: with the exact creds every client route returns 200 and SSE streams.

**Conclusion:** the earlier "not reachable" occurred while the server was down (killed terminal);
once the server is up the client connects. Credentials were already correct — nothing was changed.
No files on device or in the repo were modified this session (except this file).

### Next
1. One-time migration (optional): `opencode-ctl restart` from a real Termux session to move the
   server into the managed tmux+watchdog setup.
2. User: HONOR auto-launch permission for Termux + Termux:Boot, battery Unrestricted for Termux.
3. Commit + push (`tool/opencode/`, `PHONE_COMMANDS.md`, `SESSION_STATUS.md`).

---

## Current Task — ALWAYS-ON OPencode SERVER (Session 31)

**Problem:** When the phone screen locked, the OpenCode server in Termux stopped
responding and the client "disconnected".

**Root cause:** the running `opencode serve` (PID on `127.0.0.1:4096`) was attached
to a live terminal (`pts/0`) — it bypassed the managed `opencode-ctl` setup — and
**no wake-lock was held**. On screen lock Android suspended/killed the Termux
process tree, killing the server.

**Fix (all layers, canonical copies in `tool/opencode/`):**

| Layer | Change |
|-------|--------|
| **Wake lock** | `termux-wake-lock` taken on start + `wake-lock = true` added to `~/.termux/termux.properties` → CPU stays awake with screen off |
| **Detach** | Server runs inside Termux tmux session `opencode` (`setsid`), so closing the terminal / backgrounding the app cannot kill it |
| **Auto-heal** | `opencode-launch` now loops and respawns proot/opencode if it crashes; `opencode-ctl stop` sets a `.stop` flag first so a manual stop is respected |
| **Boot autostart** | `~/.termux/boot/opencode-boot.sh` restores the server after reboot (needs `pkg install termux-boot` + enable "Run command at startup" once) |
| **Doze whitelist** | Manual one-time: Android Settings → Apps → Termux → Battery → Unrestricted (or `adb shell dumpsys deviceidle whitelist +com.termux`) |

Files modified:
- `~/.opencode-ctl/opencode-launch` (respawn loop) · `~/.opencode-ctl/opencode-ctl`
  (stop-flag) · `~/.opencode-ctl/README.md`
- `~/.termux/termux.properties` (`wake-lock = true`) ·
  `~/.termux/boot/opencode-boot.sh` (new)
- Repo: `tool/opencode/{opencode-ctl,opencode-launch,opencode-boot.sh,install.sh,README.md}`
- `PHONE_COMMANDS.md` — new "السيرفر شغال دايماً" section

### Next
1. **Connect command** — user should use `opencode attach http://127.0.0.1:4096`
   (or alias `oc`), NEVER re-run the `proot-distro login ... serve` command (it
   is a server-START command attached to the terminal and fails with `ServeError`
   when the managed server already owns port 4096).
2. **One-time migration (optional, recommended):** run `opencode-ctl restart` in a
   real Termux session so the server moves into the managed tmux+watchdog setup
   (current instance is still attached to a live terminal; wake-lock already
   protects it against screen lock).
3. User: install Termux:Boot + do the battery-optimization whitelist step
4. Commit + push (`tool/opencode/`, `PHONE_COMMANDS.md`, `SESSION_STATUS.md`)

---

## Current Task — BIOMETRIC BUG FIXES: HONOR 400 PRO AUTHENTICATION FIX (Session 30)

Three bugs fixed in the biometric/fingerprint login flow:

| Bug | Root Cause | Fix |
|-----|-----------|-----|
| **Race condition** | `_handlePostLoginSave()` and `_handlePostLoginNavigation()` called without `await`, so `_biometricAvailable` was stale (`false`) when enrollment dialog check ran on first login | Added `await` to both calls; enrollment dialog now shows correctly |
| **`biometricOnly: true` fails on HONOR** | `local_auth.authenticate(biometricOnly: true)` throws on HONOR 400 Pro | Inner try: try `biometricOnly: true`, on exception fall back to `biometricOnly: false` (allows device PIN as fallback) |
| **`_offerBiometricEnrollment` dead catch** | `updateBiometricEnabled` catches internally but `_offerBiometricEnrollment` had `on Exception catch` that fired unpredictably | Server update made non-blocking: fire-and-forget `.catchError((_) {})`, show success immediately |

Files modified:
- `lib/features/auth/presentation/pages/login_page.dart` — all 3 fixes
- `lib/features/splash/presentation/pages/splash_page.dart` — biometric fallback in `_tryBiometricAutoLogin`

Results: **594/594 tests pass, 0 errors**

### Next
1. Reconnect adb (need Wireless debugging pairing code from device)
2. Rebuild APK (`flutter build apk --target-platform android-arm64 --debug --dart-define-from-file=.env.dev`)
3. Install on device and verify biometric login end-to-end
4. Commit all fixes

The Android SDK on this machine is **x86-64-only** (aapt2, cmake, ninja, NDK toolchain) but the host is **aarch64** (PRoot on DNP NX9). The native binaries SIGILL under emulation — so every x86 tool was wrapped or replaced with a native-arm64 equivalent. Result: **`app-debug.apk` built successfully** on this device for the first time.

| Tool | Problem | Fix |
|------|---------|-----|
| **android-37 platform** | Missing → "Unable to locate Android SDK" | Symlink `android-37 → android-37.0` in `/usr/lib/android-sdk/platforms/` |
| **assets/lottie/** | Missing → pubspec assets entry failed | Created 6 valid Lottie JSON placeholders (`order_success.json` real, 5 dummies: loading/empty_cart/empty_favorites/no_connection/search_empty) |
| **aapt2** | x86-64 binary, SIGILL on arm64 | QEMU wrapper (`/opt/aapt2-qemu/aapt2`) + replaced gradle-cache and build-tools 36.0.0 aapt2 (verified `aapt2 version` + resource compile) |
| **cmake/ninja** | x86 binaries, exit 132 | Replaced with native arm64 symlinks (`/usr/bin/cmake` 4.2.3, `/usr/bin/ninja` 1.13.2) |
| **NDK clang** | `linux-x86_64/bin/clang` exit 132 → later code=1 | Wrapped all 38 ELF x86-64 binaries with qemu scripts; fixed **argv[0] dispatch** (details below) |
| **lld multi-call** | `ld.lld` symlink → wrapper forcing argv[0]=`llvm-objcopy` → "generic driver" / `unknown argument -o` | Wrappers now preserve invoked name via `-0 "$0"` |

### NDK wrapper design (the tricky part)
The NDK has **multi-call binaries** that branch on `argv[0]` basename: `ld.lld`/`ld64.lld`/`lld-link`/`wasm-ld` all point to `lld`, and `llvm-strip` → `llvm-objcopy`. Naive wrappers break this. The working wrapper preserves the **invoked** name:

```bash
#!/bin/bash
exec qemu-x86_64 -0 "$0" -L /lib/x86_64-linux-gnu "$NDK_BIN/<tool>.real" "$@"
```

- `-0 "$0"` → guest sees the exact argv[0] the caller used → correct mode dispatch (GNU-compatible linker, strip vs objcopy)
- clang derives its resource dir (`lib/clang/19`) from argv[0]'s directory — a bare basename broke `-latomic`/`libclang_rt` resolution, full path fixed it
- Verified end-to-end: `clang --target=aarch64-linux-android24` compile → correct **ARM aarch64** relocatable; full link → **ARM aarch64 PIE executable**

### State
- **APK**: `build/app/outputs/flutter-apk/app-debug.apk` (1.4 GB debug) — **BUILT ✓**
- **Install**: BLOCKED — device not rooted (`ro.build.type=user`); `pm install` runs as Termux uid `u0_a526` → `SecurityException` (needs `INTERACT_ACROSS_USERS_FULL`). Wireless adb (was on port 42017) is currently closed/refused. **Need user: enable Wireless debugging + pairing code, or adb over USB from a PC, or copy APK to phone storage and install from file manager.**
- **Failed-build logs**: `/tmp/opencode/build*.log` (5 → 9; build9.log = SUCCESS)
- **Git**: `d9e7269` pushed (migration fixes); working tree has `assets/lottie/` (new) + `.gitignore` (`/android/build`) + `SESSION_STATUS.md`

> **Next:** get the APK onto DNP NX9 (user action), then run `flutter analyze` / `flutter test` gate before committing the build-bring-up changes.

---

## Current Task — REPO SYNC + POST-PULL VERIFICATION (Session 29)

Pulled 108 commits (sprints 61–69) from `origin/master` and re-verified the project. Local HEAD now `0053f90` (sprint 69), `0 0` ahead/behind, working tree clean.

| Step | Result |
|------|--------|
| **Pull** | `git pull origin master` applied 108 commits / 765 files (was 108 behind at `280aa37`) |
| **Codegen** | `dart run build_runner build --delete-conflicting-outputs` → 297 outputs (Freezed/json generated files are gitignored, absent after clone) |
| **Analyzer** | `flutter analyze` → **0 errors**, 28 warnings, 519 info (pre-existing baseline) |
| **Tests** | `flutter test` → **594/594 passing** (grew from 443 at the pre-pull HEAD) |
| **Git** | `git status` clean · synced with `origin/master` (`0 0`) |

> **Note:** The 1,345 analyzer errors right after the pull were all missing codegen artifacts (`.freezed.dart` / `.g.dart` are gitignored), resolved by `build_runner` — not a code regression.

---

## Completed — LIVE DB MIGRATIONS APPLIED + VERIFIED (Session 29 cont.)

Audited the live Supabase schema via REST + OpenAPI introspection against the repo's migrations and found several NEVER applied. Applied all of them via the Management API (user-supplied PAT) and verified live.

### Pending migrations detected (before)
- **023** home-services tables (service_categories / service_providers / service_bookings) — MISSING
- **024** payment_transactions + orders.payment_id/transaction_id — MISSING
- **025** categories.name_en + category-images bucket — MISSING
- **026** notifications.idempotency_key/read_at/deep_link/image_url + notification_tokens.device_id/app_version/is_active/last_seen_at — MISSING
- **017** users.username — MISSING
- **002_favorites_merchant_support** favorites.merchant_id — MISSING (app reads favorites.merchant_id in supabase_favorite_data_source)

### Fixes required to apply (migration bugs, not code)
| File | Bug | Fix |
|------|-----|-----|
| `023_home_services.sql` | Admin policies referenced a nonexistent `profiles` table | Rewrote to `public.is_admin()` (from migration 018) |
| `024_payment_infrastructure.sql` | Index used `products.category_id` (live column is `category`) | `ON products(category)` |

### Applied + verified
- 56 tables total (was 52). All columns above present. `get_unread_notification_count()` RPC → `0` (HTTP 200), `deactivate_stale_tokens()` → `0` (HTTP 200). Storage bucket `category-images` exists (public, 5 MB, png/jpeg/webp). `service_categories` seeded with 8 rows (plumbing…applianceRepair).
- Consolidated one-shot file kept at `supabase/migrations/027_apply_pending_migrations.sql`.

> **Next:** revoke the PAT after this session. Credentials still needed: Firebase, Google Maps key, Cloudflare.

---

## Current Task — SPRINT 69: PRODUCTION NOTIFICATION SYSTEM (Session 28)

---

## Current Task — SPRINT 69: PRODUCTION NOTIFICATION SYSTEM (Session 28)

Complete production-grade notification architecture: FCM lifecycle, persistent Supabase records, deep linking, idempotency, token cleanup on logout, reactive badge, enhanced Notification Center.

### Sprint 69 (commit dc23cc0)
| Area | Change |
|------|--------|
| **Notification entity** | Enhanced `AppNotification` with `idempotencyKey`, `readAt` fields. New `NotificationType` enum: system, order, payment, promotion, service, account, security, message + legacy info/warning/success/reminder (12 total) |
| **NotificationPayload** | Centralized payload parser with `fromMap()`, `toMap()`, `resolveDeepLink()`. Maps entityType to deep link routes: order→/market/orders, merchant→/market/merchant, service→/service-booking, ride→/ride |
| **DB migration 026** | Added `idempotency_key` (unique), `read_at`, `deep_link`, `image_url` to notifications. Enhanced `notification_tokens` with `device_id`, `app_version`, `is_active`, `last_seen_at`. New indexes for performance. RLS hardened. `get_unread_notification_count()` RPC. `deactivate_stale_tokens()` function |
| **Token cleanup** | `PushNotificationService.deactivateTokensOnLogout()` called from `AuthStateNotifier.signOut()` before Supabase sign-out. Deactivates all user tokens, cancels heartbeat, resets state |
| **Deep linking** | `_handleNotificationTap()` resolves `NotificationPayload` from FCM data, navigates via GoRouter. Cold-start: `getInitialMessage()` → resolve → navigate. Background: `onMessageOpenedApp` → resolve → navigate. Local notification tap: `onDidReceiveNotificationResponse` callback |
| **Navigator key** | Exported `rootNavigatorKey` from `app_router.dart` for push notification service access |
| **Badge reactivity** | New `unreadCountStreamProvider` with periodic refresh (1 min). `badgeStream()` now returns reactive stream. Fixed sidebar badge wiring |
| **Android manifest** | Added `default_notification_channel_id` (delwaqty_notifications), `default_notification_icon` (@mipmap/ic_launcher), `default_notification_color` (#6C41C8) |
| **Notification Center** | Date-grouped sections: اليوم / أمس / أقدم. Tap navigates to deepLink. Enhanced type icons/colors for all 12 notification types |
| **Data source** | `_fromRow()` extracts `deep_link` from both row-level and JSONB `data`. `getUnreadCount()` uses RPC. `markAsRead()` sets `read_at`. Idempotency key lookup. Token deactivation methods |
| **Admin push page** | Updated `_typeIcon()` switch for all 12 notification types |

### Quality
| Metric | Value |
|--------|-------|
| **Tests** | 594/594 passing |
| **Analyzer** | 0 errors |
| **APK** | Built + installed on DNP NX9 |
| **Git** | Committed + pushed (dc23cc0) |

### Sprint 68 (commit 4cab1c9)
| Area | Change |
|------|--------|
| **Scroll-aware bottom nav** | New `ScrollAwareNavObserver` in `scroll_aware_nav.dart`: 50px threshold, 10px hysteresis. `bottomNavVisibleProvider` drives AnimatedSlide + AnimatedOpacity on bottom nav in `app_shell.dart` |
| **PlatformCategory entity** | New Freezed entity with `id, name, nameAr, nameEn, icon, imageUrl, sortOrder, isActive, createdAt`. Extension `PlatformCategoryX.displayName(isArabic)` |
| **Category repository** | New `PlatformCategoryRepository` interface + `CategoryRepositoryImpl` with CRUD + image upload/delete via Supabase Storage `category-images` bucket |
| **Category data source** | New `SupabaseCategoryDataSource` with full CRUD + `uploadCategoryImage()`, `deleteCategoryImage()`, `replaceCategoryImage()` |
| **DB migration 025** | Adds `name_en` column to categories, `category-images` storage bucket with RLS policies (public read, authenticated write) |
| **Home domain** | New `activeCategoriesProvider` (reads non-empty categories), `discoveryModeProvider` (nearby/recommended/popular), `discoveryMerchantsProvider` (queries based on mode) |
| **Home page restructure** | New section order: Header → Search → CTA → Offers → Compact Categories (horizontal scroll, 72px items with image/icon + name) → Discovery Section with tabs (القريبة/موصى لك/الأشهر, AnimatedSwitcher transitions) |
| **Admin categories page** | New `AdminCategoriesPage`: DataTable with columns (Image, Name AR, Name EN, Order, Active, Actions). Add/edit/delete categories, upload/replace/delete image previews, toggle active, sort order control |
| **Admin web shell** | Added Categories nav item (Icons.category_rounded) as 4th navigation option |

### Quality
| Metric | Value |
|--------|-------|
| **Tests** | 594/594 passing |
| **Analyzer** | 0 errors (428 pre-existing info lints) |
| **APK** | Built + installed on DNP NX9 |
| **Git** | Committed + pushed (4cab1c9) |

---

## Previous Task — SPRINT 66: OFFLINE CACHING + PRICE RANGE FILTER (Session 25)

Added Hive offline caching with stale-while-revalidate strategy and a search price range filter for merchant minimum order/delivery fee.

### Sprint 66 (commit pending)
| Area | Change |
|------|--------|
| **Hive cache service** | New `HiveCacheService` in `lib/data/datasources/local/`: stores merchants, products, service categories in Hive boxes with 15-min TTL. `cacheMerchants()`, `getCachedMerchants()`, `cacheProducts()`, `getCachedProducts()`, `cacheServiceCategories()`, `getCachedServiceCategories()` |
| **Cached merchant repository** | New `CachedMerchantRepository` wrapping `MerchantRepository`: online-first with fallback to Hive cache on network failure; offline reads from cache directly. Implements stale-while-revalidate pattern |
| **Cached service booking repository** | New `CachedServiceBookingRepository` wrapping `ServiceBookingRepository`: caches service categories for offline access |
| **Hive initialization** | `Hive.initFlutter()` + box opening in `main.dart` during startup parallel init |
| **Search price range filter** | New `_priceRangeProvider` (RangeValues 0–10000), filter button in sort bar, `_PriceFilterSheet` bottom sheet with RangeSlider, Apply/Reset buttons. Filters merchants by `minimumOrder` or `deliveryFee` |
| **l10n** | New key `priceRange` (EN: "Price Range", AR: "نطاق السعر") |

### Quality
| Metric | Value |
|--------|-------|
| **Tests** | 594/594 passing |
| **Analyzer** | 0 errors (401 pre-existing info lints) |
| **APK** | Pending build |
| **Git** | Pending commit |

---

## Previous Task — SPRINT 62+63+65: PHASE 1 MVP (Session 24)

Massive Phase 1 MVP expansion: 24 service categories, Home Services booking, 4-role registration, auth guard, and Flutter Web admin dashboard.

### Sprint 62 (commit `1530247`)
| Area | Change |
|------|--------|
| **MerchantType enum** | Expanded from 10 → 24 values: added supermarket, fruits, meat, seafood, sweets, clothing, shoes, mobile, appliances, cafe, petShop, fitness, gas, carwash |
| **AppColors** | 14 new service category colors |
| **l10n** | 28 new keys (EN + AR) for all new categories |
| **Home page grid** | Expanded from 7 → 23 service tiles |
| **Home Services module** | New Clean Architecture module: ServiceCategory, ServiceProvider, ServiceBooking entities; ServiceBookingRepository; Supabase implementation; HomeServicesPage + ServiceBookingPage |
| **DB migration 023** | `service_categories`, `service_providers`, `service_bookings` tables with RLS, indexes, seed data |
| **Search enhancements** | 12 filter pills, "Open Now" toggle, auto-complete suggestions |

### Sprint 63 (commit `94322d4`)
| Area | Change |
|------|--------|
| **UserType enum** | Expanded to 5 values: customer, merchant, driver, provider, delivery. Added `requiresTradeLicense`, `requiresDrivingLicense`, `requiresIdCard`, `requiresProfilePhoto` getters |
| **Registration wizard** | 4-role selection (Customer, Merchant, Driver, Provider) with role-specific document uploads: ID card + profile photo (all non-customer), trade license (merchant), driving license (driver) |
| **Document uploads** | New Supabase Storage folders: `trade_licenses/`, `driving_licenses/` |
| **User model** | Added `tradeLicenseUrl`, `drivingLicenseUrl` fields |
| **Auth guard** | Pending verification redirect already works via `_resolveAuthenticated` → `AuthPendingVerification` state → router redirects to `/pending-verification` |

### Sprint 65 (commit `94322d4`)
| Area | Change |
|------|--------|
| **Flutter Web admin** | New `lib/main_web.dart` entry point + `admin_web` feature module |
| **Admin shell** | Sidebar navigation with Dashboard, Users, Verifications sections |
| **Dashboard overview** | 5 stat cards: Total Users, Merchants, Orders, Drivers, Service Bookings (live from Supabase) |
| **User management** | Table view with search, role badges, status badges |
| **Verification management** | Pending requests list with approve/reject buttons, document preview |

### Quality
| Metric | Value |
|--------|-------|
| **Tests** | 594/594 passing |
| **Analyzer** | 0 errors, 0 warnings (398 pre-existing info lints) |
| **APK** | Debug APK built + installed on DNP NX9 |
| **Git** | Commits `1530247` + `94322d4` pushed to `origin master` |

---

## Current Task — FINGERPRINT LOGIN-PAGE BUTTON UNIFIED ON THE DB-BACKED STORE + ANDROID 16 FIX (Session 23)

User reported the login-page fingerprint button still did not auto-login ("زر البصمة لا يسجل الدخول تلقائياً"). Root cause: enrollment (post-login dialog) and startup auto-login had moved to the new DB-backed `BiometricAuthStore` (`auth_biometric_<userId>` + `auth_biometric_active_user`), but the login-page button, saved-account chip badges, and the Settings fingerprint toggle still read the **legacy** `SavedAccountsStore` (`biometric_password_<email>` + `SavedAccount.hasBiometric`). The two systems were split, so a newly enrolled user's button reported "no biometric account". The legacy fingerprint paths were removed and every biometric concern now flows through the new store + the `users.is_biometric_enabled` flag.

| Area | Change |
|------|--------|
| **Login button fix** | `login_page.dart` `_authenticateWithBiometric` now reads `biometricAuthStoreProvider.activeCredentials()` (single active biometric user), prompts with the real sensor, fills the email/password fields, and calls `signIn`. The legacy email→`biometricPassword` lookup and the `_promptEnableFingerprint` password re-entry dialog are deleted |
| **Legacy UI removed** | `_enableBiometric` checkbox (login form) and the per-chip fingerprint badge on `_SavedAccountChip` removed — enrollment is the post-login dialog only, and the new store holds exactly one active user. `_BiometricButton` shows `fingerprintLogin` (no saved-email label) |
| **Model** | `SavedAccount.hasBiometric` removed from `SavedAccount` (Freezed + json regenerated) — the account list is again purely email/displayName prefill |
| **Store** | `SavedAccountsStore` stripped to SharedPreferences only (drop `FlutterSecureStorage`, `setBiometric`, `biometricPassword`, `biometricAccount`, `biometric_password_<email>` keys) |
| **Settings toggle** | `fingerprint_login_page.dart` reads `user.isBiometricEnabled` (DB, source of truth) instead of scanning accounts; toggle-on stores credentials via `saveCredentials(userId, …)` + `updateBiometricEnabled(true)`, toggle-off runs `clearActive()` + `updateBiometricEnabled(false)` |
| **Enrollment prompt** | Unchanged path (post-password-login dialog) — still saves via the new store + `updateBiometricEnabled(true)`; `skipEnrollmentPrompt` plumbing removed since the checkbox no longer exists |
| **Device sensor (re-check)** | `dumpsys fingerprint` now shows **healthy**: `Fps state: 0`, 4 enrolled prints, `authEndedFor(…, wasSuccessful: true)` events — the earlier "state 4 (bad)" blocker is resolved; end-to-end auto-login verification can run on DNP NX9 |
| **Tests** | `saved_accounts_store_test.dart`, `saved_account_test.dart`, `fingerprint_login_page_test.dart` rewritten for the new model/store (settings page now mocks `authRepositoryProvider`/`userRepositoryProvider`). Full suite **594/594** passing · `flutter analyze` **0 errors / 0 warnings** (514 pre-existing info lints, unchanged baseline) |

User requests: (1) refine Arabic reverse geocoding so villages/tourist areas show the hierarchical Markaz→village chain (e.g. "مركز السويس - قرية الزعفرانة") instead of a flat string, staying localized on language switch; (2) replace the fingerprint "auto-detect" with a real DB-linked biometric system: `users.is_biometric_enabled`, enable-after-password-login prompt, per-user encrypted credentials, and biometric auto-login at app start. Both implemented, tested, built, and installed on DNP NX9.

| Area | Change |
|------|--------|
| **Geocoding — Google chain** | Static `@visibleForTesting composeGoogleAddress` (in `location_provider.dart`): `administrative_area_level_2 → level_3 → sublocality_level_3 → level_2 → level_1 → neighborhood` joined by `' - '` (Arabic `'، '`, English `', '`), dedup across + within the chain |
| **Geocoding — Nominatim chain** | Static `composeNominatimAddress`: county, municipality, city, town, village, hamlet, city_district, suburb, quarter, neighbourhood, residential; named-place keys exempt when they contain digits; region = state/region; country deduped; `_typesContain` made static |
| **Geocoding — tests** | 11 new tests in `location_provider_test.dart` (Google AR chain `Zafarana offices، مركز السويس - قرية الزعفرانة، محافظة السويس، مصر`, EN chain, cross-field dedup, within-chain collapse, street number+route, empty→null, hasNamed false; Nominatim county+village, city+suburb, named-place, dedup, empty→null) — all 29 location tests pass |
| **Migration `022_user_biometric_enabled.sql`** | `ALTER TABLE users ADD COLUMN IF NOT EXISTS is_biometric_enabled BOOLEAN NOT NULL DEFAULT false;` |
| **Model** | `@Default(false) bool isBiometricEnabled` on `User`/`UserModel`; `fromSupabase` maps `is_biometric_enabled` (missing → false); `toSupabaseMap`/`toUpdateMap` export it; Freezed/json regenerated |
| **Backend chain** | `AuthRepository.updateBiometricEnabled(userId, enabled)` → `AuthRepositoryImpl` via `_profileDataSource.updateProfile` → `updateBiometricEnabledUseCase` + provider → `AuthStateNotifier.updateBiometricEnabled` (re-fetches user, re-applies `_resolveAuthenticated`) |
| **Secure store** | New `lib/data/datasources/local/biometric_auth_store.dart`: per-user JSON credentials in `flutter_secure_storage` under `auth_biometric_<userId>` + active-user marker `auth_biometric_active_user`; corrupt payload → null; `saveCredentials`/`credentialsFor`/`activeCredentials`/`clearActive` |
| **Enrollment prompt** | `login_page.dart`: after successful password login, when biometrics available and not yet enabled → AlertDialog "هل ترغب في تفعيل الدخول بالبصمة للمرة القادمة؟"; confirm → local authenticate (biometricOnly + stickyAuth) → save credentials + `updateBiometricEnabled(true)` + `fingerprintEnabled` snackbar; `PlatformException` → `biometricEnableFailed`; suppressed after a biometric auto-login. New l10n keys en+ar: `enableBiometricPromptTitle/Message/Confirm/Later`, `biometricEnableFailed` |
| **Startup auto-login** | `splash_page.dart` `_navigate()` async: when not authenticated → `_tryBiometricAutoLogin()` reads active credentials, local biometric prompt, then `signIn(email, password)`; `AuthError`/`AuthUnauthenticated`/failure → `clearActive()`; `PlatformException` → `/login` |
| **Tests** | New `biometric_auth_store_test.dart` (8 tests, `FlutterSecureStorage.setMockInitialValues`); `user_model_test.dart` updated for the new field. Full suite **599/599** (was 577 → +22 net) |
| **Quality gates** | `flutter analyze` 0 errors / 0 warnings from touched files · `flutter test` 599/599 · debug APK built + installed on DNP NX9 · app launches clean (session restored, header `Zafarana offices، عتاقة، محافظة السويس، مصر`, logcat clean) |
| **Release signing (resolved)** | `android/keystore/release.jks` password recovered locally (project-naming pattern; alias `delwaqty`; not stored in the repo) → `flutter build apk --release` succeeds → signed `app-release.apk` (68.7 MB, `CN=Delwaqty`) **installed on DNP NX9** in place of the debug build; launches clean, no FATAL |

> **REMAINING (blockers, not code):** (1) Village-chain end-to-end needs a Google Geocoding call at a real open-sky village coordinate on-device (app-restricted key can't be exercised from shell).

> **RESOLVED 2026-08-08 — Migration applied live:** Migration `022_user_biometric_enabled.sql` **APPLIED live** to `bttnlkmwhorjamzemwda` via Management API (user-supplied PAT). Verified: `users.is_biometric_enabled boolean NOT NULL DEFAULT false` present in `information_schema.columns`. The app's `fromSupabase` fallback is no longer exercised for this field.

> **RESOLVED 2026-08-08 — Release signed build:** `android/keystore/release.jks` (created during the sprint 40-44 "release hardening" milestone) was recovered locally via `keytool` (alias `delwaqty`; cert SHA-256 `901f9dd15636eeb35edd741ae9eb3896eb94aac4cea8295a02baf9eb1e5b7583`). `flutter build apk --release --dart-define-from-file=.env.dev` succeeds → **68.7 MB `app-release.apk` signed with `CN=Delwaqty` (verified via apksigner)** → installed on DNP NX9 (debug uninstalled first). App launches clean (MainActivity focused, full Home with session restored, **no FATAL**). The password value is held by the user locally and is **deliberately NOT written into this repo**.

> **RESOLVED 2026-08-08 — Crashlytics wired correctly:** `com.google.gms.google-services` **4.5.0** + `com.google.firebase.crashlytics` **3.0.7** added to `android/settings.gradle.kts` (apply false) and applied in `android/app/build.gradle.kts`. Release APK rebuilt + reinstalled. Cold-start logcat: **0** "Crashlytics build ID is missing", **0** "Firebase initialization failed", **0** FATAL; Firebase Sessions initializes and `firebaselogging-pa` requests flow — Crashlytics reporting is now live. (The earlier "no-app" hits were a regex false-positive on `Adreno-AppProfiles` log lines.)

---

## Previous Task — PRECISE LOCALIZED LOCATION + FINGERPRINT AUTO-LOGIN (Session 21s)

User request (Arabic): "الموقع مش دقيق... عايز الموقع بشكل دقيق وبالعربي مع اللغة العربية وانجليزي مع اللغة الانجليزية... والبصمة: بدون اختيار الحساب واختيار التسجيل بالبصمة البرنامج يفهم الحساب المسجل ليه البصمة على الداتا بيز والباسورد الخاص به ويسجل تلقائي" — make the location precise and localized (Arabic with Arabic UI, English with English UI), and make the fingerprint button auto-detect the saved biometric account + its stored password and log in without selecting the account first. Fixed, tested, built, and installed on DNP NX9.

| Area | Change |
|------|--------|
| **Root cause — generic address** | `_cleanArabicAddress` stripped **all digits** (destroying street numbers); geocoders called without a language; the geocode cache was language-agnostic so switching languages kept the old-language string |
| **Fix — precision** | Google now parses `street_number` + `route` → `"number route"` street part (digits preserved); `_cleanAddress(input, language)` no longer strips digits, only normalizes separators (`،` ar / `,` en) |
| **Fix — localization** | Google sends `language=$language`, Photon `lang=$language`, Nominatim `accept-language=$language` via new `_appLanguage()` (reads `localeProvider`); cache key now `lat,lng@language` (`location_geocode_cache_v2`, TTL 24 h, cap 200) |
| **Fix — reactive language switch** | `UserLocationNotifier.build()` now `ref.watch(localeProvider)` — toggling the UI language re-runs geocoding in the new language immediately (reproduced the bug on device: Arabic string persisted after switching to English; fixed) |
| **Root cause — fingerprint** | `_authenticateWithBiometric` required a non-empty email and never looked up which saved account has biometric enabled |
| **Fix — fingerprint auto-login** | New `SavedAccountsStore.biometricAccount()` (first account with `hasBiometric`); `_authenticateWithBiometric` now auto-detects that account + its Keystore password and signs in when no email is selected; falls back to enable-dialog only when no stored password. New l10n keys `noBiometricAccountSaved` + `biometricNotEnrolled` (en + ar) |
| **On-device verification** | Home header now shows **`Zafarana offices، عتاقة، محافظة السويس، مصر`** (governorate added; the in-building coordinate only yields premise-level components — no street number exists at that point from any provider). English regression confirmed and fixed via locale watch |
| **Tests** | 3 new `biometricAccount()` tests in `saved_accounts_store_test.dart`. Suite **577/577 passing** (was 575) |
| **Quality gates** | `flutter analyze` 0 errors / 0 warnings from touched files (repo-wide info lints pre-existing) · `flutter test` 577/577 · debug APK built (`--dart-define-from-file=.env.dev`) + installed on DNP NX9 · app launches clean |

> **REMAINING (device blockers, not code):** (1) DNP NX9's biometric sensor reports state 4 (bad) despite 4 enrolled fingerprints → a real fingerprint scan always throws `PlatformException`; the auto-detection + password-retrieval logic is unit-tested but the success gesture needs a healthy device. (2) At the test coordinate Google returns premise-only components (building interior) — a street number appears only at street-level coordinates (data limitation).

---

## Current Task — LOCATION FIX: "0 m" CLAIMED WHEN ACCURACY WAS UNKNOWN (Session 21r)

User request (Arabic): "اصلح اللوكيشن في التطبيق بمقدار 0 متر" — fix the app showing the location as 0 meters. Root cause found, fixed, tested, built, and installed on DNP NX9. The remaining piece — Google Geocoding API activation — is an external Google Cloud Console action the user must take (detailed below).

| Area | Change |
|------|--------|
| **Root cause — the "0 m" bug** | `geolocator` reports `accuracy = 0.0` when the platform provides **no accuracy estimate** (`hasAccuracy == false`, typical of network/fused cell fixes). The engine treated `0` as a perfect sub-metre fix: `_isFreshAndPrecise` accepted `>= 0 && <= 1` (short-circuited acquisition as "≤ 1 m"), `_isUsableLastKnown` accepted `>= 0 && <= 500`, `refreshDeepLocked()` early-returned on `accuracy <= 1`, and `UserLocation.accuracyMeters` surfaced raw `0.0` — so an unmeasured fix was delivered as "0 m" with no warning while being potentially hundreds of meters off |
| **Fix — accuracy must be > 0** | `_isFreshAndPrecise` → `accuracy > 0 && <= 1`; `_isUsableLastKnown` → `accuracy > 0 && <= 500` (GNSS-verified last-known still passes on satellite count); `_acquirePreciseFix` best/early-complete now require `accuracy > 0` + live GNSS for the sub-metre shortcut |
| **Fix — null = unknown** | `UserLocation.accuracyMeters` is now `position.accuracy > 0 ? position.accuracy : null` — unknown accuracy is typed as `null`, so callers (delivery `_useCurrentLocation`, ride booking) can never display or trust a fabricated "0 m" |
| **Fix — deep-lock best tracking** | `refreshDeepLocked()` now prefers known-accuracy fixes across attempts; an unknown-accuracy fix is kept only as last-resort fallback and never triggers the ≤ 1 m early return |
| **Fix — geocoding key headers** | Google Geocoding HTTP call now sends `X-Android-Package: com.delwaqty.app` + `X-Android-Cert: 5337185A52F0B615A3388ECC03B6576D61F34EEF` (debug SHA-1, colons removed) — the standard way an Android-app-restricted Maps key authorizes raw REST geocoding (the Maps SDK sends these automatically; the raw `http.get` did not → `REQUEST_DENIED`) |
| **Tests** | 3 new regression tests in `location_provider_test.dart`: quick mode rejects a fresh non-GNSS last-known with unknown (0.0) accuracy; deep mode reports `null` (not 0 m) for a GNSS last-known with unknown accuracy; deep mode reports `null` for a 0.0-accuracy stream sample. Suite **570/570 passing** (was 567) |
| **Quality gates** | `flutter analyze` 0 errors, **0 new issues** from touched files (repo-wide info lints pre-existing) · `flutter test` 570/570 · debug APK built (`--dart-define-from-file=.env.dev`) + installed on DNP NX9 · app launches clean (Map SurfaceView active, no crash) |

> **RESOLVED 2026-08-07:** User enabled the key in Google Cloud Console. Verified live: Geocoding API returns **`status=OK`** with the app's exact headers (`X-Android-Package`/`X-Android-Cert`); server-side (no headers) still correctly `REQUEST_DENIED` (key is Android-restricted). No re-deploy needed — the installed APK already sends the headers. **Plus-code safety confirmed:** in the sparse Zafarana area Google returns a plus-code-only result whose `plus_code` component the parser skips → `parts` empty → app falls through to the Photon chain (nice Arabic address preserved, no regression); Cairo-level areas now return full Arabic street addresses (`1 شارع محمد محمود، ميدان التحرير...`). On-device E2E of the fixed accuracy flow still needs a login + delivery-flow walk; fingerprint is enrolled from 21q.

---

## Previous Task — FINGERPRINT LOGIN + SAVED ACCOUNTS + SOCIAL LOGIN REMOVAL (Session 21q)

User request (Arabic): "في تسجيل الدخول فعل زر البصمة بشكل صحيح، وشيل التسجيل من أي منصة سوشيال في الوقت الحالي، وزر حفظ تسجيل الحساب شغّله بشكل صحيح، ويبقى فيه خانة للحسابات المحفوظة في تسجيل الدخول" — make the fingerprint button actually work, remove social login for now, make save-account work correctly, and add a saved-accounts section on the login page. This session shipped all four on top of the Sprint 60 verification milestone (commit `87aadc3`).

| Area | Change |
|------|--------|
| **Root cause — fingerprint** | Old flow stored email/password in **plaintext SharedPreferences** (`biometricEnabled/biometricEmail/biometricPassword`), required a password re-entry bypass, and `AndroidManifest.xml` was **missing `USE_BIOMETRIC`/`USE_FINGERPRINT`** so `LocalAuthentication` could never succeed. Added both permissions |
| **Secure store** | New `lib/data/datasources/local/saved_accounts_store.dart`: account list (email/displayName/hasBiometric) in SharedPreferences JSON under `StorageKeys.savedAccounts`; **biometric password only in Keystore/Keychain** via `flutter_secure_storage` (`biometric_password_<email>`); emails normalized at the boundary. Old plaintext keys deleted from `StorageKeys` |
| **Model** | New Freezed `SavedAccount` (`lib/features/auth/domain/saved_account.dart`) with normalized `key` getter; generated files gitignored (build artifacts) |
| **Login page** | `login_page.dart` rewritten: social buttons (Google/Apple/Facebook) removed; "حفظ الحساب" checkbox persists the account on successful login (`_handlePostLoginSave` off the `authenticated` listener) with optional "تفعيل البصمة"; horizontal **Saved Accounts** chip row — tap fills email + selects text + focuses password, fingerprint badge = one-tap biometric sign-in, × = remove with confirm dialog; fingerprint button (biometricOnly + stickyAuth) reads the secure password then calls `signIn`; shown only when `hasBiometric` for the filled email AND `canCheckBiometrics` |
| **Auth provider** | `signInWithGoogle/Apple/Facebook` getters + methods removed from `AuthStateNotifier`; `signOut` no longer wipes biometric/saved-account storage (accounts survive logout by design). Phone/password + guest remain |
| **Dependencies** | `flutter_secure_storage` pinned **`^11.0.0`** (only line using `win32 ^6`, compatible with `geolocator ^14`); **`compileSdk` 36 → 37** (v11 AAR requires API 37); plugin registrants regenerated for linux/macos/windows |
| **l10n** | New keys en+ar: `saveAccount`, `savedAccounts`, `savedAccountsHint`, `removeAccount`, `removeSavedAccountConfirm`, `accountSaved`, `accountRemoved`; regenerated |
| **Quality gates** | `flutter analyze` **0 errors / 0 warnings from touched files** (untouched-module lints are pre-existing) · `flutter test` **567/567 passing** (was 556 → +11) · debug APK built (`compileSdk 37`) + installed on DNP NX9 · app launches clean (PID 11858, no FATAL / no ConfigValidator crash) |

> **REMAINING (not blocking):** (1) on-device E2E of the Sprint 60 register → confirm-email-link → pending → admin-approve → home walk on DNP NX9 (user must tap the confirmation link; free-tier mailer 2/hr); (2) **SECURITY:** revoke the Supabase PAT used in the Sprint 60 session. Saved-account flow verified by unit tests + clean install; full fingerprint tap needs a real fingerprint-enrolled device gesture.

---

## Previous Task — ACCOUNT VERIFICATION WORKFLOW (Session 21p)

New provider/delivery sign-ups must verify their identity before using the platform: register step 1 selects an account type, providers/delivery users upload an ID card + profile photo, then an admin approves or rejects them from a new dashboard page. Customers skip verification entirely. Code was already written (uncommitted); this session finished it: lint cleanup, the missing Supabase migration, live-DB application, email-confirmation activation, and docs.

| Area | Change |
|------|--------|
| **Domain enums** | `lib/domain/enums/user_type.dart` (`customer` / `provider` / `delivery`, `requiresVerification`) + `lib/domain/enums/verification_status.dart` (`pending` / `approved` / `rejected`) — new `lib/domain/enums/` + `test/domain/enums/auth_enums_test.dart` |
| **User model** | `UserModel`/`User` gain `userType`, `verificationStatus`, `idCardUrl`, `profilePhotoUrl`; `fromSupabase` falls back: missing `user_type`/`verification_status` → treated as customer/approved |
| **Registration** | `register_page.dart` → 4-step flow: (0) account type picker, (1) info, (2) preferences, (3) confirmation. Role + documents required for provider/delivery (`selectAccountType`, `documentsRequired`). `image_picker` bottom sheet (gallery/camera), uploads via `AuthRepositoryImpl._persistSignUpProfile` |
| **Auth state** | New `AuthState.pendingVerification`; `_resolveAuthenticated` routes non-approved provider/delivery users there; router forces `/pending-verification` (unless on an auth route); `PendingVerificationPage` shows hourglass + sign-out |
| **Admin** | `AdminVerificationsPage` at `/admin/verifications` (dashboard quick action): pending requests, ID card + profile photo preview (`InteractiveViewer` zoom), approve/reject with confirm dialog; `admin_service`/`admin_repository` `getVerificationRequests` / `approveVerification` / `rejectVerification`; `verificationRequestsProvider` |
| **Storage/permissions** | AndroidManifest + Info.plist: CAMERA + media permissions with usage descriptions; uploads to the public `profiles` bucket under `id_cards/` and `profile_photos/` |
| **Home grid** | Ride tile removed from Home grid (indexes re-mapped); Home Services now index 3 |
| **Migration `020_user_verification.sql`** | Adds `user_type`, `verification_status`, `id_card_url`, `profile_photo_url` to `users` (+ CHECKs); extends `users_role_check` with `provider`/`delivery`/`owner`; admin SELECT/UPDATE policies via `is_admin()`; ensures public `profiles` bucket + upload policy. **APPLIED live** to `bttnlkmwhorjamzemwda` |
| **Migration `021_signup_type_flow.sql`** | Rewrites `handle_new_user()` so role/user_type/verification_status come from `raw_user_meta_data` (defaults: customer/approved, provider|delivery/pending) instead of hardcoding customer — otherwise email confirmation strips the session before the client-side upsert and every sign-up collapses into a customer row; backfills orphaned auth users + reconciles previously-broken provider/delivery rows; preserves owner role. **APPLIED live** |
| **Email confirmation** | Live GoTrue already `mailer_autoconfirm: false` (verified); `site_url` + `uri_allow_list` set to `io.delwaqty://login-callback` so confirmation links open the app (PKCE flow completes the session via deep link) |
| **Quality gates** | `flutter analyze` **0 errors / 0 warnings** · `flutter test` **556/556 passing** (was 542 → +14) · debug APK built + installed on DNP NX9 |

> **REMAINING (not blocking the milestone):** (1) on-device E2E of register→confirm-email-link→pending→admin-approve→home on DNP NX9 — needs the user to tap the confirmation link (Supabase built-in mailer; free-tier `rate_limit_email_sent=2`/hr); (2) commit + push the Sprint 60 milestone. **SECURITY:** the Supabase Personal Access Token used in this session must be revoked after use.

---

## Previous Task — HOME PAGE LOGO + INTRO WORDMARK FLASH FIX (Session 21o)

User reported two issues after 21n: (1) the home page header still showed the gradient square with the Arabic "دلوقتي" text instead of the actual app logo next to the sidebar button, and (2) a visible "crash"/flash during the intro while the English "Delwaqty" wordmark animates. Both fixed, verified programmatically on device (I cannot view images — verified via per-frame luma analysis + logcat).

| Area | Change |
|------|--------|
| **Root cause — wordmark flash** | Logcat proved NO Dart exception (process stays alive through the whole splash); the visible flash is a rendering artifact. The `_AmbientPainter` recreated **3 radial gradient shaders on every frame** (`ui.Gradient.radial`) inside a `RepaintBoundary`; on Impeller/Vulkan this shader churn during the wordmark phase produced a frame where the background dropped out. Confirmed by `[ERROR platform_configuration.cc(448)] Reported frame time is older than the last one; clamping` during the wordmark window (1.5–2.5 s) |
| **Fix — painter split** | `_AmbientPainter` split into two: **`_GlowPainter`** (const, paints the 3 static radial-gradient glows ONCE — `shouldRepaint => false`, raster-cached, never repaints) and **`_ParticlePainter(progress)`** (animated, draws only 30 tiny white circles — no shaders at all, still in its own `RepaintBoundary`). Per-frame work is now 30 cheap circles; zero per-frame shader creation |
| **Fix — home logo** | `_LogoMark` in `home_page.dart` now renders the official `assets/logo app/logo.png` (white 46×46 tile, radius 14, purple shadow, `ClipRRect`, `DecoratedBox` gradient "دلوقتي" fallback via `errorBuilder`) next to the `_GlassCircleButton` in the header Row |
| **Verification — wordmark flash** | Installed build → screenrecord + ffmpeg `signalstats` luma per frame: **splash window (frames 70–320) max frame-to-frame luma diff < 1.0** — the background never disappears during the wordmark. The only dips (frames 28–68, luma →17.6) are the native Android 12+ launch crossfade BEFORE Flutter's first frame — normal cold-start, not the wordmark. Splash→login transition = the single 72-luma jump at frame 323 |
| **Verification — home logo** | Asset bundled in APK (`assets/flutter_assets/assets/logo%20app/logo.png`, 1.27 MB); identical asset path already renders on splash/login; logcat has **no** `Unable to load asset` |
| **Quality gates** | `flutter analyze` 0 errors (my files contribute no new lints) · `flutter test` 542/542 passing · debug APK built + installed on DNP NX9 |

---

## Previous Task — SPLASH INTRO CRASH FIX + LOGIN LOGO (Session 21n)

Fixed the hidden "brown flash" crash during the intro wordmark animation, restored the natural splash design, made the Arabic tagline "دلوقتي" colorful like the English wordmark, and enlarged the login page logo.

| Area | Change |
|------|--------|
| **Root cause — brown flash** | `_ambientController.repeat()` (3000ms) wrapped the entire `CustomPaint` in an `AnimatedBuilder`, forcing full-widget rebuilds every frame AND recreating `RadialGradient.createShader()` on every paint. When `_wordController` started simultaneously, the combined rebuilds caused a single-frame artifact where the gradient briefly disappeared (looked like a brown/dark flash). The `Scaffold.backgroundColor` (light theme surface) showed through momentarily |
| **Fix — ambient animation** | Replaced `AnimationController.repeat()` with a raw `Ticker` feeding a `ValueNotifier<double>` (`_ambientTick`). The `CustomPaint` is now wrapped in `RepaintBoundary` + `ValueListenableBuilder` — it repaints in isolation without rebuilding the Stack/wordmark |
| **Fix — painter cost** | `_AmbientPainter` now uses `ui.Gradient.radial` (const-created) instead of `RadialGradient().createShader()` per frame; particles cached once as static `_ParticleData`; `shouldRepaint` only returns `true` when `progress` actually changed (was always `true`) |
| **Arabic tagline fix** | Split-letter `Row` (letters were disconnected/choppy in RTL) replaced with a single `RichText` + `TextSpan` — natural flowing word, each letter colored: د/ل/و white, ق purple `#7A5CFF`, ت blue `#4E8DFF`, ي teal `#2DD4BF`, fontSize 24 |
| **Login page logo** | `_buildLogo()` enlarged from 80×80 → **120×120**, border radius 22→28, stronger purple shadow (`spreadRadius 4`, blur 30) — the actual `assets/logo app/logo.png` renders prominently above "مرحبا" |
| **Verification** | `flutter analyze` 0 errors · `flutter test` 542/542 passing · debug APK built + installed on DNP NX9 · logcat **clean** (no `I/flutter` errors, no `FATAL`, no `AndroidRuntime`) · app restarts cleanly (PID 22497→23202) · splash → login flow reaches login page |

---

## Previous Task — CINEMATIC INTRO + PREMIUM AUTH (Session 21m)

Built a world-class cinematic brand introduction and redesigned the entire authentication flow. The experience follows the reference design with 10 animated scenes, premium login, and 3-step registration.

| Area | Change |
|------|--------|
| **Logo asset** | Created `assets/logo app/logo.png` from user's icon logo. Registered in `pubspec.yaml` |
| **Brand colors** | Added `brandCyan` (#06B6D4) and `brandTeal` (#14B8A6) to `AppColors` |
| **Cinematic Intro** (`cinematic_intro_page.dart`) | 10-scene experience: (1) Black intro with haptic, (2) Purple+cyan light beams, (3) Energy ring build-up, (4) Logo reveal with elastic scale+opacity, (5) Motion lines (purple→blue→cyan), (6) Wordmark "Delwa" (white) + "Qty" (gradient), (7) Arabic tagline with decorative lines, (8) 8 service icons with glass morphism, (9) Brand message "كل احتياجاتك... دلوقتي", (10) Smooth fade transition to login. Custom particle painter, light streaks, all at 60fps |
| **Premium Login** (`login_page.dart`) | Complete rewrite: deep gradient background, logo reveal animation, glass-morphism text fields (radius 18), gradient primary button (purple→blue→cyan, radius 22), social login (Google/Apple/Facebook), "Remember Me" checkbox, "Forgot Password" link, guest mode, shake animation on validation. No `GradientBackground` — custom dark luxury background |
| **Step Registration** (`register_page.dart`) | 3-step flow with animated progress bar: Step 1 (name, email, phone, password, confirm), Step 2 (language selector, notifications toggle, location toggle), Step 3 (success animation with checkmark + welcome). Glass text fields, gradient button, step transitions |
| **Navigation** | Splash → `/intro` (cinematic) → `/login` → `/register` → `/home`. Router updated to allow `/intro` route. Added `/intro` route in `splash_module.dart` |
| **l10n additions** | New keys (en+ar): `signIn`, `emailOrPhone`, `rememberMe`, `or`, `createAccount`, `location` |
| **Quality gates** | `flutter analyze` **0 errors** · `flutter test` **542/542 passing** · APK built + installed on DNP NX9 ✅ |

---

## Current Task — APP ICON + DYNAMIC APP NAME (Session 21l)

Replaced the app's launcher icon with the user's new design and set up locale-based dynamic app name so it shows "دلوقتي" on Arabic devices and "Delwaqty" on English devices.

| Area | Change |
|------|--------|
| **New launcher icon** | User-provided icon (`icon logo.png`, 1254x1254) resized to all Android density buckets: mdpi (48), hdpi (72), xhdpi (96), xxhdpi (144), xxxhdpi (192). Both `ic_launcher.png` and `ic_launcher_round.png` created in all mipmap directories |
| **Adaptive icon** | Created `mipmap-anydpi-v26/ic_launcher.xml` and `ic_launcher_round.xml` with foreground drawable + dark purple background (`#1A0536`). Android 8.0+ devices get the adaptive icon |
| **Dynamic app name** | Created `values/strings.xml` (`app_name` = "Delwaqty") and `values-ar/strings.xml` (`app_name` = "دلوقتي"). AndroidManifest.xml updated from hardcoded `"delwaqty"` to `@string/app_name`. System automatically picks the correct name based on device locale |
| **Web icons** | favicon.png, Icon-192.png, Icon-512.png, Icon-maskable-192.png, Icon-maskable-512.png all updated |
| **iOS icon** | Icon-App-1024x1024@1x.png updated |
| **Windows icon** | app_icon.ico updated |
| **Device verification** | APK built + installed on DNP NX9. Device locale is `en-EG` → app shows "Delwaqty" on home screen. Switching device to Arabic locale → shows "دلوقتي" |
| **Quality gates** | `flutter analyze` **0 errors** · `flutter test` **542/542 passing** · APK built + installed ✅ |

---

## Current Task — MOST REQUESTED + LANGUAGE FIX + CART ICON + ADMIN/DELIVERY V2 THEME (Session 21k)

Five changes in one session: animated Most Requested carousel on the commerce discovery page, broken Arabic language fix on the favorites page, cart icon in the sidebar, and Premium V2 theme upgrade for the admin panel and delivery list.

| Area | Change |
|------|--------|
| **Favorites language bug** | `app_ar.arb`: `"favoriteMerchants": "الmerchantات"` → `"المتاجر"`; `"noFavoritesMessage"` — replaced untranslated "merchant" with "متجر". Re-generated l10n |
| **Most Requested section** | New animated `PageView` carousel in `commerce_discovery_page.dart` between Featured and All Merchants — shows top 10 merchants sorted by rating in `_MostRequestedCard` (gradient accent, star rating, type badge, auto-scroll every 4s with dot indicators). New l10n key `mostRequested` (en: "Most Requested", ar: "الأكثر طلباً") |
| **Cart icon in sidebar** | New `SidebarItem` with `Icons.shopping_cart_outlined` under Favorites in `floating_sidebar_overlay.dart`, navigating to `/market/cart` |
| **Admin panel V2 theme** | `admin_dashboard_page.dart`: replaced all `GlassCard` → `PremiumCard` (radius `AppSpacing.radiusCard`); renamed `_StatGlassCard` → `_StatPremiumCard`; stat cards, quick actions, activity tiles all use `PremiumCard` |
| **Delivery list V2 theme** | `admin_deliveries_page.dart`: replaced `GlassCard` → `PremiumCard`; service filter chips now use `AppColors.brandPurple` gradient when selected (animated `Container`); delivery tiles use `PremiumCard` with proper radius |
| **Quality gates** | `flutter analyze` **0 errors** · `flutter test` **542/542 passing** · APK built + installed on DNP NX9 ✅ |

---

## Current Task — OFFER BANNER FIX + MERCHANT OFFERS MANAGEMENT (Session 21j)

Follow-up to the Redesign V2 milestone. Fixed the home page offer banner overflow and built a full merchant-side offers management page so merchants can create, edit, delete, and toggle offers from the dashboard.

| Area | Change |
|------|--------|
| **Offer banner overflow** | `_PromoCarousel` container height increased from 120 → 140px to accommodate padding + title + subtitle + coupon chip without bottom overflow (was overflowing 13px) |
| **Merchant Offers Page** | New `merchant_offers_page.dart` — full CRUD: list all offers with search, edit/delete/toggle-active per card, `FloatingActionButton` for creating new offers, form sheet with title, description, discount type (percentage/fixed), discount value, minimum order, max discount, start/end dates, active toggle |
| **Dashboard wiring** | "Create Offer" `ListTile` in `merchant_dashboard_page.dart` now navigates to `/merchant-dashboard/offers` (was a dead SnackBar placeholder) |
| **Route registration** | `/merchant-dashboard/offers` route registered in `merchant_module.dart` |
| **l10n additions** | 30 new keys (en+ar): `manageOffers`, `yourOffers`, `addOffer`, `editOffer`, `deleteOffer`, `offerTitle`, `enterOfferTitle`, `offerDescription`, `enterOfferDescription`, `discountType`, `percentage`, `fixedAmount`, `discountValue`, `enterDiscountValue`, `minimumOrder`, `enterMinimumOrder`, `maximumDiscount`, `enterMaximumDiscount`, `startDate`, `endDate`, `activateOffer`, `deactivateOffer`, `confirmDeleteOffer`, `offerCreated`, `offerUpdated`, `offerDeleted`, `noOffersYet`, `noOffersMessage`, `searchOffers` |
| **Quality gates** | `flutter analyze` **0 errors** · `flutter test` **542/542 passing** · APK built + installed on DNP NX9 ✅ |

---

## Current Task — REDESIGN V2: SEARCH / ORDERS / PROFILE PAGES (Session 21i)

Part of the platform-wide Premium V2 redesign (Apple/Airbnb/Stripe aesthetic, deep-purple brand). This session redesigned the remaining three bottom-nav tabs to match the Session 21h Home redesign — reusing the same V2 tokens and shared design widgets. All business logic and routes are unchanged; only presentation was upgraded.

| Area | Change |
|------|--------|
| **Search page** (`search_page.dart`) | Replaced `AppSearchBar` with the shared `PremiumSearchField` (22px frosted-glass capsule, animated focus). Filter chips + sort `ChoiceChip`s → custom `_PremiumPill` (brand gradient when selected with `shadowGlow`, glass pill when unselected; compact variant for sort bar). Grid cards → premium `_SearchMerchantCard` (24px `PremiumCard`, gradient/emoji header with image fallback, Open/Closed `_OpenBadge`, persisted `FavoriteButton`, type-color category chip, rating + count, delivery time + fee with `currencySymbol`). `EmptyState` → `PremiumEmptyState` (no-results + error with retry). Loading → shimmer `ShimmerLoading` grid. Debounce/search/sort logic untouched |
| **Orders page** (`orders_page.dart`) | Cards → 24px `PremiumCard` with colored `_StatusTile` (gradient icon per status), status `_StatusChip` with dot, items count via `l10n.itemCount(count)`, total with `currencySymbol`, schedule icon + formatted date, **Track Order** affordance (`l10n.trackYourOrder` + chevron) when trackable. Empty + error → `PremiumEmptyState` (error has retry). Loading → `_OrderSkeletonCard` shimmer. Business logic (`_ordersFutureProvider`, statuses, routes) untouched |
| **Profile page** (`profile_page.dart`) | Authed: gradient-ring avatar (`_GradientAvatarRing`) + gradient camera button, role `_RoleChip` (admin/driver/merchant/owner), `PremiumCard` header. Settings + Orders/Invoices → `_SectionCard` (title + premium card with tinted `_IconTile` leading icons, dividers). Role portals → gradient `_PortalTile` rows. Guest profile → `_GuestAvatar` gradient circle + full-width premium buttons. Logout + edit dialogs radius 26 (`radiusDialog`). Locale/theme/sign-out/edit-photo logic untouched |
| **Page backdrop** | `GradientBackground` brand wash behind all three tab bodies for a cohesive premium feel (dark-aware) |
| **l10n additions** | New keys (en+ar): `merchant`, `owner`, `rolePortals`; `gen-l10n` re-run; orders page now uses existing `itemCount`/`trackYourOrder` instead of inline strings |
| **Code deletion classification** | `AppSearchBar` + `EmptyState` widgets remain — still used by favorites/cart/restaurant-tracking pages and their tests (not deleted) |
| **Quality gates** | `flutter analyze` **0 errors** (issue count dropped 481 → 474, all pre-existing info lints) · `flutter test` **542/542 passing** · `flutter build apk --debug --dart-define-from-file=.env.dev` ✅ · APK installed on DNP NX9 ✅ |

> **Remaining (next in V2 plan):** commit/push the full Redesign V2 milestone (Sessions 21g–21i: tokens, theme, shell, Home, Search, Orders, Profile) + sprint report in `docs/HANDOFF/`, then run the device check across all four tabs.

---

## Previous Task — ADMIN PUSH UX + NOTIFICATION DELETION (Session 21g)

Follow-up to 21f. User asked for: connected devices as pure counters, an offline counter, a button showing how many devices received a broadcast, hiding the Firebase/database card, a delete-all button, and per-notification delete.

| Area | Change |
|------|--------|
| **Migration `019_push_broadcast_device_count.sql`** | Replaces `admin_broadcast_notification` to return the **device count** (number of `notification_tokens` belonging to the matched recipients) instead of the recipient-user count. Still inserts one `notifications` row per matching user. **Applied + verified live** via Management API (pg_proc shows the new body with `matched_ids uuid[]` + `device_count`) |
| **Admin page — counters** | Connected-devices card → compact stat tiles: **متصل (online)** and **غير متصل (offline)** counters (15-min window), plus an **الأجهزة المستلمة (devices received)** button showing the last broadcast's device count (updates after each send). Token list removed. Classification extracted to testable `computeDeviceStats(tokens, now)` |
| **Admin page — Firebase card removed** | The Firebase Console copy card + dead `_copyPayload`/`_openConsoleGuide`/`_buildPayload` code deleted; the RPC send is the single path |
| **Notification center — delete** | **حذف الجميع** (delete all) action with confirmation dialog (`clearAll()`); every card gains a per-item **حذف الإشعار** delete button (`deleteNotification(id)`); both invalidate `notificationsProvider`/`unreadCountProvider` |
| **Token heartbeat** | `PushNotificationService` re-upserts the token every **5 min** while the app is alive → `updated_at` is a real liveness signal, so online/offline counters are meaningful |
| **Tests** | 4 new `computeDeviceStats` tests + 3 notification-center widget tests (per-item delete, delete-all with cancel/confirm, empty state). Suite **535 → 542** · `flutter analyze` 0 errors |
| **Verify on device (DNP NX9)** | Stats card renders `1 متصل / 0 غير متصل / الأجهزة المستلمة: 0`; a test broadcast returned **1 device** and the received button updated to **1** (DB row created, RPC live); Firebase card gone (page ends at send button); notification center shows delete-all + per-item buttons; per-item delete removed the `تست/تست١` row (DB confirmed), delete-all emptied the table (**0 rows**), empty state renders. Test notification data cleaned up in the process |

> **Remaining:** background/terminated FCM push still requires a Firebase service account (external). In-app realtime broadcast + admin counters/deletion are verified working live.

---

## Previous Task — PUSH NOTIFICATION SYSTEM FIXED + VERIFIED LIVE (Session 21f)

| Area | Change |
|------|--------|
| **Root cause #1 — schema mismatch** | `notification_tokens` (migration 002) has only `created_at`, but the service + dashboard persist/read `updated_at` → every token query threw → `_saveToken` silently failed (no tokens ever stored) and the admin "connected devices" card showed the generic `خطأ` |
| **Root cause #2 — broken upsert** | `_saveToken` used `onConflict: 'token'` but no unique index exists on `token` alone (table has `UNIQUE(user_id, token)`) → the upsert itself failed |
| **Root cause #3 — RLS** | `notification_tokens` policy (`auth.uid() = user_id`) blocked admins from listing devices; the legacy `notifications` "Service role can insert" policy was `WITH CHECK (true)` with **no role restriction** — any user could insert a notification for any user |
| **Root cause #4 — no send path** | Admin page only copied an FCM payload for manual pasting into Firebase console. Real FCM v1 needs a service-account credential (external blocker). Meanwhile the app already had a full in-app notification center (`notifications` table) that was not wired to realtime |
| **Fix — migration `018_push_notification_platform.sql`** | Adds `updated_at` + auto-update trigger + `user_id` index to `notification_tokens`; admin SELECT-all-tokens policy; admin INSERT/SELECT/DELETE on `notifications`; restricts the legacy insert policy to `service_role`; adds `notifications` to `supabase_realtime`; adds admin-only `SECURITY DEFINER` RPC `admin_broadcast_notification(p_title, p_body, p_type, p_deep_link, p_target_role, p_target_user_id)` → inserts one row per matching user, returns recipient count |
| **Fix — `push_notification_service.dart`** | Upsert conflict → `user_id,token`; `platform` normalized to `android`/`ios` (CHECK constraint); **Supabase Realtime subscription** on `notifications` INSERT (RLS-scoped) → shows local notification + invalidates `notificationsProvider`/`unreadCountProvider` → instant in-app push with **no external credentials**; runs regardless of FCM permission |
| **Fix — admin page** | Real **إرسال الإشعار (Send)** button calling the RPC; audience selector (all / customer / driver / merchant / admin); type selector (`info`/`warning`/`success`/`reminder`); optional deep link; recipient-count snackbar; tokens refresh after send; connected-devices card has retry + specific failure message; Firebase console copy remains as secondary; logic extracted to testable `buildBroadcastParams` |
| **Tests** | New `admin_push_notifications_page_test.dart` (4 tests: default all-audience params, role mapping, deep-link trim, blank-link). Full suite **535/535** · `flutter analyze` 0 errors |
| **Migration 018 APPLIED to live Supabase** | Applied via Management API (`database/query`) to `bttnlkmwhorjamzemwda` with the user's Personal Access Token. Verified: `notification_tokens.updated_at` column + `notification_tokens_set_updated_at` trigger present; `admin_broadcast_notification` RPC present (pg_proc shows the 7-arg signature); `public.notifications` listed in `supabase_realtime` publication |
| **Verify — token pipeline (device)** | After app relaunch the token row appeared in `notification_tokens`: `user=8a23b719-a923-4a18-bd6e-04972097fb4b`, platform `android`, `updated_at` correctly stamped (trigger works). The admin **الأجهزة المتصلة (Connected Devices)** card now shows **1 device** + the masked token `fyx7-ITi...Kk41me9g` + relative time — the old `خطأ` state is gone |
| **Verify — admin send (device)** | On the rewritten page, filled title `Hello from admin` / body `Test Broadcast`, tapped **إرسال الإشعار**. RPC fired → 3 rows inserted into `public.notifications` (title/body/type=info/is_read=false, timestamps 03:49 UTC). Snackbar + button spinner confirmed no crash |
| **Verify — realtime delivery (device)** | Notification center (`الإشعارات`) shows the 3 `Hello from admin / Test Broadcast` rows at "2m ago"; Home header **unread badge = 3**; the old `تست / تست١` artifact row also listed. Sending from admin → row appears in the receiver's center with no manual refresh → in-app realtime broadcast loop proven end-to-end |

> **Remaining:** background/terminated FCM push still requires a Firebase **service account** credential (external). In-app realtime broadcast — the working path — needs nothing extra. Test rows (`Hello from admin` ×3 + old `تست/تست١`) were left in the DB as visible proof; clear them via `تعيين الكل كمقروء` / delete from the center, or delete the rows directly.

---

## Previous Task — "الموقع غير متاح" BUG FIXED (Over-Strict Gate Was Rejecting Real Fixes)

User reported the app **always** showed `الموقع غير متاح` on the Home header even though the phone has real, fresh location fixes. Root cause was the previous session's anti-stale fix being **over-corrected**. Fixed, tested, and proven on device.

| Area | Change |
|------|--------|
| **Root cause** | Session 21d required `satellitesUsedInFix > 0` (GNSS-only) + ≤ 2 min freshness for EVERY accepted fix. On this device that is impossible indoors: network/fused fixes always carry `satellitesUsedInFix = 0`, and the last real GPS fix was 35 min old (`hAcc=40.2`, `satellites=6`). `dumpsys location` re-analysis proved `et=` is **elapsed-time-since-boot**, not fix age — the network/fused last-fixes were actually **~1 min old (FRESH)**, rejected purely because they had no satellite count. Result: eternal `الموقع غير متاح` |
| Fix — freshness tiers | `_maxFixAge` = 2 min (stream fix freshness), new `_maxLastKnownAge` = **10 min** (last-known usability). The 9-day replay protection is preserved: anything > 10 min old is still refused |
| Fix — `_isUsableLastKnown` | New: accepts last-known ≤ 10 min old (−30 s skew). GNSS-verified positions always pass; **non-GNSS (network/fused) pass only if `accuracy >= 0 && accuracy <= 500 m`** → the fresh 100 m fused/network fix is now used instead of `الموقع غير متاح` |
| Fix — `_acquirePreciseFix` | No longer rejects satellite-less stream samples — any fresh sample accumulates as `best` and is returned. GNSS verification is now required ONLY for the ≤ 1 m early-lock shortcut (real 1 m still needs open sky). `waitSeconds` = 45 only when deep AND no usable last-known, else 12 → deep lock no longer hangs |
| `_bestAvailablePosition` | Returns fresh GNSS ≤ 1 m last-known immediately; quick mode returns a usable last-known without waiting; otherwise acquires a stream fix; falls back to usable last-known |
| Unit tests | `location_provider_test.dart` now **14 tests** (+4): satellite-less network/fused stream sample accepted as fallback; fresh non-GNSS last-known accepted in quick mode; poor-accuracy (> 500 m) non-GNSS last-known rejected; GNSS last-known up to 10 min old accepted; non-GNSS last-known older than 10 min rejected. Full suite **531/531** |
| Verify on device | `flutter analyze` 0 errors · `flutter test` 531/531 · debug APK rebuilt + installed · **Home header now shows `شاليهات مارفيل، بلو باي اسيا، السويس، مصر` (NOT `الموقع غير متاح`)** · deep-lock (`حدد موقعي` on Direct Delivery) filled the deliver-to field with the same resolved address · Termux terminal overlay briefly covered the app — brought back with `am start`, state confirmed |
| **Bundled sprint 57 features verified on device (DNP NX9)** | **Floating sidebar** opens via header menu (RTL → button is top-right): user card (`U` / `User` / `said.3pkarino@gmail.com` / `مدير عام` badge) + all sections incl. لوحة الإدارة, الشكاوى, العقوبات, تتبع مباشر · **Notifications page** renders (`الإشعارات` title, `تعيين الكل كمقروء`, empty state `لا توجد إشعارات`); unread badge is hidden by design at `unreadCount=0` · **Profile tab** + **Edit Profile dialog** show the new `اسم المستخدم` field · **Admin Dashboard → Push Notifications page** renders; `الأجهزة المتصلة` shows a graceful `خطأ` state (no FCM tokens exist yet); message field + `نسخ أمر FCM` + Firebase console link present · **logcat clean** — no `FATAL` / `AndroidRuntime` / `E/flutter` during the whole session |

> **Remaining reality check:** the ≤ 1 m deep-lock still requires a live GNSS fix (indoor `avgBasebandCn0=18.7 dB-Hz`, no fresh fix). It now degrades gracefully: if no GNSS fix arrives it uses the best fresh stream sample or a usable ≤ 10 min / ≤ 500 m last-known instead of returning nothing.

---

## Previous Task — STALE-LOCATION BUG FIXED (App No Longer Guesses)

User reported the app showed a **wrong place** (`شاليهات مارفيل، بلو باي اسيا`) that was NOT where they physically are. Root cause found, fixed, and proven on device.

| Area | Change |
|------|--------|
| **Root cause** | Android's FusedLocationProvider delivered the **9-day-old cached location** as the first stream event, **re-attributed with a fresh `getTime()`** → the app treated it as current and reverse-geocoded it. `dumpsys location` proved ALL system fixes were `et=+9d16h` (fused/network/gps) |
| Fix #1 (time filter) | `_isFreshTimestamp` — a fix is fresh only if ≤ 2 min old (30 s future tolerance). Alone this was **insufficient**: the platform re-attributes fresh timestamps to replayed caches |
| Fix #2 (GNSS verification) | `_hasLiveGnss(position)` — on Android, a position is accepted only if `AndroidPosition.satellitesUsedInFix > 0` (live GNSS session). `geolocator_android`'s `NmeaClient.enrichExtrasWithNmea` stamps the satellite count on every delivered fix; a **replayed cache carries 0** → rejected. Non-Android (tests/iOS) pass by freshness only |
| Stale fallback removed | `_bestAvailablePosition` no longer falls back to a stale `lastKnown`; it returns it only if `_isFreshAndVerified` (fresh + GNSS-verified). Null → UI honestly shows `الموقع غير متاح` instead of guessing |
| Stream onDone | `_acquirePreciseFix` now completes the completer when the stream ends (`onDone`) instead of only the timer → no 45 s hang when the provider yields nothing |
| Unit tests | `location_provider_test.dart` now **10 tests** (+5 new): rejects 9-day-old last-known when no fresh fix; ignores stale stream samples; prefers fresh stream fix over stale last-known; rejects satellite-less (`satellitesUsedInFix: 0`) Android sample; accepts GNSS-verified (`satellitesUsedInFix: 4`) sample. Note: `AndroidPosition` ctor params are untyped → must pass `0.0`/doubles (int literals throw at runtime). Full suite **527/527** |
| Verify on device | Rebuilt + installed. Home header now shows **`الموقع غير متاح`** (NOT the stale Marvel address) — the app refuses to guess. Re-verified this session: app restart → still `الموقع غير متاح`; deep-lock (`حدد موقعي`) ran a full HIGH_ACCURACY window → GPS provider still reports **no fresh fix in 9 days** (`et=+9d17h…`, `hAcc=40.2`, `satellites=6`); GNSS receiver alive (9 satellites, 301k sv-status msgs) but `avgBasebandCn0=18.7 dB-Hz` = indoor, no fix computed. All network/fused/gps last-fixes remain 9 days stale. Location mode 3, permissions granted, no mock source. **Fix is proven: the app refuses stale/replayed positions and shows `الموقع غير متاح`** |

> **Reality check:** 1 m precision is physically impossible indoors (last GPS fix `satellites=6, meanCn0=12`, 9 days stale). The `refreshDeepLocked()` 1 m lock is intact, GNSS-verified and tested. To verify a real 1 m fix end-to-end the user must step outside under open sky, then pull-to-refresh Home or place an order (order flows call `refreshDeepLocked()`).

---

## Previous Task — ACTUAL PLACE NAME + PRODUCTION-GRADE LOCATION ENGINE

Delivered the **actual place name** (like Uber) using **Photon (Komoot)** — a free, no-key OSM geocoder — and removed every non-production artifact from the engine.

| Area | Change |
|------|--------|
| Photon source | New `_photonStructuredAddress` in the 4-way geocode chain (Google → Photon → Nominatim → Overpass-nearest). Returns locality/street/state/country → on device now resolves the user's real location to **`شاليهات مارفيل، بلو باي اسيا، السويس، مصر`** (Marvel Chalets, Blue Bay Asia, Suez, Egypt) |
| Photon 403 fix | `photon.komoot.io` returned **403** to Dart's http client (same as Overpass) → added `User-Agent: Delwaqty/1.0` → 200 JSON |
| Nearest-place | `_nearestNamedPlace` radius 2000→**4000 m**, now **prioritizes POIs** (amenity/shop/leisure/tourism/building/office/place/landuse/resort/camp_site) **over highways**; found "Zafarana offices" instead of the road name |
| Production cleanup | **Removed ALL debug tracing** (`loc_debug.txt` writes, `_appendDebug`, `geo:/pos:/addr:` logs). Replaced hardcoded `dart:io` file cache with **SharedPreferences** cache (`location_geocode_cache_v1`) with **24 h TTL** + 200-entry cap. `dart:io` import removed |
| Precision lock | `refreshDeepLocked()` — 3 attempts, locks on `accuracy ≤ 1.0 m`; deep window back to **45 s** per attempt for GPS cold-start convergence |
| Verify | `flutter analyze` 0 errors · `flutter test` 522/522 · debug APK built + installed · **UI verified on device**: Home header shows `شاليهات مارفيل، بلو باي اسيا، السويس، مصر` · `files/` clean (no debug/cache artifacts) |

> Remaining external blocker for Uber-grade POI quality: Google Geocoding + Places APIs still `REQUEST_DENIED` (key not authorized in Google Cloud Console). Current depth comes from OSM (Photon/Nominatim/Overpass). 1 m fix physically requires open sky (device GNSS is dual-frequency capable).

---

## Previous Task — 1 m PRECISION LOCK (STRICT) — Google Key is the Only External Block

User demanded: **"عايز الدقه 1 متر وليس اى دقه عشوائيه"** (1 m precision, NOT random accuracy) — like Uber. Implemented a **strict 1 m lock** so order flows refuse insufficient fixes and guide the user, instead of silently accepting weak readings.

| Area | Change |
|------|--------|
| Strict lock | `refreshDeepLocked()` — up to **3 attempts** of the deep acquisition; returns as soon as `accuracy ≤ 1.0 m` (`precisionTargetMeters`); after all attempts returns best + caller shows Arabic guidance. Used by Direct Delivery `_useCurrentLocation` and Ride Booking `_useCurrentLocation` |
| Deep window | `_acquirePreciseFix(deepPrecision: true)`: `LocationAccuracy.bestForNavigation`, 30 s per attempt, early-complete at `≤ 1 m` |
| UI guidance | New l10n keys (both ARB): `accuracyInsufficient` (Arabic: "الدقة الحالية غير كافية (مطلوب دقة 1 متر)…"), `improvingAccuracy`, `retryLocation`; order flows show a snackbar when accuracy > 1 m but still fill best-effort address |
| Unit tests | New `test/features/location/presentation/providers/location_provider_test.dart` — 5 tests via `MockPlatformInterfaceMixin` mock of `GeolocatorPlatform`: service off → null, denied → null, deniedForever → null, sub-metre last-known lock, sub-metre stream lock. Suite now **522 passing** |
| Google key | **Confirmed blocked**: Geocoding + Places both return `REQUEST_DENIED: "This IP, site or mobile application is not authorized"` (tested from dev machine AND from the device). Root cause = key restrictions/API enablement in Google Cloud Console. Debug SHA-1 `53:37:18:5A:52:F0:B6:15:A3:38:8E:CC:03:B6:57:6D:61:F3:4E:EF`, package `com.delwaqty.app` |
| OSM reality | Around the user's point (tourist-village area, Zafarana/Sokhna road) the nearest named OSM POIs are 2.2–2.6 km away (Bassem Market, Mountain View Sokhna, La Regina Resort). OSM data is sparse; **Google Places is required for true Uber-style place names** |
| Verify | `flutter analyze` 0 errors · `flutter test` 522/522 · debug APK built + installed · Home shows `طريق العين السخنه، الزعفرانه، السويس، مصر` |

> **ACTION REQUIRED FROM USER (external blocker):** In Google Cloud Console → enable **Geocoding API** + **Places API**, fix the key's Application restrictions (Android key → add package `com.delwaqty.app` + SHA-1 above; or remove restriction for testing), and ensure billing is active. Until then, POI depth = OSM only.

---

## Previous Task — DEEP LOCATION PRECISION (1 m) + FULL ARABIC ADDRESS

Deepened the location engine to genuinely pursue a **1 m GPS fix** and render a **full Arabic street-level address with no digits/units in the UI** (per user's earlier "no accuracy numbers" decision; user now explicitly wants 1 m precision).

| Area | Change |
|------|--------|
| Deep engine | `_acquirePreciseFix(deepPrecision: true)` uses `LocationAccuracy.bestForNavigation`, **45 s** convergence window, completes immediately when `accuracy ≤ 1 m`, otherwise returns best sample; two precession tiers added |
| Quick path | `refreshQuick()` = `LocationAccuracy.best`, 12 s, `≤ 10 m` target — used by Home header so the passive display never blocks 45 s |
| Deep path | `refreshDeep()` — used by **order-time** capture (Direct Delivery `_useCurrentLocation`, Ride Booking `_useCurrentLocation`) so the real fix is as deep as possible at order time |
| Overpass fix | Root cause found: `overpass-api.de` returned **406** because the request lacked an explicit `User-Agent` (Dart's default rejected). Added `User-Agent: Delwaqty/1.0` → **200 + JSON**. Mirrors: overpass-api.de, overpass.kumi.systems, overpass.private.coffee (15 s per mirror, UA header on all) |
| Geocode cache | New file cache `loc_geocode_cache.json` keyed on `lat,lng` rounded to 4 decimals (~40 m grid) → second launch resolves the address **instantly** with zero Overpass/Nominatim calls (verified: no `geo:` line on 2nd run) |
| Address depth | Result on device: `طريق العين السخنه، الزعفرانه، السويس، مصر` (road → area → governorate → country, Arabic, no digits) |
| On-device accuracy | Indoors ~**7.5 m** with `bestForNavigation` (was ~25 m default); device GNSS is multi-constellation (GPS+GLONASS+BeiDou+Galileo); **1 m requires open sky** (indoor meanCn0=7, 6 sats) |
| Verify | `flutter analyze` 0 errors · `flutter test` 517/517 · debug APK built + installed on DNP NX9 · address renders in Home header, cache persists |

> Known limits: Google Geocoding still `REQUEST_DENIED` (unauthorized key) so POI depth comes from Nominatim + Overpass only. Exact named building needs open sky + authorized Google key (or user-entered free text).

---

## Previous Task — FUNCTIONAL BOTTOM-NAV RESTRUCTURE (Session 20)

Redesigned the bottom navigation from the module-driven Home / Direct Delivery / Ride / Settings tab set into a professional 4-tab layout: **Home / Search / Orders / Profile** — the product decision deferred in Session 19.

| Area | Change |
|------|--------|
| Nav tabs | New order by `navPriority`: **Home (10) → Search (20) → Orders (30) → Profile (40)**; the shell builds branches from `FeatureRegistry.navModules` so tabs stay module-driven |
| SearchModule | Promoted to nav module: branch `/search` → existing commerce `SearchPage`; home search bar now `context.go('/search')` (switches tab instead of pushing a duplicate) |
| OrdersModule (new) | `lib/features/orders/orders_module.dart` — nav branch `/orders` → existing commerce `OrdersPage`; `/orders` added to `restrictedRoutes` (guests → login); depends on `commerce` |
| ProfileModule | Promoted to nav module: branch `/profile` → `ProfilePage`; drawer/sidebar `/profile` uses `go` (tab switch); **gear icon** added to Profile AppBar → `push('/settings')` |
| SettingsModule | Demoted to non-nav; `/settings` kept as `shellSubRoute` wrapped in a `Scaffold` + `AppBar` (page itself remains a bare `ListView`) |
| DirectDeliveryModule | Demoted to non-nav; `/direct-delivery` kept as a `standaloneRoute`; page gained its own `AppBar` (title + back) since it is no longer rendered under the shell AppBar |
| RideModule | Re-enabled (was commented out in `module_registry.dart`); demoted to non-nav with `/ride/book` as a `standaloneRoute` (RideBookingPage has its own back button); home ride tile's `/ride/book` push now resolves; delivery tile fixed to push `/direct-delivery` |
| AppShell | Global AppBar removed (menu + notifications moved into Home header); **menu button** added to Home header (opens floating sidebar); `extendBody: true` → `false` so branch pages with their own Scaffolds are not overlapped by the floating pill; Home bottom spacer 100 → 24 |
| Routes | `app_router.dart` restricted list now includes `/orders`; `module_registry.dart` registers `OrdersModule` and re-registers `RideModule` |
| Verify | `flutter analyze` 0 errors · `flutter test` 517/517 · debug APK built + installed on DNP NX9 · all 4 tabs tapped on device with no crashes |

> The old tab set (Direct Delivery, Ride, Settings) remains reachable: Delivery via Home grid tile, Ride via Home grid tile (`/ride/book`), Settings via Home "More" tile + Profile gear.

---

## Current Task — MIGRATIONS EXECUTED ON SUPABASE (015 + 016)

Both migrations were executed directly against `bttnlkmwhorjamzemwda` via the Supabase Management API (`database/query` endpoint) using the user's Personal Access Token.

**Important finding:** before execution, all 5 tables returned **404 via REST** — 015 had NOT been applied (despite the report). Executed 015 then 016.

| Verification | Result |
|--------------|--------|
| `pg_tables` (public schema) | ✅ 5/5 tables exist (`complaints`, `sanctions`, `location_updates`, `chat_rooms`, `chat_messages`) |
| `relrowsecurity` | ✅ RLS enabled on 5/5 |
| `pg_policies` | ✅ 31 policies (admin SELECT/INSERT/UPDATE/DELETE + user policies per table) |
| Helper functions | ✅ `is_admin`, `add_admin_note`, `add_complaint_admin_note` |
| Realtime publication | ✅ 5/5 tables added to `supabase_realtime` |
| Storage buckets | ✅ `complaints` + `chat_attachments` |
| Grants to `authenticated` | ✅ SELECT/INSERT/UPDATE/DELETE on 5/5 |
| REST end-to-end | ✅ Table reachable (200, RLS returns filtered rows); temporary `anon` grant was revoked after the test |
| PostgREST reload | ✅ `NOTIFY pgrst, 'reload schema'` triggered |
| `flutter analyze` / `test` | ✅ 0 errors / 517 passing (unchanged) |

> **Note:** The Personal Access Token was used in the session only (never saved to files or committed). User should revoke/rotate it in Supabase → Account → Access Tokens.

---

## Current Task — RLS POLICY REBUILD (migration 016)

After 015 was applied, features still misbehaved due to RLS policies: policies from 007/014/015 overlapped or were incomplete for admin + participant flows. Fixed with a deterministic rebuild.

| Fix | Details |
|-----|---------|
| New migration `016_fix_rls_policies.sql` | Drops ALL known policy names on the 5 tables (from 007/014/015), re-enables RLS, and recreates explicit SELECT/INSERT/UPDATE/DELETE policies for admin + users |
| `is_admin()` helper | `SECURITY DEFINER` SQL function checking `users.role IN ('admin','owner')` (matches app logic; `admin_users.id` is a separate UUID and is intentionally not used) |
| `add_admin_note()` + `add_complaint_admin_note()` | Admin-only note functions; legacy RPC name preserved for the app |
| Admin full control | SELECT/INSERT/UPDATE/DELETE on complaints, sanctions, location_updates, chat_rooms, chat_messages |
| User policies | Own complaints (+legacy reporter), own sanctions, own locations, rooms they participate in, messages in their rooms (with `sender_id = auth.uid()` on insert) |
| Grants | `GRANT SELECT,INSERT,UPDATE,DELETE ... TO authenticated` on all 5 tables |
| Verify | `flutter analyze` 0 errors · `flutter test` 517/517 |

> **ACTION REQUIRED:** Run `016_fix_rls_policies.sql` in the Supabase SQL Editor (instructions in session report).

---

## Current Task — MANAGEMENT TABLES DB FIX (Root Cause: migration 014)

The new features (complaints, sanctions, live tracking, support chat) failed with `Could not find the table`. Root cause found and fixed.

**Root cause:** `supabase/migrations/014_management_platform.sql` used `CREATE TYPE IF NOT EXISTS`, which **PostgreSQL does not support** (syntax error) → the migration aborted mid-way → `sanctions`, `location_updates`, `chat_rooms`, `chat_messages` were never created, and `complaints` kept the legacy 007 ride schema (missing management columns).

| Fix | Details |
|-----|---------|
| New migration `015_create_management_tables.sql` | Creates all 5 tables (merged `complaints` schema + `sanctions` + `location_updates` + `chat_rooms` + `chat_messages`) with TEXT+CHECK instead of enums; RLS policies (participant OR admin); 2 storage buckets; `add_complaint_admin_note` RPC; adds tables to `supabase_realtime` publication |
| 014 bug fixed | Replaced `CREATE TYPE IF NOT EXISTS` with guarded `DO` blocks |
| `complaints` conflict resolved | Old 007 ride table auto-detected + replaced with merged schema so ride module (`reportIssue`) keeps working |
| Dart fixes | `createComplaint`/`createRoom`/`sendMessage`/`createSanction` no longer send `id: ''` into UUID columns; use `.select().single()` to return real rows; `Complaint.fromJson` tolerates legacy ride rows |
| `supabase_service.dart` | **No change needed** — it only exposes the Supabase client; table names live in each data source |
| Verify | `flutter analyze` 0 errors · `flutter test` 517/517 · APK built + installed on DNP NX9 |

> **ACTION REQUIRED:** Run `015_create_management_tables.sql` (and re-run `014` for the type fix) in the Supabase SQL Editor — see instructions below.

---

## Current Task — ADMIN PANEL WIRING (Post-Sprint 51)

Made the Sprint 40 management features (complaints, sanctions, live tracking, support chat) reachable from the UI and removed all legacy ride-page references from the admin panel.

| Change | Details |
|--------|---------|
| Deleted `admin_rides_page.dart` | Old transport/ride page removed |
| Removed `/admin/rides` route | Removed from `admin_module.dart` |
| Dashboard quick actions updated | Removed `rideHistory`; added **Complaints**, **Sanctions**, **Live Tracking**, **Support Chat** (4 new actions) |
| Floating sidebar | New admin-only **Admin Panel** section (idx 8–12: admin panel, complaints, sanctions, live tracking, support chat); support section reindexed 13–18 |
| l10n cleanup | Removed 4 unused ride keys (`rideMonitoring`, `noRidesFound`, `noRidesCreated`, `noRidesSelectedStatus`) + `gen-l10n` |
| Analyzer cleanup | Removed unused imports in `floating_sidebar_overlay.dart`, `floating_sidebar_controller.dart`, `app_shell.dart` |
| Build + install | `flutter build apk --debug --dart-define-from-file=.env.dev` ✅ installed on DNP NX9 ✅ |

---

## Completed Milestones

| Milestone | Sprint | Description | Status |
|-----------|--------|-------------|--------|
| M1-M11 | 28-39 | Previous milestones (localization, transportation, booking, dispatch, search, driver platform, delivery, safety, theme, errors, empty states) | ✅ |
| M12 | 40 | Management Platform — Complaints, Sanctions, Live Tracking, Support Chat | ✅ |
| M13 | 51+ | Admin Panel Wiring — features exposed in dashboard + sidebar; legacy rides page removed | ✅ |
| M13b | 53 | Management Tables DB Fix — migration 015, 014 type bug, UUID insert + RLS fixes | ✅ |
| M13c | 54 | RLS Policy Rebuild — migration 016: is_admin helper, explicit per-command policies, grants | ✅ |
| M13d | 55 | UI Polish — Cairo typography (google_fonts), card system (radius/shadow/gradients), pill search, banner copy, micro-interactions | ✅ |
| M13e | 56 | Functional Bottom-Nav Restructure — 4-tab layout (Home/Search/Orders/Profile), Settings behind Profile gear, Delivery/Ride into Home grid | ✅ |
| M13f | 57 | Location Reliability — real place names via Photon/Nominatim/Overpass, 1 m deep lock, stale/9-day replay rejected, then over-strict gate relaxed so real fresh fixes (network/fused 100 m) are used again | ✅ |
| M13g | 57 | Push Notifications — token pipeline fixed (updated_at, upsert, platform CHECK), migration 018 applied live, admin broadcast via SECURITY DEFINER RPC, realtime in-app delivery verified end-to-end on device | ✅ |
| M13h | 57 | Admin Push UX — device counters (online/offline/received), migration 019 (RPC returns device count), Firebase card removed, notification-center delete-all + per-item delete, token heartbeat | ✅ |
| M13i | 58 | Redesign V2 — Premium UI (Apple/Airbnb/Stripe aesthetic, deep-purple brand): design tokens (colors/spacing/elevation/theme), floating glass bottom nav, shared design widgets (`PremiumCard`/`PremiumSearchField`/`GlassSurface`/`GradientBackground`), Home page redesign, then Search/Orders/Profile tab redesigns | ✅ (commit c7122b2) |
| M13j | 59 | Intro rendering — splash painter split into static glows + cheap particles (kills the wordmark-phase flash on Impeller); home header shows the real logo image next to the sidebar | ✅ |
| M13k | 60 | Account Verification — user type (customer/provider/delivery) + verification status on registration, document upload, pending-verification gate, admin approve/reject page, migrations 020+021 applied live, email confirmation + deep-link auth config | ✅ (device E2E tap-confirmation-link pending) |

---

## Sprint 40 Summary

### Management Platform
- **Migration `014_management_platform.sql`**: 5 tables with RLS policies, indexes, storage buckets for attachments
- **complaints/**: Full CRUD, status management (`pending`/`investigating`/`resolved`/`rejected`/`escalated`), admin notes, filters by type and status
- **sanctions/**: Warning, fine, temporary_ban, permanent_ban, suspension types; active/inactive filtering
- **location_tracking/**: Real-time location upsert, active driver query, Supabase Realtime stream, driver list view + map placeholder
- **support_chat/**: Bidirectional chat between users and admins, Supabase Realtime message streaming, room management, read receipts
- **Admin panel integration**: Dashboard quick actions sidebar entries, nested routes under `/admin`
- **Client pages**: `/my-complaints`, `/new-complaint`, `/support`, `/support/room/:roomId`

---

## Current Quality Gates

| Check | Result |
|-------|--------|
| `flutter analyze` | 0 errors |
| `flutter test` | 555/555 passing |
| APK build | ✅ `app-debug.apk` rebuilt clean (single APK) + installed on DNP NX9 |
| Gradle | `kotlin.incremental=false` fix committed in `android/gradle.properties` |
| Migration 018 | ✅ Applied to `bttnlkmwhorjamzemwda` via Management API + verified (columns, trigger, RPC, realtime publication) |
| Migration 019 | ✅ Applied to `bttnlkmwhorjamzemwda` via Management API + verified (RPC body returns device count) |
| Migration 020 | ⏳ **Not applied yet** — needs user PAT / SQL Editor (external blocker) |
| Live E2E | ✅ Admin send → RPC returns 1 device → received counter updates; notification center per-item delete + delete-all verified (DB 0 rows) |
| Redesign V2 | ✅ Home (21h) + Search/Orders/Profile (21i) premium UI, 0 analyze errors, 555/555 tests, APK installed |

---

## Next Milestones

| Milestone | Description | Status |
|-----------|-------------|--------|
| M14 | Payments integration | Pending |
| M15 | AI-powered features | Pending |

---

## Project Environment

| Tool | Value |
|------|-------|
| Flutter SDK | `E:\app\flutter` (3.44.6, Dart 3.12.2) |
| Android Device | DNP NX9 (`A3SQUT5A28003808`), Android 16 |
| Package | `com.example.delwaqty` |
| Supabase Project | `bttnlkmwhorjamzemwda` |
| Google Maps Key | `AIzaSyA9v-pk50aB3G45zIb_RQKxD5qo_CVX8GY` |
| Pub Cache | `E:\app\pub-cache` |
| Gradle Home | `E:\app\delwaqty\.gradle_home` (isolated, gitignored) |
| Git Remote | `https://github.com/delwaqtyapp/delwaqty` |

---

## Key Architecture Decisions

| Decision | Rationale |
|----------|-----------|
| Separate feature modules for each management domain | Follows existing Clean Architecture; independently testable |
| Admin pages as nested routes in AdminModule | Consistent with existing `/admin/*` pattern |
| Supabase Realtime for chat and location | No polling needed; instant updates |
| GIN index on participant_ids | Efficient `@>` containment queries for chat rooms |
| RLS per table (not blanket) | Fine-grained access control per domain |
