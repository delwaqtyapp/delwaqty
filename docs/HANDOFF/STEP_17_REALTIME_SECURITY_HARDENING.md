# STEP 17: Realtime + Security Hardening

**Date:** 2026-08-18
**Sprint:** 83
**Status:** COMPLETE

---

## Sub-phase 2.6: Realtime Hardening

### Problem
- Single hardcoded channel name `'in-app-notifications'` in `PushNotificationService`
- No centralized channel tracking — channels could leak if not properly unsubscribed
- No error callbacks on channel subscription failures
- No cleanup guarantee on provider disposal

### Solution

#### New: `lib/services/realtime/realtime_service.dart`
- `RealtimeService` class — centralized Supabase Realtime channel manager
- Tracks all active channels in `Map<String, RealtimeChannel>`
- Auto-unsubscribes old channel when same name re-subscribes
- `subscribe()` method with `RealtimeChannelFilter` for PostgresChanges
- `unsubscribe()` / `unsubscribeAll()` for graceful cleanup
- `dispose()` for full teardown on provider disposal
- Error callback support via `onError` parameter
- Riverpod `realtimeServiceProvider` with `ref.onDispose`

#### New: `lib/services/realtime/realtime_channel_constants.dart`
- `RealtimeChannels` — 11 canonical channel names:
  - `in-app-notifications`, `driver-offers`, `active-ride`, `active-delivery`
  - `chat-messages`, `sos-alerts`, `trusted-contacts`
  - `location-updates`, `profile-updates`, `merchant-reviews`, `inventory-updates`

#### Updated: `lib/services/push_notification/push_notification_service.dart`
- Constructor now accepts `RealtimeService` dependency
- `_setupRealtimeNotifications()` uses `_realtime.subscribe()` instead of raw channel creation
- `deactivateTokensOnLogout()` calls `_realtime.unsubscribeAll()`
- Removed `RealtimeChannel? _realtimeChannel` field (replaced by centralized tracking)

---

## Sub-phase 2.7: Security Hardening

### Problem (documented in ADR-029 / doc 26)
- 26 SECURITY DEFINER RPCs across migrations 005, 010, 012, 021 lacked `SET search_path = public, pg_temp`
- 14 `platform_*` RPCs (migration 050) were GRANT'd to `anon` — admin-only functions callable by anonymous users
- 9 driver platform RPCs (010) + 7 safety RPCs (012/029) lacked REVOKE/GRANT ACLs
- Total: 016 pattern not applied everywhere

### Solution: Migration 051

#### search_path Hardening (26 RPCs)
| Migration | Count | Functions |
|-----------|-------|-----------|
| 005 | 4 | `get_user_role`, `get_user_merchant_id`, `is_admin(UUID)`, `is_merchant_owner` |
| 010 | 9 | `submit_driver_onboarding`, `complete_driver_onboarding`, `upsert_driver_document`, `get_driver_documents`, `add_driver_vehicle`, `update_driver_vehicle`, `toggle_vehicle_active`, `get_driver_wallet_detail`, `get_driver_performance` |
| 012/029 | 7 | `trigger_sos_alert`, `resolve_sos_alert`, `start_live_share`, `stop_live_share`, `get_live_share_session`, `upsert_trusted_contact`, `delete_trusted_contact` |
| 029 | 4 | `get_peak_hours`, `get_merchant_rating_summary`, `increment_coupon_usage`, `get_admin_analytics` |
| 021 | 1 | `handle_new_user()` (trigger function) |

#### ACL Lockdown
- All 26 legacy RPCs: `REVOKE EXECUTE FROM PUBLIC, anon` + `GRANT EXECUTE TO authenticated`
- 15 platform_* RPCs: `REVOKE EXECUTE FROM PUBLIC, anon` (authenticated already granted from 050)

#### Verification
- `pg_proc` query confirms all 26 RPCs have `search_path=public, pg_temp`
- `has_function_privilege()` confirms anon blocked from all platform_* RPCs
- `has_function_privilege()` confirms authenticated can call all RPCs
- Pre-existing `is_admin()` returns false for owner (owner not in `admin_users` table — separate issue)

---

## Tests
- Admin: 65/65
- Member/Complaints/Sanctions/Escalation: 42/42
- Services: 12/12
- **Total: 119/119 green**

## Analysis
- 0 errors, 15 pre-existing warnings (unused imports in old files)

## Commits
- Sprint 83: Realtime + Security Hardening
