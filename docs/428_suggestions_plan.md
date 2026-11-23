# Suggestions feature (build 11) — design plan

Owner request (WhatsApp, 2026-11-23 08:53 EET): in all four apps (customer,
driver, admin, provider), add a Suggestions entry in the profile screen next
to the existing Complaints entry, so people can send ideas to improve the
platform. Suggestions reach the admin app in their own screen. Reuse the
complaints pattern as much as possible: table with RLS, a submit RPC, admin
list and status. Free tools only, Egyptian Arabic UI text, no rides mentions.
Client change → ships in build 11.

## 1. Database (migration 428_suggestions.sql)

New table `public.suggestions`, a deliberate simplification of
`public.complaints` (000_baseline):

- Columns: id, user_id (FK users, cascade), app_role
  (customer/driver/provider/admin), category (general/app/feature/payment/
  other), subject (≤120 chars), description (≤2000 chars), status
  (pending/reviewing/accepted/rejected/implemented), admin_notes text[],
  resolution_note, reviewed_at, reviewed_by (FK users, set null),
  created_at, updated_at.
- Dropped from the complaints shape (not needed for ideas): order_id,
  ride_id, respondent_id, reporter_id, complaint_type, priority,
  attachments, escalation fields, assigned_admin_id, storage bucket,
  chat-room and sanctions hooks.
- RLS (7 policies, mirrors complaints): users insert/select/update only
  their own rows; is_admin() gets all four operations. No regional scoping:
  suggestions are platform-wide ideas, unlike complaint case data (411).
- Trigger `suggestions_guard_admin_fields` (copy of the complaints guard):
  a non-admin client can edit their own subject/description but never
  status/admin_notes/resolution_note/reviewed_*/user_id/created_at.
- Trigger `suggestions_set_updated_at` via the existing set_updated_at().
- RPC `submit_suggestion(subject, description, category, app_role)`:
  SECURITY DEFINER, validated + trimmed, 10-per-24h per-user rate limit,
  returns the new id. Executable by authenticated only.
- RPC `admin_list_suggestions(status?, limit?, offset?)`: SECURITY DEFINER,
  is_admin() gated, newest first, limit clamped to 500.
- RPC `admin_update_suggestion_status(id, status, resolution_note?)`:
  SECURITY DEFINER, is_admin() gated, stamps reviewed_at/reviewed_by.
- ACLs: all three RPCs revoked from PUBLIC/anon; the guard trigger function
  revoked from PUBLIC/anon/authenticated. Table grants mirror complaints
  (authenticated + postgres + service_role; RLS does the gating).
- Guard block: fresh objects only, aborts if table or RPCs already exist.
  Verify block inside the transaction.

Status note: prod apply happens only via a reviewed prod extract after both
reviewers GO, same as the convergence batch. Staging already has 428 applied
and the rollback test passes (10 sections: submit validation, rate limit,
RLS ownership, guard trigger, admin RPCs incl. denied principals, anon ACL
denied; zero residue).

## 2. Client work (UI keeper agent-01M81MHB4DVZ44B14WCKN5HG62)

New shared module `lib/features/_shared/suggestions/` mirroring
`lib/features/_shared/complaints/`:

- domain: Suggestion entity (fromJson/toJson), repository interface.
- data: SupabaseSuggestionsDataSource calling the three RPCs
  (submit_suggestion for create; admin_list_suggestions +
  admin_update_suggestion_status for admin; direct table select for
  "my suggestions" via RLS, same as getMyComplaints).
- presentation/pages: NewSuggestionPage (subject, category picker,
  description), MySuggestionsPage (own list with status chips),
  AdminSuggestionsPage (list with status filter + triage dialog).
- SuggestionsModule with routes /my-suggestions, /new-suggestion and admin
  route /admin/suggestions.
- Registration: all four module registries (customer, driver, provider,
  admin). NOTE: the Complaints module is registered only in the customer
  app today; the Suggestions entry must be added in all four profile
  screens next to wherever each app's Complaints entry lives (admin app's
  complaints screen is at /admin/complaints; its Suggestions screen goes to
  /admin/suggestions). Driver and provider apps get the submit + my
  suggestions pages; only admin gets the triage screen.
- notification_route_resolver: add a 'suggestions' case only if admin
  notifications are added later; v1 has no notifications.
- Localization (Egyptian Arabic, no rides wording), new keys mirroring the
  complaints keys:
  - suggestions = اقتراحات
  - new_suggestion = اقتراح جديد
  - my_suggestions = اقتراحاتي
  - suggestion_subject = العنوان
  - suggestion_description = اكتب اقتراحك
  - suggestion_category = النوع: عام / التطبيق / ميزة جديدة / الدفع / أخرى
  - suggestion_submit = إرسال
  - suggestion_sent = وصلنا اقتراحك، شكراً لك
  - suggestion_status_pending = جديد
  - suggestion_status_reviewing = بنراجعه
  - suggestion_status_accepted = مقبول
  - suggestion_status_rejected = مرفوض
  - suggestion_status_implemented = اتنفذ
  - admin_suggestions_title = اقتراحات المستخدمين

## 3. Rollout

1. Both reviewers review migration + test + this plan (attachments).
2. On GO: merge migration to master (PR), apply to prod via reviewed
   extract, registry row, postchecks — same discipline as the convergence
   batch.
3. Client module merges into build 11 alongside the other build-11 work.
   Build-10 clients simply won't show the entry; no prod dependency issue
   since the table/RPCs are additive.

## 4. Non-goals (v1)

Attachments/storage bucket, admin notifications, escalation, chat,
analytics events. Each can be a follow-up if the owner wants parity with
complaints.
