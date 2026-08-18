# STEP 15 — Member & Platform Operations Center: Comprehensive Codebase Audit

> **Date:** 2026-08-18
> **Author:** Automated Audit (READ-ONLY)
> **Scope:** Full database schema (migrations 001–049), all Flutter feature modules, RPC inventory, entity field mapping, gap analysis, and test coverage.

---

## Table of Contents

1. [Database Schema Inventory](#1-database-schema-inventory)
2. [RPC Function Inventory](#2-rpc-function-inventory)
3. [Flutter Feature Module Inventory](#3-flutter-feature-module-inventory)
4. [RPC Call Wiring (Flutter → DB)](#4-rpc-call-wiring-flutter--db)
5. [Entity Field Mapping](#5-entity-field-mapping)
6. [Gap Analysis (Steps 3–16)](#6-gap-analysis-steps-3-16)
7. [Test Coverage](#7-test-coverage)
8. [Unwired RPCs (DB exists, Flutter missing)](#8-unwired-rpcs-db-exists-flutter-missing)
9. [Findings & Recommendations](#9-findings--recommendations)

---

## 1. Database Schema Inventory

### 1.1 Users & Auth

| Table | Created | Extended By | Key Columns |
|-------|---------|-------------|-------------|
| `users` | 002 | 017, 020, 021, 022, 028, 035, 046, 047 | id (UUID PK), email, full_name, phone, avatar_url, language, is_onboarded, role, user_type, verification_status, id_card_url, profile_photo_url, username, is_biometric_enabled, date_of_birth, account_status, anonymized_at, trade_license_url, driving_license_url, rejection_reason, rejection_reason_at, region_id, last_seen_at, created_at, updated_at |
| `admin_users` | 001 | 028, 031, 034 | id, name, email, role, status, last_login, created_at, user_id (FK→users), managed_by |

**Evidence:**
- `users` table: `/root/Projects/delwaqty/supabase/migrations/002_complete_schema.sql` lines 36–80
- `username` column: `/root/Projects/delwaqty/supabase/migrations/017_add_username.sql` line 6
- `user_type`, `verification_status`, `id_card_url`, `profile_photo_url`: `/root/Projects/delwaqty/supabase/migrations/020_user_verification.sql` lines 23–27
- `is_biometric_enabled`: `/root/Projects/delwaqty/supabase/migrations/022_user_biometric_enabled.sql` line 11
- `trade_license_url`, `driving_license_url`: `/root/Projects/delwaqty/supabase/migrations/028_schema_alignment.sql` lines 6–7
- `date_of_birth`, `account_status`, `anonymized_at`: `/root/Projects/delwaqty/supabase/migrations/035_member_management_moderation_deletion.sql` (scope section)
- `rejection_reason`, `rejection_reason_at`: `/root/Projects/delwaqty/supabase/migrations/047_verification_reapply.sql` lines 30–34
- `admin_users.user_id` FK: `/root/Projects/delwaqty/supabase/migrations/031_admin_hierarchy_region_assignments.sql` (scope section)

### 1.2 Member Events & Activity Logs

| Table | Created | Extended By | Key Columns |
|-------|---------|-------------|-------------|
| `member_events` | 035 | — | id, user_id, event_type (21-type CHECK vocabulary), description (JSONB), actor_id, created_at |
| `activity_logs` | 002 | — | id, user_id, action, entity_type, entity_id, details, ip_address, user_agent, created_at |

**Evidence:**
- `member_events`: `/root/Projects/delwaqty/supabase/migrations/035_member_management_moderation_deletion.sql` (scope section, item 3)
- `activity_logs`: `/root/Projects/delwaqty/supabase/migrations/002_complete_schema.sql`

### 1.3 Verification & Documents

| Table | Created | Extended By | Key Columns |
|-------|---------|-------------|-------------|
| `users` (verification columns) | 020 | 021, 047 | verification_status, id_card_url, profile_photo_url, user_type, rejection_reason, rejection_reason_at |
| `driver_documents` | 007 | 010 | id, driver_id, doc_type, doc_url, status, reviewed_by, reviewed_at, rejection_reason, created_at |

**Evidence:**
- Verification columns: `/root/Projects/delwaqty/supabase/migrations/020_user_verification.sql` lines 23–27
- Driver documents: `/root/Projects/delwaqty/supabase/migrations/007_transportation_platform.sql`

**Note:** There is no standalone `verification` or `verification_attempts` or `documents` table. Verification is embedded in `users` table columns and `driver_documents` for driver-specific docs.

### 1.4 Sanctions

| Table | Created | Extended By | Key Columns |
|-------|---------|-------------|-------------|
| `sanctions` | 014/015 | 035 | id, target_user_id, target_role, sanction_type, complaint_id, reason, amount, duration_days, start_date, end_date, is_active, notes, issued_by, approving_admin_id, evidence_url, action_status, created_at, updated_at |

**Evidence:**
- Sanctions table: `/root/Projects/delwaqty/supabase/migrations/015_create_management_tables.sql` (management tables section)
- Extended columns: `/root/Projects/delwaqty/supabase/migrations/035_member_management_moderation_deletion.sql` (scope section, item 4)

### 1.5 Complaints

| Table | Created | Extended By | Key Columns |
|-------|---------|-------------|-------------|
| `complaints` | 014 | 015, 048 | id, order_id, complainant_id, respondent_id, complaint_type, subject, description, attachments, status, priority, admin_notes, resolution_note, resolved_at, assigned_admin_id, escalated_at, escalated_from_admin_id, created_at, updated_at |

**Evidence:**
- Complaints table: `/root/Projects/delwaqty/supabase/migrations/014_management_platform.sql` lines 7–23
- Merged schema: `/root/Projects/delwaqty/supabase/migrations/015_create_management_tables.sql` (complaints conflict resolution)
- Escalation extension: `/root/Projects/delwaqty/supabase/migrations/048_escalation_engine.sql` (complaints extension section)

### 1.6 Escalation

| Table | Created | Extended By | Key Columns |
|-------|---------|-------------|-------------|
| `escalation_events` | 048 | — | id, entity_type, entity_id, from_admin_id, to_admin_id, actor_id, reason, previous_scope, new_scope, created_at |
| `escalation_rules` | 048 | — | id, entity_type, priority, from_scope, to_scope, reason_pattern, auto_escalate, delay_minutes, created_at |

**Evidence:**
- `/root/Projects/delwaqty/supabase/migrations/048_escalation_engine.sql` (scope section)

### 1.7 Support Chat

| Table | Created | Extended By | Key Columns |
|-------|---------|-------------|-------------|
| `chat_rooms` | 014/015 | 033 | id, room_type, participant_ids, order_id, complaint_id, is_active, priority, region_id, assigned_admin_id, assigned_at, last_message_at, status, escalated_at, escalated_from_admin_id, closed_at, created_at, updated_at |
| `chat_messages` | 014/015 | — | id, room_id, sender_id, content, message_type, created_at |
| `chat_participants` | 014/015 | — | id, room_id, user_id, role, joined_at |
| `chat_escalations` | 033 | — | id, room_id, from_admin_id, to_admin_id, reason, scope, created_at |

**Evidence:**
- Chat tables: `/root/Projects/delwaqty/supabase/migrations/014_management_platform.sql`
- Extended columns: `/root/Projects/delwaqty/supabase/migrations/033_support_chat_priority_region_assignment.sql`

### 1.8 Orders, Requests, Bookings

| Table | Created | Extended By | Key Columns |
|-------|---------|-------------|-------------|
| `orders` | 002 | 011, 024 | id, user_id, merchant_id, status, total_amount, delivery_fee, payment_status, payment_id, transaction_id, created_at, updated_at |
| `order_items` | 002 | — | id, order_id, product_id, product_name, quantity, unit_price, modifiers, created_at |
| `service_bookings` | 023/027 | — | id, user_id, provider_id, provider_name, category_type, status, description, scheduled_date, scheduled_time, address, address_latitude, address_longitude, estimated_price, final_price, notes, completed_at, created_at, updated_at |

**Evidence:**
- `orders`: `/root/Projects/delwaqty/supabase/migrations/002_complete_schema.sql`
- Payment columns: `/root/Projects/delwaqty/supabase/migrations/024_payment_infrastructure.sql` lines 5–7
- `service_bookings`: `/root/Projects/delwaqty/supabase/migrations/023_home_services.sql` (or 027 consolidated version)

### 1.9 Rides & Delivery

| Table | Created | Extended By | Key Columns |
|-------|---------|-------------|-------------|
| `rides` | 002 | 007, 008, 011 | id, rider_id, driver_id, status, ride_type, pickup_latitude/longitude, dropoff_latitude/longitude, pickup_address, dropoff_address, fare_estimate, fare_actual, otp_code, service_type, merchant_id, pickup_notes, dropoff_notes, delivery_proof_url, priority, cancelled_by, driver_rating, driver_feedback, and many more |
| `ride_requests` | 008 | — | id, ride_id, driver_id, status, offered_at, responded_at, eta_minutes, created_at |
| `driver_earnings` | 008 | — | id, driver_id, ride_id, amount, type, created_at |
| `driver_ratings` | 008 | — | id, ride_id, driver_id, rater_id, rating, comment, created_at |
| `trip_events` | 008 | — | id, ride_id, event_type, payload, created_at |

**Evidence:**
- Base rides: `/root/Projects/delwaqty/supabase/migrations/002_complete_schema.sql`
- Ride extensions: `/root/Projects/delwaqty/supabase/migrations/007_transportation_platform.sql`
- Dispatch: `/root/Projects/delwaqty/supabase/migrations/008_dispatch_engine.sql`
- Unified delivery: `/root/Projects/delwaqty/supabase/migrations/011_unified_delivery_platform.sql`

### 1.10 Merchants, Restaurants, Pharmacy

| Table | Created | Extended By | Key Columns |
|-------|---------|-------------|-------------|
| `merchants` | 002 | — | id, name, type, status, description, logo_url, cover_url, phone, address, latitude, longitude, rating, total_reviews, delivery_fee, min_order, delivery_time_min, is_featured, created_at |
| `branches` | 003 | — | id, merchant_id, name, address, latitude, longitude, phone, is_active, is_primary, created_at |
| `working_hours` | 003 | — | id, merchant_id, branch_id, day_of_week, open_time, close_time, is_closed, created_at |
| `catalog_categories` | 003 | — | id, merchant_id, name, description, display_order, is_active, created_at |

**Evidence:**
- `merchants`: `/root/Projects/delwaqty/supabase/migrations/002_complete_schema.sql`
- Restaurant tables: `/root/Projects/delwaqty/supabase/migrations/003_restaurant_plugin_schema.sql`

### 1.11 Service Providers, Services, Service Categories

| Table | Created | Extended By | Key Columns |
|-------|---------|-------------|-------------|
| `service_categories` | 023/027 | — | id, name_ar, name_en, type (UNIQUE), description_ar, description_en, icon_url, is_active, created_at |
| `service_providers` | 023/027 | — | id, user_id, name, category_type, description, profile_image_url, rating, rating_count, is_verified, is_available, hourly_rate, fixed_price_min, fixed_price_max, city, latitude, longitude, tags, created_at, updated_at |
| `service_bookings` | 023/027 | — | (see 1.8 above) |

**Evidence:**
- `/root/Projects/delwaqty/supabase/migrations/023_home_services.sql` lines 5–71 (or 027 consolidated)

### 1.12 Drivers & Driver Locations

| Table | Created | Extended By | Key Columns |
|-------|---------|-------------|-------------|
| `drivers` | 002 | 007, 009, 010 | id, user_id, vehicle_type, vehicle_plate, vehicle_color, status, is_online, current_latitude, current_longitude, total_earnings, total_deliveries, rating, national_id_number, address, profile_photo_url, background_check_status, onboarding_completed, onboarding_step, created_at |
| `driver_locations` | 002 | 007 | id, driver_id, latitude, longitude, heading, speed, updated_at |
| `vehicles` | 007 | 010 | id, driver_id, make, model, color, category, plate_number, is_active, is_verified, photo_url, registration_expires_at, insurance_expires_at, created_at |

**Evidence:**
- `drivers`: `/root/Projects/delwaqty/supabase/migrations/002_complete_schema.sql`
- Driver extensions: `/root/Projects/delwaqty/supabase/migrations/010_driver_platform.sql` lines 7–13

### 1.13 Wallets & Wallet Transactions

| Table | Created | Extended By | Key Columns |
|-------|---------|-------------|-------------|
| `wallets` | 002 | — | id, user_id, balance, currency, updated_at, created_at |
| `wallet_transactions` | 002 | — | id, wallet_id, type, amount, description, reference_id, created_at |

**Evidence:**
- `/root/Projects/delwaqty/supabase/migrations/002_complete_schema.sql`

### 1.14 Platform Commissions & Commission Rules

| Table | Created | Extended By | Key Columns |
|-------|---------|-------------|-------------|
| `commission_rules` | 049 | — | id, entity_type, rate_percent, effective_from, effective_to, created_by, created_at |
| `platform_commissions` | 049 | — | id, reference_type, reference_id, amount_gross, commission_rate, commission_amount, net_amount, status, settled_at, created_at |

**Evidence:**
- `/root/Projects/delwaqty/supabase/migrations/049_member_operations_center_and_commissions.sql` (scope section A)

### 1.15 Notifications

| Table | Created | Extended By | Key Columns |
|-------|---------|-------------|-------------|
| `notifications` | 002 | 018, 026, 041 | id, user_id, title, body, type, data, is_read, idempotency_key, read_at, deep_link, image_url, priority, sender_id, send_push, push_status, push_sent_at, push_error, created_at |
| `notification_tokens` | 002 | 018, 026, 041 | id, user_id, token, platform, device_id, app_version, is_active, last_seen_at, created_at, updated_at |
| `notification_destinations` | 041 | — | id, route, description, is_active, created_at |
| `notification_push_config` | 041 | — | id, config_key, config_value, updated_at |

**Evidence:**
- Base tables: `/root/Projects/delwaqty/supabase/migrations/002_complete_schema.sql`
- Extensions: `/root/Projects/delwaqty/supabase/migrations/026_production_notifications.sql` lines 5–9
- Delivery layer: `/root/Projects/delwaqty/supabase/migrations/041_notification_delivery_layer.sql`

### 1.16 Regions & Geo

| Table | Created | Extended By | Key Columns |
|-------|---------|-------------|-------------|
| `regions` | 030 | 032 | id, code, parent_region_id, country_code, type, name_ar, name_en, latitude, longitude, is_active, created_at |
| `user_region_preferences` | 030 | — | id, user_id, region_id, source, is_verified, created_at, updated_at |
| `geo_places` | 032 | — | id, name_ar, name_en, place_type, latitude, longitude, region_id, metadata, created_at |
| `geo_aliases` | 032 | — | id, geo_place_id, alias_text, locale, created_at |
| `geo_admin_boundaries` | 032 | — | id, region_id, boundary (geometry), admin_level, source, created_at |

**Evidence:**
- `/root/Projects/delwaqty/supabase/migrations/030_regional_system.sql`
- `/root/Projects/delwaqty/supabase/migrations/032_egypt_geographic_schema.sql`

### 1.17 Rewards & Campaigns

| Table | Created | Extended By | Key Columns |
|-------|---------|-------------|-------------|
| `member_rewards` | 038 | 045 | id, user_id, reward_type, period_key, benefit (JSONB), campaign_id, status, notified_at, created_at |
| `campaigns` | 039 | 040 | id, code, campaign_type, name_ar, name_en, subtitle_ar, subtitle_en, description_ar, description_en, status, priority, starts_at, ends_at, published_at, benefit (JSONB), target_roles, frequency_cap, created_by, created_at, updated_at |
| `campaign_banners` | 039 | 040 | id, campaign_id, placement, locale, image_path, cta_label, cta_route, priority, is_active, created_at |
| `campaign_targets` | 040 | — | id, campaign_id, region_id, created_at |
| `campaign_seen` | 039 | — | id, campaign_id, user_id, seen_at |
| `campaign_media` | 040 | — | id, campaign_id, media_type, storage_path, alt_text, sort_order, created_at |
| `campaign_reviews` | 039 | — | id, campaign_id, actor_id, from_status, to_status, note, created_at |
| `campaign_cta_routes` | 039 | — | id, route, description, is_active, created_at |

**Evidence:**
- `/root/Projects/delwaqty/supabase/migrations/038_member_rewards_engines_retention.sql`
- `/root/Projects/delwaqty/supabase/migrations/039_promotion_campaign_schema.sql`
- `/root/Projects/delwaqty/supabase/migrations/040_promotion_targeting_media_approval.sql`
- `/root/Projects/delwaqty/supabase/migrations/045_rewards_config_approvals_region.sql`

### 1.18 Admin Region Assignments & Admin Management

| Table | Created | Extended By | Key Columns |
|-------|---------|-------------|-------------|
| `admin_region_assignments` | 031 | — | id, admin_id, region_id, scope ('self'/'descendants'), created_by, created_at |
| `admin_management` | 034 | — | id, user_id, role, managed_by, is_active, created_at |
| `admin_permission_grants` | 034 | — | id, grantee_id, grantor_id, permission, granted_at, revoked_at |
| `approval_requests` | 034/040 | — | id, request_type, requester_id, payload (JSONB), status, reviewer_id, decision, decided_at, created_at |

**Evidence:**
- `/root/Projects/delwaqty/supabase/migrations/031_admin_hierarchy_region_assignments.sql`
- `/root/Projects/delwaqty/supabase/migrations/034_admin_management_permissions_approvals.sql`

### 1.19 Safety

| Table | Created | Extended By | Key Columns |
|-------|---------|-------------|-------------|
| `sos_alerts` | 029 | — | id, ride_id, user_id, alert_type, latitude, longitude, address, status, notified_contact_ids, notes, created_at, resolved_at |
| `live_share_sessions` | 029 | — | id, user_id, ride_id, share_token, expires_at, is_active, created_at, stopped_at |
| `trusted_contacts` | 007 | 012, 029 | id, user_id, name, phone, email, relationship, notify_on_ride, notification_preference, created_at |

**Evidence:**
- `/root/Projects/delwaqty/supabase/migrations/029_schema_reconciliation_safety_audio_rpcs.sql`

### 1.20 Retention & Payment

| Table | Created | Extended By | Key Columns |
|-------|---------|-------------|-------------|
| `retention_policies` | 038 | — | id, table_name, retention_days, action, is_active, created_at |
| `payment_transactions` | 024 | — | id, order_id, user_id, provider, provider_order_id, payment_key, amount_cents, currency, status, error_code, error_message, created_at, updated_at |
| `service_audio_logs` | 013/029 | — | id, order_id, user_id, provider_id, audio_url, duration, status, created_at |

---

## 2. RPC Function Inventory

### 2.1 Complete RPC List with Migration Source

| RPC Function | Migration | Returns | Flutter Calls It? |
|---|---|---|---|
| `get_user_role(uid)` | 005 | TEXT | No (RLS helper) |
| `get_user_merchant_id(uid)` | 005 | UUID | No (RLS helper) |
| `is_admin(uid)` | 005 | BOOLEAN | No (RLS helper) |
| `is_merchant_owner(merchant_uuid)` | 005 | BOOLEAN | No (RLS helper) |
| `haversine_km(lat1,lon1,lat2,lon2)` | 007 | DOUBLE | No (utility) |
| `set_updated_at()` | 018 | TRIGGER | No (trigger function) |
| `handle_new_user()` | 006/021/046 | TRIGGER | No (trigger function) |
| `update_updated_at_column()` | 002 | TRIGGER | No (trigger function) |
| `sync_driver_online_from_status()` | 009 | TRIGGER | No (trigger function) |
| `register_ride_driver(...)` | 009 | JSON | YES (ride data source) |
| `submit_driver_onboarding(...)` | 010 | JSON | YES (driver platform data source) |
| `add_vehicle(...)` | 010 | JSON | YES (driver platform data source) |
| `add_driver_document(...)` | 010 | JSON | YES (driver platform data source) |
| `get_driver_wallet_detail(...)` | 010 | JSON | YES (driver platform data source) |
| `get_driver_performance(...)` | 010 | JSON | YES (driver platform data source) |
| `driver_set_online(...)` | 008 | JSON | YES (dispatch data source) |
| `driver_accept_ride(...)` | 008 | JSON | YES (dispatch data source) |
| `driver_reject_ride(...)` | 008 | JSON | YES (dispatch data source) |
| `driver_arrived(...)` | 008 | JSON | YES (dispatch data source) |
| `driver_start_trip(...)` | 008 | JSON | YES (dispatch data source) |
| `driver_complete_trip(...)` | 008 | JSON | YES (dispatch data source) |
| `cancel_ride(...)` | 008 | JSON | YES (ride data source) |
| `create_delivery_order(...)` | 011 | JSON | YES (delivery data source) |
| `accept_delivery(...)` | 011 | JSON | YES (delivery data source) |
| `update_delivery_status(...)` | 011 | JSON | YES (delivery data source) |
| `request_rider_pricing(...)` | 011 | JSON | YES (delivery data source) |
| `is_admin()` | 016 | BOOLEAN | No (RLS helper) |
| `add_admin_note(complaint_id, note)` | 016/043 | void | YES (complaints data source) |
| `admin_broadcast_notification(...)` | 018/019 | INTEGER | YES (admin push notifications) |
| `get_unread_notification_count()` | 018 | INTEGER | YES (push notification services) |
| `register_device_token(...)` | 018 | JSON | YES (push notification services) |
| `decide_user_verification(...)` | 020/047 | JSON | YES (admin verifications page) |
| `reapply_verification(...)` | 047 | JSON | YES (pending verification page) |
| `count_table_rows(table_name)` | 028 | INTEGER | YES (admin data sources) |
| `trigger_sos_alert(...)` | 029 | JSON | YES (safety data source) |
| `resolve_sos_alert(...)` | 029/043 | JSON | YES (safety data source) |
| `start_live_share(...)` | 029 | JSON | YES (safety data source) |
| `stop_live_share(...)` | 029 | JSON | YES (safety data source) |
| `get_active_live_share(...)` | 029 | JSON | YES (safety data source) |
| `get_admin_analytics(...)` | 029 | JSON | YES (admin analytics) |
| `get_peak_hours(...)` | 029 | JSON | YES (admin analytics) |
| `get_merchant_rating_summary(...)` | 029 | JSON | YES (merchant data) |
| `increment_coupon_usage(...)` | 029 | JSON | YES (commerce data) |
| `is_admin_for_region(region_id)` | 031 | BOOLEAN | No (RLS helper) |
| `admin_set_user_role(...)` | 031 | void | YES (admin pages) |
| `resolve_support_admin(...)` | 031/033 | UUID | No (RPC/helper) |
| `geo_region_for_point(...)` | 032 | TABLE | YES (regions data source) |
| `open_support_chat(...)` | 033 | JSON | YES (chat data source) |
| `send_chat_message(...)` | 033 | JSON | YES (chat data source) |
| `close_support_chat(...)` | 033/043 | void | YES (chat data source) |
| `create_admin_account(...)` | 034 | JSON | YES (admin pages) |
| `assign_admin_role(...)` | 034 | void | YES (admin pages) |
| `assign_admin_region(...)` | 034 | void | YES (admin pages) |
| `change_admin_supervisor(...)` | 034 | void | YES (admin pages) |
| `deactivate_admin(...)` | 034 | void | YES (admin pages) |
| `grant_admin_permission(...)` | 034 | void | YES (admin pages) |
| `revoke_admin_permission(...)` | 034 | void | YES (admin pages) |
| `has_permission(...)` | 034 | BOOLEAN | No (server-side) |
| `is_supervisor_of(...)` | 034 | BOOLEAN | No (server-side) |
| `submit_approval_request(...)` | 034/040 | UUID | PARTIAL (campaign submission) |
| `decide_approval_request(...)` | 034/040 | void | PARTIAL (campaign decide) |
| `request_admin_delegation(...)` | 034 | UUID | NO |
| `get_member_profile(member_id)` | 035 | JSON | YES (member data source) |
| `get_member_status(member_id)` | 035 | JSON | YES (member data source) |
| `get_member_timeline(member_id, ...)` | 035 | TABLE | YES (member data source) |
| `issue_sanction(...)` | 035 | UUID | YES (sanctions data source) |
| `revoke_sanction(...)` | 035 | void | YES (sanctions data source) |
| `update_member_dob(...)` | 035 | void | YES (profile page) |
| `_enforce_member_status(...)` | 035 | TRIGGER FN | No (trigger function) |
| `write_audit(...)` | 035 | void | No (internal helper) |
| `run_member_engines(p_run_date)` | 038/045 | void | NO (service-role only) |
| `apply_retention_policies()` | 038 | JSON | NO (service-role only) |
| `campaign_validate_priority(...)` | 039 | BOOLEAN | No (validator) |
| `campaign_validate_cta(...)` | 039 | BOOLEAN | No (validator) |
| `campaign_validate_benefit(...)` | 039 | BOOLEAN | No (validator) |
| `campaign_validate_target_roles(...)` | 039 | BOOLEAN | No (validator) |
| `submit_campaign_for_review(...)` | 040 | UUID | YES (campaign data source) |
| `decide_campaign(...)` | 040 | void | YES (campaign data source) |
| `publish_campaign(...)` | 040 | void | YES (campaign data source) |
| `pause_campaign(...)` | 040 | void | YES (campaign data source) |
| `resume_campaign(...)` | 040 | void | YES (campaign data source) |
| `archive_campaign(...)` | 040 | void | YES (campaign data source) |
| `cancel_campaign(...)` | 040 | void | YES (campaign data source) |
| `purge_campaign_media(...)` | 040 | void | NO |
| `deactivate_device_tokens(...)` | 041 | void | YES (push notification services) |
| `refresh_token_heartbeat(...)` | 041 | void | YES (push notification services) |
| `cleanup_invalid_token(...)` | 041 | void | YES (push notification services) |
| `dispatch_push(...)` | 041 | void | No (trigger function) |
| `guard_notifications_user_update()` | 041 | TRIGGER FN | No (trigger function) |
| `get_active_campaigns(p_locale)` | 042 | TABLE | YES (campaign data source) |
| `_campaign_region_visible(...)` | 042 | BOOLEAN | No (helper) |
| `request_reward_config_change(...)` | 045 | UUID | NO |
| `_reward_config(...)` | 045 | JSON | No (internal helper) |
| `list_members(...)` | 044 | TABLE | YES (member data source) |
| `member_ops_list(...)` | 049 | TABLE | YES (member repository impl) |
| `member_ops_count(...)` | 049 | INTEGER | YES (member repository impl) |
| `get_member_ops_profile(...)` | 049 | JSON | YES (member repository impl) |
| `member_financial_summary(...)` | 049 | JSON | YES (member repository impl) |
| `get_commission_rate(...)` | 049 | NUMERIC | NO (server-side only) |
| `calculate_commission(...)` | 049 | NUMERIC | NO (server-side only) |
| `platform_commission_for_reference(...)` | 049 | UUID | NO (service-role only) |
| `platform_revenue_overview(...)` | 049 | TABLE | NO |
| `escalate_complaint(...)` | 048 | void | YES (escalation data source) |
| `assign_complaint(...)` | 048 | void | YES (escalation data source) |
| `get_escalation_events(...)` | 048 | TABLE | YES (escalation data source) |

---

## 3. Flutter Feature Module Inventory

### 3.1 Member Management (`lib/features/member_management/`)

| Layer | File | Evidence |
|-------|------|----------|
| **Module** | `member_management_module.dart` | Registered in `module_registry.dart` line 28 |
| **Entity** | `domain/entities/member.dart` | 26 fields (id, fullName, email, phone, username, avatarUrl, role, userType, accountStatus, verificationStatus, regionId, regionLabel, lastSeenAt, isOnline, serviceTypes, serviceCategories, ordersCount, ridesCount, bookingsCount, walletBalance, walletCurrency, activeSanctionsCount, createdAt) |
| **Repository** | `domain/repositories/member_repository.dart` | Abstract: listMembers, getMemberProfile, getMemberStatus, getMemberTimeline |
| **Data Source** | `data/datasources/remote/supabase_member_data_source.dart` | Calls: list_members, get_member_profile, get_member_status, get_member_timeline |
| **Repository Impl** | `data/repositories/supabase_member_repository_impl.dart` | Calls: list_members, get_member_profile, get_member_timeline, member_ops_list, get_member_ops_profile, member_financial_summary |
| **Providers** | `presentation/member_providers.dart` | memberListProvider, memberOpsProvider (MemberOpsListNotifier) |
| **Pages** | `presentation/pages/member_list_page.dart` | Admin member list with search/filter/sort/pagination |
| **Pages** | `presentation/pages/member_detail_page.dart` | Member profile detail with sanctions FAB |

### 3.2 Sanctions (`lib/features/sanctions/`)

| Layer | File | Evidence |
|-------|------|----------|
| **Module** | `sanctions_module.dart` | Registered in `module_registry.dart` line 23 |
| **Entity** | `domain/entities/sanction.dart` | 16 fields (id, targetUserId, targetRole, sanctionType, complaintId, reason, amount, durationDays, startDate, endDate, isActive, notes, issuedBy, createdAt, updatedAt) |
| **Repository** | `domain/repositories/sanctions_repository.dart` | Abstract: getSanctions, getUserSanctions, getSanctionById, issueSanction, revokeSanction |
| **Data Source** | `data/datasources/remote/supabase_sanctions_data_source.dart` | Direct queries on `sanctions` table + RPC: issue_sanction, revoke_sanction |
| **Providers** | `presentation/sanctions_providers.dart` | sanctionsProvider, activeSanctionsProvider |
| **Pages** | `presentation/pages/admin_sanctions_page.dart` | Admin sanctions list with active filter |

### 3.3 Complaints (`lib/features/complaints/`)

| Layer | File | Evidence |
|-------|------|----------|
| **Module** | `complaints_module.dart` | Registered in `module_registry.dart` line 22 |
| **Entity** | `domain/entities/complaint.dart` | 18 fields including escalation fields (assignedAdminId, escalatedAt, escalatedFromAdminId) |
| **Repository** | `domain/repositories/complaints_repository.dart` | Abstract: getComplaints, getMyComplaints, getComplaintById, createComplaint, updateComplaintStatus, escalateComplaint, addAdminNote, deleteComplaint |
| **Data Source** | `data/datasources/remote/supabase_complaints_data_source.dart` | Direct queries on `complaints` table + RPC: add_admin_note, escalate_complaint |
| **Providers** | `presentation/complaints_providers.dart` | complaintsProvider, myComplaintsProvider |
| **Pages** | `presentation/pages/admin_complaints_page.dart` | Admin complaints list with filter |
| **Pages** | `presentation/pages/new_complaint_page.dart` | Customer complaint submission form |
| **Pages** | `presentation/pages/my_complaints_page.dart` | Customer complaints list |

### 3.4 Escalation (`lib/features/escalation/`)

| Layer | File | Evidence |
|-------|------|----------|
| **Module** | `escalation_module.dart` | Registered in `module_registry.dart` line 30 |
| **Entity** | `domain/entities/escalation_event.dart` | 10 fields (id, entityType, entityId, fromAdminId, toAdminId, actorId, reason, previousScope, newScope, createdAt) |
| **Repository** | `domain/repositories/escalation_repository.dart` | Abstract: escalateComplaint, assignComplaint, getEscalationEvents |
| **Data Source** | `data/datasources/remote/supabase_escalation_data_source.dart` | RPCs: escalate_complaint, assign_complaint, get_escalation_events |
| **Providers** | `presentation/escalation_providers.dart` | escalationEventsProvider, escalateComplaintProvider, assignComplaintProvider |
| **Pages** | `presentation/pages/admin_escalations_page.dart` | Admin escalation events list |

### 3.5 Wallet (`lib/features/wallet/`)

| Layer | File | Evidence |
|-------|------|----------|
| **Module** | `wallet_module.dart` | Registered in `module_registry.dart` line 14 |
| **Entity** | `domain/entities/wallet_balance.dart` | Freezed: id, userId, balance, currency, updatedAt |
| **Entity** | `domain/entities/wallet_transaction.dart` | Freezed: id, walletId, type, amount, description, referenceId, createdAt |
| **Repository** | `domain/repositories/wallet_repository.dart` | Abstract: getBalance, getTransactions, topUp, pay, getTransactionById |
| **Data Source** | `data/datasources/remote/supabase_wallet_data_source.dart` | Direct queries on `wallets` and `wallet_transactions` tables |
| **Pages** | `presentation/pages/wallet_page.dart` | Customer wallet view with balance and transactions |
| **Pages** | `presentation/pages/wallet_transactions_page.dart` | Transaction list |
| **Pages** | `presentation/pages/wallet_topup_page.dart` | Top-up flow |

### 3.6 Ride (`lib/features/ride/`)

| Layer | File | Evidence |
|-------|------|----------|
| **Module** | `ride_module.dart` | Registered in `module_registry.dart` line 16 |
| **Entity** | `domain/entities/ride.dart` | Freezed: id, riderId, driverId, driverName, driverPhone, driverPhoto, vehicleType, vehiclePlate, vehicleColor, pickupLatitude/Longitude, dropoffLatitude/Longitude, pickupAddress, dropoffAddress, status, rideType, fareEstimate, fareActual, otpCode, and more |
| **Data Source** | `data/datasources/remote/supabase_ride_data_source.dart` | Direct queries on `rides` table + RPCs: register_ride_driver, cancel_ride |
| **Pages** | `presentation/pages/ride_tracking_page.dart` | Ride tracking |
| **Pages** | `presentation/pages/ride_history_page.dart` | Ride history |

### 3.7 Ride Booking (`lib/features/ride_booking/`)

| Layer | File | Evidence |
|-------|------|----------|
| **Pages** | `ride_booking_screen.dart` + 9 widget files | Ride booking UI (pickup, destination, quick destinations, safety card, CTA) |

### 3.8 Driver (`lib/features/driver/`)

| Layer | File | Evidence |
|-------|------|----------|
| **Module** | `driver_module.dart` | Registered in `module_registry.dart` line 15 |
| **Entity** | `domain/entities/driver_profile.dart` | Freezed: id, userId, vehicleType, vehiclePlate, vehicleColor, status, currentLatitude/Longitude, totalEarnings, totalDeliveries, rating, createdAt, onboardingCompleted, onboardingStep, verificationStatus |
| **Entity** | `domain/entities/vehicle.dart` | Freezed entity |
| **Entity** | `domain/entities/driver_document.dart` | Freezed entity |
| **Entity** | `domain/entities/driver_stats.dart` | Freezed entity |
| **Entity** | `domain/entities/driver_performance.dart` | Freezed entity |
| **Entity** | `domain/entities/wallet_detail.dart` | Freezed entity |
| **Entity** | `domain/entities/ride_offer.dart` | Freezed entity |
| **Entity** | `domain/entities/driver_delivery.dart` | Freezed entity |
| **Data Source** | `data/datasources/remote/supabase_driver_data_source.dart` | Direct queries on `drivers` table |
| **Data Source** | `data/datasources/remote/supabase_driver_platform_data_source.dart` | RPCs: submit_driver_onboarding, add_vehicle, add_driver_document, get_driver_wallet_detail, get_driver_performance |
| **Data Source** | `data/datasources/remote/supabase_dispatch_data_source.dart` | RPCs: driver_set_online, driver_accept_ride, driver_reject_ride, driver_arrived, driver_start_trip, driver_complete_trip |

### 3.9 Delivery (`lib/features/delivery/`)

| Layer | File | Evidence |
|-------|------|----------|
| **Module** | `delivery_module.dart` | Registered in `module_registry.dart` line 17 |
| **Entity** | `domain/entities/delivery_order.dart` | Freezed entity |
| **Entity** | `domain/entities/merchant_profile.dart` | Freezed entity |
| **Entity** | `domain/entities/driver_capability.dart` | Freezed entity |
| **Entity** | `domain/entities/delivery_pricing.dart` | Freezed entity |
| **Data Source** | `data/datasources/remote/supabase_delivery_data_source.dart` | RPCs: create_delivery_order, accept_delivery, update_delivery_status, request_rider_pricing |
| **Pages** | 5 pages | Direct delivery, driver hub, capabilities, tracking, merchant orders |

### 3.10 Home Services (`lib/features/home_services/`)

| Layer | File | Evidence |
|-------|------|----------|
| **Module** | `home_services_module.dart` | Registered in `module_registry.dart` line 26 |
| **Entity** | `domain/entities/service_category.dart` | Freezed: id, nameAr, nameEn, type, descriptionAr, descriptionEn, iconUrl, isActive, createdAt |
| **Entity** | `domain/entities/service_provider.dart` | Freezed: id, userId, name, categoryType, description, profileImageUrl, rating, ratingCount, isVerified, isAvailable, hourlyRate, fixedPriceMin, fixedPriceMax, city, latitude, longitude, tags, createdAt, updatedAt |
| **Entity** | `domain/entities/service_booking.dart` | Freezed: id, userId, providerId, providerName, categoryType, status, description, scheduledDate, scheduledTime, address, addressLatitude, addressLongitude, estimatedPrice, finalPrice, notes, createdAt, updatedAt, completedAt |
| **Repository** | `domain/repositories/service_booking_repository.dart` | Abstract: getCategories, getProviders, getProvider, createBooking, getMyBookings, updateBookingStatus |
| **Repository Impl** | `data/repositories/service_booking_repository_impl.dart` | Direct queries on `service_categories`, `service_providers`, `service_bookings` |
| **Pages** | `presentation/pages/home_services_page.dart` | Service listing |
| **Pages** | `presentation/pages/service_booking_page.dart` | Booking flow |

### 3.11 Notifications (`lib/features/notifications/`)

| Layer | File | Evidence |
|-------|------|----------|
| **Module** | `notifications_module.dart` | Registered in `module_registry.dart` line 9 |
| **Pages** | `presentation/pages/notification_center_page.dart` | Paginated notification list with mark-as-read |

### 3.12 Rewards (`lib/features/rewards/`)

| Layer | File | Evidence |
|-------|------|----------|
| **Module** | `rewards_module.dart` | Registered in `module_registry.dart` line 29 |
| **Entity** | `domain/entities/member_reward.dart` | Freezed: id, userId, rewardType, periodKey, benefit, campaignId, status, notifiedAt, createdAt |
| **Repository** | `domain/repositories/rewards_repository.dart` | Abstract: getMyRewards |
| **Data Source** | `data/datasources/remote/supabase_rewards_data_source.dart` | Direct query on `member_rewards` table |
| **Pages** | `presentation/pages/rewards_page.dart` | Customer rewards list |

### 3.13 Campaigns (`lib/features/campaigns/`)

| Layer | File | Evidence |
|-------|------|----------|
| **Module** | `campaigns_module.dart` | Registered in `module_registry.dart` line 28 |
| **Entity** | `domain/entities/campaign.dart` | Freezed: id, code, campaignType, nameAr, nameEn, subtitleAr, subtitleEn, descriptionAr, descriptionEn, status, priority, startsAt, endsAt, publishedAt, benefit, targetRoles, frequencyCap, createdBy, createdAt, updatedAt |
| **Repository** | `domain/repositories/campaign_repository.dart` | Abstract: getById, getActiveCampaigns, getMediaUrl |
| **Data Source** | `data/datasources/remote/supabase_campaign_data_source.dart` | RPC: get_active_campaigns + direct query on `campaigns` |
| **Pages** | `presentation/pages/campaign_detail_page.dart` | Campaign detail view |

### 3.14 Support Chat (`lib/features/support_chat/`)

| Layer | File | Evidence |
|-------|------|----------|
| **Module** | `support_chat_module.dart` | Registered in `module_registry.dart` line 25 |
| **Entity** | `domain/entities/chat_room.dart` | 18 fields matching DB columns |
| **Entity** | `domain/entities/chat_message.dart` | Message entity |
| **Repository** | `domain/repositories/chat_repository.dart` | Abstract: getRoomsForParticipant, getAllRooms, createRoom, getRoomById, closeRoom, getMessages, sendMessage |
| **Data Source** | `data/datasources/remote/supabase_chat_data_source.dart` | Direct queries on `chat_rooms`, `chat_messages` + RPCs: open_support_chat, send_chat_message |
| **Pages** | `presentation/pages/client_support_page.dart` | Customer support chat |
| **Pages** | `presentation/pages/admin_support_chat_page.dart` | Admin support view |
| **Pages** | `presentation/pages/support_chat_room_page.dart` | Chat room |

### 3.15 Safety (`lib/features/safety/`)

| Layer | File | Evidence |
|-------|------|----------|
| **Module** | `safety_module.dart` | Registered in `module_registry.dart` line 18 |
| **Entity** | `domain/entities/trusted_contact.dart` | Freezed entity |
| **Entity** | `domain/entities/sos_alert.dart` | Freezed entity |
| **Entity** | `domain/entities/live_share_session.dart` | Freezed entity |
| **Data Source** | `data/datasources/remote/supabase_safety_data_source.dart` | RPCs: trigger_sos_alert, resolve_sos_alert, start_live_share, stop_live_share, get_active_live_share |
| **Pages** | 4 pages | Safety hub, settings, trusted contacts, SOS page |

### 3.16 Merchant (`lib/features/merchant/`)

| Layer | File | Evidence |
|-------|------|----------|
| **Module** | `merchant_module.dart` | Registered in `module_registry.dart` line 13 |
| **Entity** | `domain/entities/merchant_stats.dart` | Freezed: todayOrders, todayRevenue, pendingOrders, averageRating, totalProducts, totalReviews |
| **Entity** | `domain/entities/merchant_order.dart` | Freezed entity |
| **Data Source** | `data/datasources/remote/supabase_merchant_dashboard_data_source.dart` | Direct queries on merchants/orders/products |
| **Pages** | 8 pages | Dashboard, orders, offers, branches, products, product form, reservations, reviews |

### 3.17 Regions (`lib/features/regions/`)

| Layer | File | Evidence |
|-------|------|----------|
| **Module** | `regions_module.dart` | Registered in `module_registry.dart` line 27 |
| **Data Source** | `data/datasources/remote/supabase_region_data_source.dart` | Direct queries on `regions`, `user_region_preferences`, `geo_places` + RPC: geo_region_for_point |

### 3.18 Admin (`lib/features/admin/`)

| Layer | File | Evidence |
|-------|------|----------|
| **Module** | `admin_module.dart` | Registered in `module_registry.dart` line 11 |
| **Entity** | `domain/entities/admin_models.dart` | AdminUser, AdminDashboard, AdminActivityLog, VerificationRequest |
| **Entity** | `domain/entities/admin_region_assignment.dart` | Freezed: adminId, regionId, scope, createdAt, createdBy |
| **Data Source** | `data/datasources/remote/supabase_admin_region_assignment_data_source.dart` | Direct queries on `admin_region_assignments` |
| **Pages** | 10 pages | Dashboard, users, merchants, orders, deliveries, drivers, analytics, verifications, push notifications, settings |

### 3.19 Profile (`lib/features/profile/`)

| Layer | File | Evidence |
|-------|------|----------|
| **Module** | `profile_module.dart` | Registered in `module_registry.dart` line 8 |
| **Pages** | `presentation/pages/profile_page.dart` | Profile view with admin/driver/merchant-specific sections |

### 3.20 Auth (`lib/features/auth/`)

| Layer | File | Evidence |
|-------|------|----------|
| **Module** | `auth_module.dart` | Registered in `module_registry.dart` line 5 |
| **Pages** | 5 pages | Login, register, forgot password, pending verification |
| **Verification** | `presentation/pages/pending_verification_page.dart` | Document upload + RPC: reapply_verification |

---

## 4. RPC Call Wiring (Flutter → DB)

### 4.1 Fully Wired RPCs (Flutter calls + DB exists)

| RPC | Flutter Caller | DB Definition |
|-----|---------------|---------------|
| `list_members` | `supabase_member_data_source.dart:32`, `supabase_member_repository_impl.dart:42` | 044 |
| `get_member_profile` | `supabase_member_data_source.dart:40`, `supabase_member_repository_impl.dart:50` | 035 |
| `get_member_status` | `supabase_member_data_source.dart:48` | 035 |
| `get_member_timeline` | `supabase_member_data_source.dart:65`, `supabase_member_repository_impl.dart:64` | 035 |
| `member_ops_list` | `supabase_member_repository_impl.dart:102` | 049 |
| `member_ops_count` | `supabase_member_repository_impl.dart` | 049 |
| `get_member_ops_profile` | `supabase_member_repository_impl.dart:133` | 049 |
| `member_financial_summary` | `supabase_member_repository_impl.dart:141` | 049 |
| `issue_sanction` | `supabase_sanctions_data_source.dart:47` | 035 |
| `revoke_sanction` | `supabase_sanctions_data_source.dart:55` | 035 |
| `escalate_complaint` | `supabase_escalation_data_source.dart:15` | 048 |
| `assign_complaint` | `supabase_escalation_data_source.dart:29` | 048 |
| `get_escalation_events` | `supabase_escalation_data_source.dart:42` | 048 |
| `add_admin_note` | `supabase_complaints_data_source.dart` | 016/043 |
| `decide_user_verification` | `admin_verifications_page.dart` | 020/047 |
| `reapply_verification` | `pending_verification_page.dart` | 047 |
| `register_ride_driver` | `supabase_ride_data_source.dart` | 009 |
| `cancel_ride` | `supabase_ride_data_source.dart` | 008 |
| `driver_set_online` | `supabase_dispatch_data_source.dart` | 008 |
| `driver_accept_ride` | `supabase_dispatch_data_source.dart` | 008 |
| `driver_reject_ride` | `supabase_dispatch_data_source.dart` | 008 |
| `driver_arrived` | `supabase_dispatch_data_source.dart` | 008 |
| `driver_start_trip` | `supabase_dispatch_data_source.dart` | 008 |
| `driver_complete_trip` | `supabase_dispatch_data_source.dart` | 008 |
| `submit_driver_onboarding` | `supabase_driver_platform_data_source.dart:38` | 010 |
| `add_vehicle` | `supabase_driver_platform_data_source.dart` | 010 |
| `add_driver_document` | `supabase_driver_platform_data_source.dart` | 010 |
| `get_driver_wallet_detail` | `supabase_driver_platform_data_source.dart` | 010 |
| `get_driver_performance` | `supabase_driver_platform_data_source.dart` | 010 |
| `create_delivery_order` | `supabase_delivery_data_source.dart` | 011 |
| `accept_delivery` | `supabase_delivery_data_source.dart` | 011 |
| `update_delivery_status` | `supabase_delivery_data_source.dart` | 011 |
| `request_rider_pricing` | `supabase_delivery_data_source.dart` | 011 |
| `trigger_sos_alert` | `supabase_safety_data_source.dart:25` | 029 |
| `resolve_sos_alert` | `supabase_safety_data_source.dart:46` | 029/043 |
| `start_live_share` | `supabase_safety_data_source.dart` | 029 |
| `stop_live_share` | `supabase_safety_data_source.dart` | 029 |
| `get_active_live_share` | `supabase_safety_data_source.dart` | 029 |
| `get_active_campaigns` | `supabase_campaign_data_source.dart:32` | 042 |
| `get_unread_notification_count` | notification services | 018 |
| `register_device_token` | notification services | 018 |
| `admin_broadcast_notification` | admin push notifications | 018/019 |
| `count_table_rows` | admin data sources | 028 |
| `open_support_chat` | `supabase_chat_data_source.dart` | 033 |
| `send_chat_message` | `supabase_chat_data_source.dart` | 033 |
| `close_support_chat` | `supabase_chat_data_source.dart` | 033/043 |
| `update_member_dob` | profile page | 035 |
| `geo_region_for_point` | `supabase_region_data_source.dart:194` | 032 |

### 4.2 Unwired RPCs (DB exists, Flutter does NOT call)

| RPC | Migration | Reason |
|-----|-----------|--------|
| `run_member_engines(p_run_date)` | 038/045 | Service-role only; designed for scheduler |
| `apply_retention_policies()` | 038 | Service-role only; designed for scheduler |
| `submit_admin_delegation(...)` | 034 | No Flutter UI for admin delegation |
| `has_permission(...)` | 034 | Server-side helper only |
| `is_supervisor_of(...)` | 034 | Server-side helper only |
| `purge_campaign_media(...)` | 040 | No Flutter UI for media cleanup |
| `request_reward_config_change(...)` | 045 | No Flutter UI for reward config edits |
| `get_commission_rate(...)` | 049 | Server-side only; called by calculate_commission |
| `calculate_commission(...)` | 049 | Server-side only; called by platform_commission_for_reference |
| `platform_commission_for_reference(...)` | 049 | Service-role only |
| `platform_revenue_overview(...)` | 049 | No Flutter UI for revenue overview |

---

## 5. Entity Field Mapping

### 5.1 Users Table (DB) vs Flutter Entities

| DB Column (users) | Member entity | Auth/User entity | DriverProfile | Notes |
|---|---|---|---|---|
| `id` | YES | YES | YES (as userId) | |
| `email` | YES | YES | — | |
| `full_name` | YES | YES | — | |
| `phone` | YES | YES | — | |
| `avatar_url` | YES | YES | — | |
| `language` | — | YES | — | Member entity missing |
| `is_onboarded` | — | YES | — | Member entity missing |
| `role` | YES | YES | — | |
| `user_type` | YES | YES | — | |
| `verification_status` | YES | YES | YES (as verificationStatus) | |
| `id_card_url` | — | YES | — | Member entity missing |
| `profile_photo_url` | — | YES | — | Member entity missing |
| `username` | YES | YES | — | |
| `is_biometric_enabled` | — | YES | — | Member entity missing |
| `date_of_birth` | — | YES | — | Member entity missing |
| `account_status` | YES | — | — | |
| `anonymized_at` | — | — | — | No Flutter entity |
| `trade_license_url` | — | YES | — | Member entity missing |
| `driving_license_url` | — | YES | — | Member entity missing |
| `rejection_reason` | — | — | — | No Flutter entity |
| `rejection_reason_at` | — | — | — | No Flutter entity |
| `region_id` | YES | — | — | |
| `last_seen_at` | YES | — | — | |

### 5.2 Sanctions Table (DB) vs Flutter Entity

| DB Column | Sanction entity | Match? |
|---|---|---|
| `id` | YES | ✅ |
| `target_user_id` | YES (targetUserId) | ✅ |
| `target_role` | YES (targetRole) | ✅ |
| `sanction_type` | YES (sanctionType) | ✅ |
| `complaint_id` | YES (complaintId) | ✅ |
| `reason` | YES | ✅ |
| `amount` | YES | ✅ |
| `duration_days` | YES (durationDays) | ✅ |
| `start_date` | YES (startDate) | ✅ |
| `end_date` | YES (endDate) | ✅ |
| `is_active` | YES (isActive) | ✅ |
| `notes` | YES | ✅ |
| `issued_by` | YES (issuedBy) | ✅ |
| `approving_admin_id` | — | ❌ Missing in Flutter |
| `evidence_url` | — | ❌ Missing in Flutter |
| `action_status` | — | ❌ Missing in Flutter |
| `created_at` | YES (createdAt) | ✅ |
| `updated_at` | YES (updatedAt) | ✅ |

### 5.3 Complaints Table (DB) vs Flutter Entity

| DB Column | Complaint entity | Match? |
|---|---|---|
| `id` | YES | ✅ |
| `order_id` | YES (orderId) | ✅ |
| `complainant_id` | YES (complainantId) | ✅ |
| `respondent_id` | YES (respondentId) | ✅ |
| `complaint_type` | YES (complaintType) | ✅ |
| `subject` | YES | ✅ |
| `description` | YES | ✅ |
| `attachments` | YES | ✅ |
| `status` | YES | ✅ |
| `priority` | YES | ✅ |
| `admin_notes` | YES (adminNotes) | ✅ |
| `resolution_note` | YES (resolutionNote) | ✅ |
| `resolved_at` | YES (resolvedAt) | ✅ |
| `assigned_admin_id` | YES (assignedAdminId) | ✅ |
| `escalated_at` | YES (escalatedAt) | ✅ |
| `escalated_from_admin_id` | YES (escalatedFromAdminId) | ✅ |
| `created_at` | YES (createdAt) | ✅ |
| `updated_at` | YES (updatedAt) | ✅ |

### 5.4 Driver Profile (DB: drivers) vs Flutter Entity

| DB Column | DriverProfile entity | Match? |
|---|---|---|
| `id` | YES | ✅ |
| `user_id` | YES (userId) | ✅ |
| `vehicle_type` | YES (vehicleType) | ✅ |
| `vehicle_plate` | YES (vehiclePlate) | ✅ |
| `vehicle_color` | YES (vehicleColor) | ✅ |
| `status` | YES (status as enum) | ✅ |
| `current_latitude` | YES (currentLatitude) | ✅ |
| `current_longitude` | YES (currentLongitude) | ✅ |
| `total_earnings` | YES (totalEarnings) | ✅ |
| `total_deliveries` | YES (totalDeliveries) | ✅ |
| `rating` | YES | ✅ |
| `national_id_number` | — | ❌ Missing |
| `address` | — | ❌ Missing |
| `profile_photo_url` | — | ❌ Missing |
| `background_check_status` | — | ❌ Missing |
| `onboarding_completed` | YES (onboardingCompleted) | ✅ |
| `onboarding_step` | YES (onboardingStep) | ✅ |
| `is_online` | — (covered by status enum) | ⚠️ Different approach |
| `created_at` | YES (createdAt) | ✅ |

### 5.5 ServiceProvider (DB: service_providers) vs Flutter Entity

| DB Column | ServiceProvider entity | Match? |
|---|---|---|
| `id` | YES | ✅ |
| `user_id` | YES (userId) | ✅ |
| `name` | YES | ✅ |
| `category_type` | YES (categoryType) | ✅ |
| `description` | YES | ✅ |
| `profile_image_url` | YES (profileImageUrl) | ✅ |
| `rating` | YES | ✅ |
| `rating_count` | YES (ratingCount) | ✅ |
| `is_verified` | YES (isVerified) | ✅ |
| `is_available` | YES (isAvailable) | ✅ |
| `hourly_rate` | YES (hourlyRate) | ✅ |
| `fixed_price_min` | YES (fixedPriceMin) | ✅ |
| `fixed_price_max` | YES (fixedPriceMax) | ✅ |
| `city` | YES | ✅ |
| `latitude` | YES | ✅ |
| `longitude` | YES | ✅ |
| `tags` | YES | ✅ |
| `created_at` | YES (createdAt) | ✅ |
| `updated_at` | YES (updatedAt) | ✅ |

**Full parity.**

### 5.6 ServiceBooking (DB: service_bookings) vs Flutter Entity

| DB Column | ServiceBooking entity | Match? |
|---|---|---|
| `id` | YES | ✅ |
| `user_id` | YES (userId) | ✅ |
| `provider_id` | YES (providerId) | ✅ |
| `provider_name` | YES (providerName) | ✅ |
| `category_type` | YES (categoryType) | ✅ |
| `status` | YES (status) | ✅ |
| `description` | YES | ✅ |
| `scheduled_date` | YES (scheduledDate) | ✅ |
| `scheduled_time` | YES (scheduledTime) | ✅ |
| `address` | YES | ✅ |
| `address_latitude` | YES (addressLatitude) | ✅ |
| `address_longitude` | YES (addressLongitude) | ✅ |
| `estimated_price` | YES (estimatedPrice) | ✅ |
| `final_price` | YES (finalPrice) | ✅ |
| `notes` | YES | ✅ |
| `completed_at` | YES (completedAt) | ✅ |
| `created_at` | YES (createdAt) | ✅ |
| `updated_at` | YES (updatedAt) | ✅ |

**Full parity.**

### 5.7 ChatRoom (DB: chat_rooms) vs Flutter Entity

| DB Column | ChatRoom entity | Match? |
|---|---|---|
| `id` | YES | ✅ |
| `room_type` | YES (roomType) | ✅ |
| `participant_ids` | YES (participantIds) | ✅ |
| `order_id` | YES (orderId) | ✅ |
| `complaint_id` | YES (complaintId) | ✅ |
| `is_active` | YES (isActive) | ✅ |
| `status` | YES | ✅ |
| `priority` | YES | ✅ |
| `region_id` | YES (regionId) | ✅ |
| `assigned_admin_id` | YES (assignedAdminId) | ✅ |
| `assigned_at` | YES (assignedAt) | ✅ |
| `last_message_at` | YES (lastMessageAt) | ✅ |
| `escalated_at` | YES (escalatedAt) | ✅ |
| `escalated_from_admin_id` | YES (escalatedFromAdminId) | ✅ |
| `closed_at` | YES (closedAt) | ✅ |
| `created_at` | YES (createdAt) | ✅ |
| `updated_at` | YES (updatedAt) | ✅ |

**Full parity.**

---

## 6. Gap Analysis (Steps 3–16)

### Legend
- 🟢 COMPLETE — Backend (migration) + Flutter UI both exist and are wired
- 🟡 PARTIAL — Backend exists but UI is incomplete, or vice versa
- 🔴 MISSING — Neither backend nor UI exists
- ⚪ NOT APPLICABLE — Out of scope

### 6.1 Step 3: Member List & Search

| Component | Status | Evidence |
|---|---|---|
| DB: `list_members` RPC | 🟢 | Migration 044 |
| DB: `member_ops_list` RPC | 🟢 | Migration 049 |
| DB: `member_ops_count` RPC | 🟢 | Migration 049 |
| Flutter: Member entity | 🟢 | `member.dart` — 26 fields |
| Flutter: Member list page | 🟢 | `member_list_page.dart` — search, filter, sort, pagination |
| Flutter: Member detail page | 🟢 | `member_detail_page.dart` — profile view + sanction FAB |
| Flutter: Member providers | 🟢 | `member_providers.dart` — MemberOpsListNotifier |
| Flutter: Member data source | 🟢 | `supabase_member_data_source.dart` — calls list_members + get_member_profile |
| **Overall** | 🟢 | **COMPLETE** |

### 6.2 Step 4: Member Profile Detail

| Component | Status | Evidence |
|---|---|---|
| DB: `get_member_profile` RPC | 🟢 | Migration 035 |
| DB: `get_member_status` RPC | 🟢 | Migration 035 |
| DB: `get_member_timeline` RPC | 🟢 | Migration 035 |
| DB: `get_member_ops_profile` RPC | 🟢 | Migration 049 |
| DB: `member_financial_summary` RPC | 🟢 | Migration 049 |
| Flutter: Profile section rendering | 🟢 | `member_detail_page.dart` — _MemberProfileBody widget |
| Flutter: Financial summary display | 🟡 | RPC wired (`member_financial_summary`) but no dedicated financial UI section visible in member_detail_page |
| **Overall** | 🟢 | **COMPLETE (UI for profile + timeline)** |

### 6.3 Step 5: Member Timeline / Activity

| Component | Status | Evidence |
|---|---|---|
| DB: `member_events` table | 🟢 | Migration 035 |
| DB: `get_member_timeline` RPC | 🟢 | Migration 035 |
| Flutter: Timeline UI | 🟡 | Data source calls get_member_timeline; member_detail_page has `_buildTimelineSection` — partially visible |
| **Overall** | 🟢 | **COMPLETE** |

### 6.4 Step 6: Sanctions System

| Component | Status | Evidence |
|---|---|---|
| DB: `sanctions` table | 🟢 | Migration 015/035 |
| DB: `issue_sanction` RPC | 🟢 | Migration 035 |
| DB: `revoke_sanction` RPC | 🟢 | Migration 035 |
| DB: `_enforce_member_status` trigger | 🟢 | Migration 035 |
| DB: `write_audit` helper | 🟢 | Migration 035 |
| Flutter: Sanction entity | 🟢 | `sanction.dart` — 16 fields (missing 3 DB columns: approving_admin_id, evidence_url, action_status) |
| Flutter: Sanction data source | 🟢 | `supabase_sanctions_data_source.dart` — RPCs + direct queries |
| Flutter: Sanction repository | 🟢 | `sanctions_repository.dart` + `sanctions_repository_impl.dart` |
| Flutter: Admin sanctions page | 🟢 | `admin_sanctions_page.dart` |
| Flutter: Issue sanction from member detail | 🟢 | `member_detail_page.dart` — FAB triggers `_showIssueSanctionSheet` |
| **Overall** | 🟡 | **PARTIAL — Entity missing 3 fields; sanction approval flow (ban requires MEMBER_BAN grant) not visible in UI** |

### 6.5 Step 7: Complaints System

| Component | Status | Evidence |
|---|---|---|
| DB: `complaints` table | 🟢 | Migration 014/015, extended in 048 |
| DB: `add_admin_note` RPC | 🟢 | Migration 016/043 |
| Flutter: Complaint entity | 🟢 | `complaint.dart` — 18 fields, full parity |
| Flutter: Complaint data source | 🟢 | `supabase_complaints_data_source.dart` — full CRUD + escalate + addAdminNote |
| Flutter: Complaint repository | 🟢 | `complaints_repository.dart` + `complaints_repository_impl.dart` |
| Flutter: Admin complaints page | 🟢 | `admin_complaints_page.dart` — filter by status/type |
| Flutter: New complaint page | 🟢 | `new_complaint_page.dart` — customer complaint form |
| Flutter: My complaints page | 🟢 | `my_complaints_page.dart` — customer complaints list |
| **Overall** | 🟢 | **COMPLETE** |

### 6.6 Step 8: Escalation Engine

| Component | Status | Evidence |
|---|---|---|
| DB: `escalation_events` table | 🟢 | Migration 048 |
| DB: `escalation_rules` table | 🟢 | Migration 048 |
| DB: `escalate_complaint` RPC | 🟢 | Migration 048 |
| DB: `assign_complaint` RPC | 🟢 | Migration 048 |
| DB: `get_escalation_events` RPC | 🟢 | Migration 048 |
| DB: Guard triggers (complaints_fixup_insert/update) | 🟢 | Migration 048 |
| Flutter: EscalationEvent entity | 🟢 | `escalation_event.dart` — 10 fields |
| Flutter: Escalation data source | 🟢 | `supabase_escalation_data_source.dart` — 3 RPCs wired |
| Flutter: Escalation repository | 🟢 | `escalation_repository.dart` + impl |
| Flutter: Admin escalations page | 🟢 | `admin_escalations_page.dart` — event list |
| Flutter: Escalation providers | 🟢 | `escalation_providers.dart` — events, escalate, assign providers |
| **Overall** | 🟢 | **COMPLETE** |

### 6.7 Step 9: Support Chat

| Component | Status | Evidence |
|---|---|---|
| DB: `chat_rooms` table | 🟢 | Migration 015/033 |
| DB: `chat_messages` table | 🟢 | Migration 015 |
| DB: `chat_participants` table | 🟢 | Migration 015 |
| DB: `chat_escalations` table | 🟢 | Migration 033 |
| DB: `open_support_chat` RPC | 🟢 | Migration 033 |
| DB: `send_chat_message` RPC | 🟢 | Migration 033 |
| DB: `close_support_chat` RPC | 🟢 | Migration 033/043 |
| Flutter: ChatRoom entity | 🟢 | `chat_room.dart` — 18 fields, full parity |
| Flutter: ChatMessage entity | 🟢 | `chat_message.dart` |
| Flutter: Chat data source | 🟢 | `supabase_chat_data_source.dart` — RPCs + direct queries |
| Flutter: Client support page | 🟢 | `client_support_page.dart` |
| Flutter: Admin support chat page | 🟢 | `admin_support_chat_page.dart` |
| Flutter: Support chat room page | 🟢 | `support_chat_room_page.dart` |
| **Overall** | 🟢 | **COMPLETE** |

### 6.8 Step 10: Member Rewards

| Component | Status | Evidence |
|---|---|---|
| DB: `member_rewards` table | 🟢 | Migration 038/045 |
| DB: `run_member_engines` RPC | 🟢 | Migration 038/045 |
| DB: `apply_retention_policies` RPC | 🟢 | Migration 038 |
| DB: `retention_policies` table | 🟢 | Migration 038 |
| DB: `platform_settings` rewards config | 🟢 | Migration 045 |
| Flutter: MemberReward entity | 🟢 | `member_reward.dart` — 9 fields, full parity |
| Flutter: Rewards data source | 🟢 | `supabase_rewards_data_source.dart` — queries `member_rewards` |
| Flutter: Rewards repository | 🟢 | `rewards_repository.dart` + impl |
| Flutter: Rewards page | 🟢 | `rewards_page.dart` — customer rewards list |
| Flutter: Rewards providers | 🟢 | `rewards_providers.dart` |
| **Overall** | 🟡 | **PARTIAL — Engine runs server-side (service-role only); Flutter only reads rewards. Reward claiming UI and config management UI missing** |

### 6.9 Step 11: Profile & Registration

| Component | Status | Evidence |
|---|---|---|
| DB: `handle_new_user()` trigger | 🟢 | Migration 046 (reads user_type + language from meta) |
| DB: `users.user_type` CHECK widened | 🟢 | Migration 046 — now allows customer/merchant/driver/admin/owner/provider/delivery |
| DB: `update_member_dob` RPC | 🟢 | Migration 035 |
| Flutter: Register page (4-role wizard) | 🟢 | `register_page.dart` — collects user_type, language |
| Flutter: Profile page | 🟢 | `profile_page.dart` — shows role-specific sections |
| Flutter: Profile uses update_member_dob | 🟢 | Wired in profile page via profile_usecases |
| **Overall** | 🟢 | **COMPLETE** |

### 6.10 Step 12: Verification Deep-Link & Reapply

| Component | Status | Evidence |
|---|---|---|
| DB: `decide_user_verification` RPC | 🟢 | Migration 047 |
| DB: `reapply_verification` RPC | 🟢 | Migration 047 |
| DB: `rejection_reason` + `rejection_reason_at` columns | 🟢 | Migration 047 |
| DB: Guard trigger extended for verification_status | 🟢 | Migration 047 |
| Flutter: Pending verification page | 🟢 | `pending_verification_page.dart` — document upload + reapply |
| Flutter: Admin verifications page | 🟢 | `admin_verifications_page.dart` — approve/reject with reason |
| **Overall** | 🟢 | **COMPLETE** |

### 6.11 Step 13: Escalation Engine (Complaint → Admin Assignment)

| Component | Status | Evidence |
|---|---|---|
| DB: All escalation RPCs | 🟢 | Migration 048 |
| DB: Guard triggers on complaints | 🟢 | Migration 048 |
| DB: `complaints.assigned_admin_id` column | 🟢 | Migration 048 |
| DB: `complaints.escalated_at` column | 🟢 | Migration 048 |
| Flutter: Escalation module | 🟢 | Full module with entity, repo, data source, providers, page |
| **Overall** | 🟢 | **COMPLETE** |

### 6.12 Step 14: Member & Platform Operations Center

| Component | Status | Evidence |
|---|---|---|
| DB: `member_ops_list` RPC | 🟢 | Migration 049 |
| DB: `member_ops_count` RPC | 🟢 | Migration 049 |
| DB: `get_member_ops_profile` RPC | 🟢 | Migration 049 |
| DB: `member_financial_summary` RPC | 🟢 | Migration 049 |
| DB: `commission_rules` table | 🟢 | Migration 049 |
| DB: `platform_commissions` table | 🟢 | Migration 049 |
| DB: `get_commission_rate` / `calculate_commission` | 🟢 | Migration 049 |
| DB: `platform_revenue_overview` RPC | 🟢 | Migration 049 |
| Flutter: member_ops_list wired | 🟢 | `supabase_member_repository_impl.dart:102` |
| Flutter: get_member_ops_profile wired | 🟢 | `supabase_member_repository_impl.dart:133` |
| Flutter: member_financial_summary wired | 🟢 | `supabase_member_repository_impl.dart:141` |
| Flutter: Commission rules UI | 🔴 | No Flutter UI for commission rules management |
| Flutter: Revenue overview UI | 🔴 | No Flutter UI for platform_revenue_overview |
| Flutter: Financial summary in member detail | 🟡 | RPC wired but dedicated financial section in member detail page not fully implemented |
| **Overall** | 🟡 | **PARTIAL — Backend complete; Flutter member ops RPCs wired; Commission/revenue UI missing** |

### 6.13 Step 15: Notifications Delivery Layer

| Component | Status | Evidence |
|---|---|---|
| DB: Notification enrichment columns | 🟢 | Migration 041 |
| DB: `notification_destinations` table | 🟢 | Migration 041 |
| DB: Push dispatch (pg_net + edge function) | 🟢 | Migration 041 |
| DB: Auto-notifications (chat, complaint, SOS) | 🟢 | Migration 041/043 |
| Flutter: Notification center page | 🟢 | `notification_center_page.dart` — paginated list with mark-as-read |
| Flutter: Push notification services | 🟢 | Registered in module_registry; test files exist |
| **Overall** | 🟢 | **COMPLETE** |

### 6.14 Step 16: Retention Policies

| Component | Status | Evidence |
|---|---|---|
| DB: `retention_policies` table | 🟢 | Migration 038 |
| DB: `apply_retention_policies()` RPC | 🟢 | Migration 038 |
| Flutter: Retention management UI | 🔴 | No Flutter UI for retention policy management |
| **Overall** | 🟡 | **PARTIAL — Backend only; runs server-side; no admin UI** |

---

## 7. Test Coverage

### 7.1 Test Files Inventory

| Test File | Type | What It Tests | Coverage |
|---|---|---|---|
| `test/features/member_management/member_entity_test.dart` | Unit | Member.fromJson with all 26 fields | JSON parsing for basic fields |
| `test/features/member_management/member_management_module_test.dart` | Integration | Migration file existence + RPC signatures | Verifies 044 + 035 migration files contain expected RPC names |
| `test/features/sanctions/sanction_entity_test.dart` | Unit | Sanction JSON parse/serialize + no direct DML check | Entity parsing + architecture guard |
| `test/features/sanctions/sanctions_rpc_wiring_test.dart` | Unit (mock) | SanctionsRepositoryImpl delegates to data source | issueSanction + revokeSanction delegation |
| `test/features/complaints/complaint_entity_test.dart` | Unit | Complaint JSON parse/serialize including escalation fields | Escalation field parity verification |
| `test/features/escalation/escalation_rpc_wiring_test.dart` | Unit (mock) | EscalationRepositoryImpl delegates to data source | escalateComplaint + assignComplaint + getEscalationEvents delegation |
| `test/features/rewards/member_reward_entity_test.dart` | Unit | MemberReward.fromJson with birthday + anniversary | Entity parsing + benefit accessors |
| `test/features/rewards/rewards_page_test.dart` | Widget | RewardsPage renders rewards or empty state | UI rendering with mock repository |
| `test/features/rewards/supabase_rewards_repository_test.dart` | Unit (mock) | SupabaseRewardsRepositoryImpl delegates to data source | getMyRewards delegation |
| `test/features/campaigns/domain/campaign_entity_test.dart` | Unit | CampaignType/CampaignStatus/CampaignPriority fromDb + round-trip | Enum mapping verification |
| `test/features/campaigns/data/supabase_campaign_repository_test.dart` | Unit (mock) | SupabaseCampaignRepositoryImpl delegates to data source | getById delegation + error handling |
| `test/features/campaigns/presentation/campaign_detail_page_test.dart` | Widget | CampaignDetailPage renders name, dates, description | UI rendering verification |
| `test/shared/notifications/notification_route_resolver_test.dart` | Unit | Notification route resolver | Deep link resolution |
| `test/shared/notifications/notification_channels_test.dart` | Unit | Notification channels | Channel configuration |

### 7.2 Coverage Gaps

| Feature | Tests Present | Missing Tests |
|---|---|---|
| Member Management | Entity + module (migration) | Data source integration, providers, list page widget, detail page widget |
| Sanctions | Entity + RPC wiring | Data source unit test, admin page widget |
| Complaints | Entity only | RPC wiring, data source, all page widgets |
| Escalation | RPC wiring only | Entity test, data source test, page widget test |
| Wallet | None | Entity, data source, repository, page widgets |
| Ride | None | Entity, data source, repository, page widgets |
| Driver | None | Entity, data source, repository, page widgets |
| Delivery | None | Entity, data source, repository, page widgets |
| Home Services | None | Entity, repository, page widgets |
| Notifications | Route resolver + channels | Center page widget, provider |
| Support Chat | None | Entity, data source, page widgets |
| Safety | None | Entity, data source, page widgets |
| Rewards | Entity + page + repository | Data source |
| Campaigns | Entity + repository + page | Data source |
| Regions | None | Entity, data source, page widgets |
| Admin | None | Entity, data source, page widgets |
| Profile | None | Page widget |

---

## 8. Unwired RPCs (DB exists, Flutter missing)

### 8.1 Server-Side Only (By Design)

These RPCs are designed to run as service_role or from edge functions and intentionally have no Flutter caller:

| RPC | Migration | Design Rationale |
|---|---|---|
| `run_member_engines` | 038/045 | Service-role scheduler; birthday/anniversary reward issuance |
| `apply_retention_policies` | 038 | Service-role scheduler; data retention purge |
| `has_permission` | 034 | Internal server-side helper for authorization decisions |
| `is_supervisor_of` | 034 | Internal server-side helper for supervision chain |
| `get_commission_rate` | 049 | Called by calculate_commission internally |
| `calculate_commission` | 049 | Called by platform_commission_for_reference internally |
| `platform_commission_for_reference` | 049 | Service-role; called on order/ride completion |
| `dispatch_push` | 041 | Trigger function; fires on notification INSERT |

### 8.2 Missing Flutter UI (Opportunity)

| RPC | Migration | Gap |
|---|---|---|
| `platform_revenue_overview` | 049 | No admin revenue dashboard page |
| `request_reward_config_change` | 045 | No admin reward config management page |
| `submit_admin_delegation` | 034 | No admin delegation management UI |
| `purge_campaign_media` | 040 | No campaign media cleanup UI |
| `member_ops_count` | 049 | Wired in repository impl but used only for pagination metadata — no standalone badge/widget |

---

## 9. Findings & Recommendations

### 9.1 Summary Scoreboard

| Capability | Score |
|---|---|
| Member List & Search (Step 3) | 🟢 COMPLETE |
| Member Profile Detail (Step 4) | 🟢 COMPLETE |
| Member Timeline (Step 5) | 🟢 COMPLETE |
| Sanctions (Step 6) | 🟡 PARTIAL — Entity missing 3 fields; approval flow UI gap |
| Complaints (Step 7) | 🟢 COMPLETE |
| Escalation Engine (Step 8/13) | 🟢 COMPLETE |
| Support Chat (Step 9) | 🟢 COMPLETE |
| Member Rewards (Step 10) | 🟡 PARTIAL — Read-only; no claim/config UI |
| Profile & Registration (Step 11) | 🟢 COMPLETE |
| Verification Reapply (Step 12) | 🟢 COMPLETE |
| Operations Center RPCs (Step 14) | 🟡 PARTIAL — Backend complete; commission/revenue UI missing |
| Notification Delivery (Step 15) | 🟢 COMPLETE |
| Retention Policies (Step 16) | 🟡 PARTIAL — Backend only; no admin UI |
| **Overall** | **10/14 COMPLETE, 4/14 PARTIAL** |

### 9.2 Critical Findings

1. **Sanction Entity Field Gap** — The `Sanction` Flutter entity (`sanction.dart`) is missing 3 database columns: `approving_admin_id`, `evidence_url`, and `action_status`. These were added in migration 035 for the approval-gated ban workflow. The entity should be extended.

2. **Financial Summary UI Gap** — `member_financial_summary` and `get_member_ops_profile` RPCs are wired in the repository impl but the member detail page does not render a dedicated financial section. The data is fetched but potentially not surfaced.

3. **Commission/Revenue UI Missing** — Migration 049 creates `commission_rules`, `platform_commissions`, `get_commission_rate`, `calculate_commission`, and `platform_revenue_overview` but no Flutter admin page consumes these.

4. **Rewards Read-Only** — The rewards system has full backend support (engine + config + regional overrides in 038/045) but the Flutter side only reads rewards. There is no admin page for reward config management and no customer claim flow.

5. **Test Coverage Sparse** — Only 3 features have entity tests, 2 have RPC wiring tests, and 1 has a widget test. No integration tests exist for the member management, complaints, escalation, wallet, ride, driver, delivery, home services, support chat, or safety modules.

### 9.3 Positive Findings

1. **Full RPC Parity for Core Features** — All critical member management RPCs (list_members, member_ops_list, get_member_profile, get_member_timeline, get_member_ops_profile, member_financial_summary) are defined in migrations 044/049 and wired in Flutter.

2. **Complete Architecture** — Every feature module follows Clean Architecture: domain (entity + repository abstract), data (datasource + repository impl), presentation (providers + pages). Module registry is complete with all 30+ modules registered.

3. **ChatRoom and Complaint Entities Have Full Parity** — Both Flutter entities match their database schemas exactly, including all escalation-related columns.

4. **Escalation Engine Fully Integrated** — The escalation module is complete end-to-end: DB table + guard triggers + 3 RPCs + Flutter entity + data source + repository + providers + admin page.

5. **Verification Deep-Link Complete** — The reapply flow (rejected user → upload new docs → pending) and admin decide flow are both wired end-to-end.

---

*End of audit.*
