# Live Backend Bug Hunt — 2026-11-21

Method: real backend (project bttnlkmwhorjamzemwda), public anon key + dedicated test
accounts (customer / merchant / driver, `bughunt.*@delwaqty-test.invalid`), one test
merchant ("Bughunt Merchant") and one test product ("BUGHUNT Test Meal", 50 EGP).
No production data modified; probe rows deleted immediately after verification.
"Live-verified" = reproduced over the network against the running backend.

---

## F1 — CRITICAL — Price tampering via `create_order_idempotent` (live-verified)

Any authenticated user can create an order with arbitrary prices.

- The function trusts client-supplied `p_subtotal`, `p_delivery_fee`, `p_discount`,
  `p_merchant_name` and per-item `unit_price`/`total_price`. Item validation checks
  only that fields are non-null; it never looks the product up or compares against
  `products.price`, and never checks `p_subtotal` = sum of lines.
- Granted to `authenticated`.
- `payment_status` is forced away from paid/refunded/failed for non-service callers,
  but with `payment_method='cash'` that is irrelevant.
- Repro: RPC call with a real 50 EGP product and `unit_price: 0.01` → order created,
  `total_amount: 0.01`, cash, pending. (Test order created against the test merchant
  and deleted after verification.)
- Secondary: the idempotency lookup is global (`WHERE idempotency_key = ...` without
  `user_id`), so a key collision across users returns another user's order_id.
- Contrast: `create_order` recomputes every price server-side and is clean.
- Fix: recompute prices server-side (or revoke from `authenticated` and route the app
  to `create_order` only); scope idempotency per user.

## F2 — HIGH — `order_tracking` world-readable and world-writable anonymously (live-verified)

- Policies: `ot_view` SELECT public `using (true)`; `ot_insert` INSERT public
  `with check (true)`. No FK on `order_id`. Table is in the realtime publication
  (migration 078) and the customer app reads it for the tracking page.
- Repro (anonymous, anon key only): POST /rest/v1/order_tracking
  `{"order_id": "<any uuid>", "status": "delivered"}` → 201 created. SELECT works too.
- Impact: anyone on the internet can inject fake tracking events into any order —
  customers watching their order receive them over realtime — and read all tracking
  history (empty today, leaks as soon as real orders flow).
- Fix: scope SELECT to order parties; restrict INSERT to system RPCs; add the FK.

## F3 — HIGH — `dispatch_order` always fails on the cron/service path (live-verified)

- The function comments that service_role/NULL-auth calls are allowed "for cron jobs",
  but after matching a driver it calls `log_admin_action`, which
  `RAISE EXCEPTION 'unauthenticated'` when `auth.uid()` IS NULL.
- The exception rolls back the whole transaction: assignment and order_dispatch row lost.
- Reproduced deterministically (begin/rollback): driver matched, then raise.
- Effect: automatic dispatch via cron can never assign; orders stall in
  PENDING_DISPATCH unless an owner/admin triggers dispatch interactively.
- Fix: tolerate NULL actor in `log_admin_action` (actor 'system') or skip the audit
  call on the system path.

## F4 — MEDIUM — Order creation/dispatch flow gaps (live-verified)

(a) `create_order` accepts NULL `p_delivery_latitude/longitude` (defaults NULL, no
    validation). Such an order reaches 'ready'/PENDING_DISPATCH but dispatch scoring
    on NULL coords never matches a driver — permanently undispatchable order.
(b) `accept_order` lets ANY verified driver self-assign ANY order in PENDING_DISPATCH
    (no `order_dispatch` offer required for the caller) and unconditionally sets
    `status='preparing'` — observed downgrading an order from 'ready' back to
    'preparing', and able to move an unconfirmed ('pending') order forward with no
    merchant involvement.
- Fix: require coords at creation; require a pending offer for the calling driver;
  stop driver acceptance from mutating kitchen status.

## F5 — HIGH — Orders flow settles nothing: no earnings, no commission, unpaid delivery (live-verified)

- Full lifecycle driven: create → merchant confirms → (manual dispatch) → driver
  accept → delivering → `merchant_complete_order` → delivered.
- `merchant_complete_order` marks the order delivered with payment_status still
  'pending' and cash_collected_at NULL — no cash collection required.
- No `driver_earnings` row (earnings are ride-scoped: `driver_earnings.ride_id`,
  orders never generate one) and no `driver_obligations` row (no platform commission
  accrual). The driver collects 115 EGP cash and the platform books nothing.
- `confirm_cash_collection` itself is well-built (assigned-driver-or-owner only,
  cash-only, lifecycle-gated, idempotent) — the gap is that nothing forces it and
  nothing accrues around it.
- Fix: gate delivery completion on cash collection (or auto-invoke it), and record
  earnings + commission obligation in the orders flow.

## F6 — MEDIUM — Coupon lifecycle issues (code-level, not live-verified)

- `redeem_coupon` consumes the coupon (used_count+1, redemption row) at order-creation
  time; `cancel_order` does not restore it — a cancelled order permanently burns a
  one-use coupon.
- `redeem_coupon` increments `used_count` without a conditional UPDATE
  (`SET used_count = used_count+1` after a separate SELECT check): two concurrent
  orders can both pass a usage_limit=1 check (TOCTOU).
- Fix: restore/release the redemption on cancel; make the increment conditional and
  re-check inside the UPDATE.

## Notes (architecture)

- Two half-wired parallel delivery systems: legacy orders dispatch vs rides/deliveries.
  `complete_delivery(order)` returns LEGACY_RETIRED; `start_delivery` /
  `driver_arrived_at_pickup` expect rides ("not_your_ride" for orders). An order
  accepted by a driver via `accept_order` sits in ASSIGNED with no driver-side
  completion path — only the merchant can close it via `merchant_complete_order`.
- `create_order` is granted to `anon` (harmless: it raises without auth.uid()).
- `drivers` self-update guard (`drivers_guard_sensitive_fields`) and
  `orders_guard_sensitive` cover the sensitive columns well: earnings, verification,
  financial fields, and status transitions are properly locked.

## F7 — CRITICAL — Anonymous user-enumeration oracles leak account emails (live-verified)

- `lookup_email_by_phone(p_phone)` and `lookup_email_by_username(p_username)` are
  SECURITY DEFINER, executable by `anon`, no rate limiting.
- Repro (anonymous, anon key only): lookup_email_by_phone with a real user's phone
  returned their real account email; lookup_email_by_username('SuperAdmin') likewise.
- Impact: mass phone/username → email harvesting of the entire user base for
  phishing and password spraying.
- Fix: revoke from anon; gate behind server-side proxy with rate limiting, or mask.

## F8 — CRITICAL — WhatsApp OTP verification fully bypassable (live-verified)

- `request_whatsapp_otp` returns `otp_code` in its API response: the out-of-band
  secret is served to the requester. Anonymous repro: request OTP for an arbitrary
  phone, read code from response, verify → `{"ok":true,"verified":true}`.
- When authenticated, `verify_whatsapp_otp` also stamps the (victim's) phone onto the
  caller's account (`UPDATE users SET phone = ... WHERE id = auth.uid()`).
- Secondary: no attempt counter/lockout on verify (6-digit code, 10-min validity,
  unlimited guesses); each request adds a new valid OTP row without invalidating
  previous ones (brute-force amplification).
- Fix: never return the code (server-side send only); rotate/invalidate prior codes;
  attempt limits; require auth for phone-linking flows.

## Verified clean (no issue)

- Wallet layer: cross-user `wallet_pay` debit FORBIDDEN; `wallet_refund`/`wallet_topup`
  not executable by users; `wallet_adjust` owner-only; over-balance and negative
  withdrawals blocked; `create_topup_request` rejects negative amounts.
- Admin RPCs from customer seat: `admin_set_user_role`, `admin_broadcast_notification`,
  `get_admin_analytics` all "Not authorized"; `admin_direct_topup` owner-only;
  `list_all_topup_requests` and `platform_kpi_summary` return NULL without permission.
- Cancel flow: pending cancellable by customer; delivered not cancellable; cross-user
  FORBIDDEN. Double completion blocked (ALREADY_DONE). `confirm_cash_collection`
  correctly gated to assigned driver / owner, idempotent, cash-only, lifecycle-checked.
- `create_order` (new path): server-side pricing, quantity bounds, stock check,
  min-order, coupon merchant scoping — clean.

## F9 — HIGH — Live location share tokens publicly enumerable (policy + live-probe)

- RLS "live share public read by token": roles {public}, qual
  `(is_active = true) AND (expires_at > now())` — the share token is never checked.
  Anyone (anon) can list every active session's user_id, ride_id AND share_token
  (the capability secret itself), breaking the share-link model.
- Live probe returned zero rows today (no active sessions); the hole is standing.
- Fix: drop public SELECT; serve shares via a SECURITY DEFINER function keyed by token.

## F10 — LOW/MEDIUM — `product_inventory` world-readable anonymously (live-verified)

- Anon SELECT returns every merchant's stock_quantity, reserved_quantity,
  low_stock_threshold, is_in_stock. Business-sensitive (competitor intel,
  stock-out targeting), not PII. Policy `inventory_select_public` qual=true.
- Fix: scope to the merchant owner + admins; public menu display only needs
  is_in_stock on the product itself.

## F11 — MEDIUM (latent) — Priced modifiers are never charged

- `create_order` has zero modifier handling: totals are product.price × qty only.
  `create_order_idempotent` stores client-supplied `modifiers` on order_items but
  never prices them either (see F1).
- No priced modifiers exist in the DB today (`product_modifiers.price_adjustment > 0`
  = 0 rows), so nothing is lost yet — but the app's product page exposes modifiers,
  and the first merchant to add a priced extra will give it away free on every order.
- Fix: server-side modifier pricing from product_modifier_options.price_adjustment
  inside create_order.

## Also verified clean

- `send-push` edge function: 401 unauthorized without service credentials.

## F12 — HIGH — Fake reviews: any account can rate any merchant with no order (live-verified)

- reviews INSERT policy allows order_id IS NULL with only auth.uid()=user_id.
- Probe: test customer (never ordered from merchant a1b2c3d4-0003…) posted a
  1-star review with order_id null — INSERT succeeded; probe row deleted.
- Impact: unlimited review-bombing / self-boosting with throwaway accounts
  (trivially created, see F8 OTP bypass). Public SELECT means ratings are
  immediately visible and pollute merchant ratings.
- Fix: require order_id NOT NULL pointing to a completed order by that user
  for that merchant (drop the NULL branch).

## F13 — HIGH — No server-side stock enforcement (live-verified)

- product set to stock_quantity=0 + is_in_stock=false, then create_order qty=3
  SUCCEEDED (order bfef6c47, 165 EGP, since cancelled). stock_quantity also
  never decrements on create (5 -> 5 observed). Stock is cosmetic; oversell
  guaranteed under any concurrency. Fix: enforce + atomically decrement in
  create_order; restore on cancel.

## F14 — HIGH — Cancel after driver assigned; merchant/driver never notified (live-verified)

- cancel_order blocks only delivered/cancelled. Live: order a9dcd505 accepted
  by driver (status preparing, driver assigned), customer cancelled -> ok.
- Notification rows: cancel notice went ONLY to the customer (actor). Merchant
  got the new-order ping but nothing on cancel; driver got nothing and
  driver_id stays on the cancelled order. Driver would pick up a cancelled
  order while the merchant prepares it. No stock restore either (moot, F13).
- Fix: block customer cancel once accepted (merchant/driver-confirmed cancel),
  notify merchant + driver, unassign driver, clean deliveries.

## F15 — HIGH — Merchant self-PATCH sets own public rating (live-verified)

- merchants guard blocks is_featured + status but NOT rating / total_reviews /
  total_orders. Live: merchant session PATCHed own row to rating=5.00,
  total_reviews=999; customer seat correctly blocked by RLS. Reset to 0/0.
- Fix: extend guard trigger to rating/total_reviews/total_orders; recompute
  from reviews/orders only.

## Verified clean (order/merchant seats)

- Order status regression: customer/driver/merchant PATCHes all blocked by
  orders guards; state unchanged.
- mark_order_paid_by_merchant_order: FORBIDDEN (user seats), permission denied
  (anon); payment_status unchanged.
- assign_order_manual: admin-only (forbidden from merchant + driver seats).
- accept_order: caller must own p_driver_id (cross-driver FORBIDDEN).
- provider_create_banner_campaign: provider-only, pending_review flow;
  campaign_cancel admin-only. (PostgREST PGRST202 when DEFAULT params omitted -
  call-shape quirk, not a bug.)
- cancel_delivery/cancel_ride_lifecycle: actor derived from auth.uid(), not the
  client-supplied p_actor_role.

## F16 — CRITICAL — Self-serve unvetted merchant storefronts (live-verified end-to-end)

- users.user_type is NOT covered by the users guard trigger: any signed-in user
  PATCHes user_type='merchant' (204). role, role_key, account_status,
  verification_status ARE guarded (blocked with proper messages).
- resolve_my_merchant then auto-provisions a merchant row for
  user_type IN (merchant, provider) with status='active', is_open=true,
  rating=5.0 - no admin approval, no documents. Live: customer test account
  minted active storefront 82da5114 in two calls (deleted; user_type restored).
- is_admin() reads the guarded role column, so admin takeover does NOT work;
  blast radius is unvetted merchant/provider provisioning (products, orders,
  banner campaigns via provider gate). With F8 OTP bypass, mass fake vendors.
- Fix: guard user_type in the users trigger; require approved provider record
  in resolve_my_merchant instead of auto-minting active merchants.

---

# Second pass (same day): wallet, coupons, admin RPC auth, realtime

## F17 — HIGH — redeem_coupon anon + cross-account (live-verified) — FIXED (175)

- Granted to anon+PUBLIC, SECURITY DEFINER, p_user_id caller-supplied with no
  auth.uid() binding. Proven: signed-out caller burned 2/3 global uses of a
  test coupon, planted coupon_redemptions rows for two foreign users (targeted
  blocking: their orders then fail COUPON_ALREADY_REDEEMED), and the
  already_redeemed reply is a per-user redemption oracle.
- Fix: redeem is self-only (auth.uid() = p_user_id). Only internal caller is
  create_order, which passes the caller's uid. Verified: anon + cross-user
  now forbidden; legit create_order with coupon applies the server-side
  discount and counts exactly one redemption.

## F18 — MEDIUM — coupon usage-limit burn without ordering (live-verified) — FIXED (175)

- increment_coupon_usage (authenticated, bare counter bump) and apply_coupon
  (increments used_count at VALIDATION time) let any signed-in user exhaust
  any coupon's global usage_limit without ordering. Both proven live.
- Fix: both revoked from anon/authenticated/PUBLIC (service_role kept).
  create_order's redeem_coupon is the authoritative counter; the app's extra
  post-order increment now fails silently into an RLS-blocked fallback, which
  also removes the double-count per coupon order.
- Related (not a bug today): the app's fallback attempts a direct UPDATE on
  coupons.used_count; only RLS blocks it. No UPDATE policy exists on coupons.
- Open product question: cancel_order does not release a consumed coupon
  redemption - a cancelled order burns the coupon.

## F19 — CRITICAL — internal exec RPCs: p_actor forgery privilege escalation (live-verified) — FIXED (176)

- _admin_exec_{create,deactivate,reactivate,region,role,supervisor},
  _member_exec_{delete,sanction,revoke_sanction}, _approval_apply and other
  internals were executable by authenticated; their gates validate a
  CALLER-SUPPLIED p_actor, not the caller. Proven: customer account issued an
  ACTIVE sanction against a driver as the owner (account_status flipped to
  restricted); same path could deactivate admins, rewrite roles, soft-delete
  and anonymize any member.
- Fix (176): revoked EXECUTE from PUBLIC/anon/authenticated on 21 internal
  functions (exec internals + write_audit/log_admin_action (fake-audit
  planting) + notify_order_events/notify_notification_push/_enqueue_push +
  _settlement_escalation_sweep + _issue/_redact_delivery_handoff +
  _enforce_member_status/run_member_engines/_provision_business_target/
  _sanction_status_for). Legit paths are SECURITY DEFINER wrappers passing
  auth.uid() themselves; no app code calls these directly; triggers need no
  EXECUTE grant. Re-probes now return permission denied.

## F20 — LOW/MEDIUM — delivery_pricing world-readable (live-verified) — FIXED (177)

- Base fees / per-km / multipliers for all service types readable by anon
  (competitor intel). App reads post-login; estimate_delivery_fee RPC was
  already authenticated-only. Fix: SELECT restricted to authenticated.
  Verified anon -> [], customer unchanged.

## Wallet audit — CLEAN

- wallet_topup/wallet_refund/wallet_pay(uid variant) not granted to app
  roles; wallet_pay(amount variant) is self-only debit; RLS on wallets +
  wallet_transactions has no user UPDATE; approve_wallet_funding_request
  gated by has_financial_permission; admin_direct_topup owner-only.

## Admin RPC audit — wrapper layer CLEAN (post-176)

- assign_admin_role/region, create_admin_account, deactivate_admin,
  count_table_rows, approve_wallet_funding_request, admin_direct_topup all
  check is_admin / supervisor tree / financial permission. The exposure was
  the ungated internal layer (F19).

## Realtime publication audit — CLOSED

- supabase_realtime publishes 26 tables. postgres_changes enforces RLS per
  subscriber, so exposure equals SELECT policy. After 168/169/174/177 every
  published table's SELECT is owner/participant/admin-scoped or intentionally
  public (offers, reviews, coupons - marketing surfaces, product decision to
  keep). The F8-era concern about order_tracking broadcasting is closed by
  the participant-scoped policy (168): realtime inherits it.
- Intentionally-public reads flagged for his awareness, not changed:
  offers (q=true), reviews (q=true), coupons/promo_codes (is_active).

---

# Third pass (same day): provider/booking flows, chat/campaign, dispatch/geo, storage, auth code

## F21 — HIGH — self-serve VERIFIED service providers (live-verified) — FIXED (178)

- resolve_my_service_provider auto-provisioned a service_providers row for
  any authenticated caller with is_verified=true, is_available=true,
  rating=5.0, hourly_rate=100. Combined with the public
  "available providers" policy (is_available=true), one call put anyone in
  the public directory as a verified 5-star provider. Proven live with the
  customer test account (anon could read the fabricated verified listing).
- Fix: provisioning is dormant (unverified, unavailable, no rating, no rate);
  activation goes through the admin verification path. The existing column
  guard already blocks self-update of managed fields. App resolve flow
  unchanged (stable id, idempotent).

## F22 — MEDIUM — customer self-confirm of reservations (live-verified) — FIXED (179)

- RLS allowed the reservation owner to UPDATE their row directly (the
  customer app writes the table, not the RPC), so a customer could set
  status='confirmed' (and table_number etc.) without the merchant. The
  update_reservation_status RPC had the same hole (dead code in-app, but
  callable).
- Fix: SECURITY INVOKER guard trigger - non-merchant non-admin callers may
  only change status to 'cancelled', ownership fields immutable. RPC returns
  MERCHANT_ONLY_STATUS for customer confirms. Verified: REST + RPC self-
  confirm blocked, customer logistics edits and cancel work, merchant
  confirm works.

## Areas audited CLEAN this pass

- Wallet: grant-gated credits, self-only debits, RLS, approval gates.
- Coupons table RLS (no user UPDATE; the app's direct-update fallback is
  RLS-blocked by design).
- Admin RPC wrapper layer (supervisor-tree / permission gates intact; the
  F19 hole was the internal exec layer).
- Chat: message insert participant-scoped; chat RPCs are trigger bodies or
  participant-gated (chat_set_call_status).
- Campaigns: publish/pause/resume/cancel/archive/submit all admin-gated;
  provider banner flow creates draft -> review only.
- Dispatch/driver lifecycle: accept/reject/arrive/start/complete/cancel all
  bind auth.uid() to the driver in the inner functions; driver online-state
  self-scoped with verification + vehicle preconditions.
- Storage: sensitive buckets private + owner/admin-scoped; ID documents in
  private identity-documents (moved off the public profiles bucket in 103);
  public buckets only hold avatars/category images.
- Service bookings: create is self-scoped; estimated_price is a pending
  estimate with no payment attached.

## Notes (no action)

- open_emergency_chat lets any signed-in user open unlimited emergency
  support rooms paging admins (spam vector, LOW). Rate limiting is a
  product decision.
- WhatsApp OTP remains ceremonial until the Meta inbound webhook lands
  (app displays the code for the user to send; verify only checks the
  code). Blocked on business verification - flagged since pass 1.

## Owner decisions 2026-11-21 (voice note ~2:08 PM) + execution

Six decisions relayed by main; all executed same day except Meta (gated).

1. Cancel/edit policy — migration 184 (commit 8b5e026):
   - Customer solo-cancel blocked once status='delivering'
     (OUT_FOR_DELIVERY); lifetime allowance of 2 customer cancels, then
     CANCEL_ALLOWANCE_EXHAUSTED. orders.cancelled_by records
     customer/admin/customer_refusal.
   - add_order_items RPC: add items while pending/confirmed/preparing,
     repriced server-side (same pricing path as create_order), stock
     decrement/restore, coupon discount recomputed on new subtotal,
     merchant notified. Paid orders blocked (ORDER_ALREADY_PAID).
   - report_delivery_refusal RPC (assigned driver, 'delivering' only):
     cancels the order with stock restore + refund, refusal warnings 1/2
     then 2/2, 3rd refusal suspends the customer account
     (users.refusal_count, account_status='suspended').
   - OPEN design calls flagged to owner: cancel allowance is lifetime
     (per-month possible); refusal closure uses reversible 'suspended';
     edits stop at 'ready'.
   - APP-SIDE (Antigravity list): add-items UI on live orders, driver
     refusal button, new error codes OUT_FOR_DELIVERY /
     CANCEL_ALLOWANCE_EXHAUSTED / ORDER_NOT_EDITABLE / ORDER_ALREADY_PAID.
2. Settlement parameters — migration 181 (commit 0d6747a): remittance
   window 12h (was 24h), suspension trigger 1500 EGP unremitted (was
   5000), suspension duration 5 days (was 3-day overdue trigger). Ceiling
   stays 1000, commissions 7%/3% unchanged. Sweep now auto-suspends
   (offline + account_status='suspended' + Arabic push + ops complaint)
   and auto-reactivates after expiry once balance <= 1500.
3. Coupon release on cancel — migration 182 (commit 00a0356):
   cancel_order deletes the coupon_redemptions row and decrements
   used_count exactly once (status transition + row lock), freeing the
   UNIQUE(coupon_id,user_id) slot so the customer can reuse the coupon.
4. Reviews closed to actual customers — migration 183 (commit d9702b0):
   order-less merchant reviews require a delivered order; ride_ratings
   require a completed ride; service_reviews require a completed booking.
5. Meta verification re-check (2:17 PM, config-h, read-only): security
   center now shows "مؤهلة للتحقق" (eligible) with an active "بدء التحقق"
   button — verification flow is OPEN but not started; business NOT
   verified. Live flip stays parked; starting verification needs his
   legal business details/documents and his call.
6. Emergency chat: owner decided NO rate limit on open_emergency_chat.
   Recorded as a decision, not a bug — the LOW spam-vector note above is
   closed by this decision.

## Owner decisions 2026-11-21 (second voice note ~2:28 PM) + execution

Owner has no registered business yet (no سجل تجاري / بطاقة ضريبية /
address proof; startup phase, paperwork comes later).

1. META LIVE FLIP: PARKED entirely until he has سجل تجاري + بطاقة
   ضريبية. The standing flip plan is stood down; no further verification
   re-checks until he says the paperwork exists. State at parking:
   portfolio 999347779858871 is "مؤهلة للتحقق" (eligible) with an active
   "بدء التحقق" button, business NOT verified, Publish not enabled.
2. WhatsApp OTP independence — verified against code + live RPCs: the
   OTP path today is request_whatsapp_otp (DB: generates 6-digit code,
   10-min expiry, invalidates older codes, 3-per-10-min cap) +
   verify_whatsapp_otp (DB check) + a wa.me deep link where the USER
   sends the code from their own WhatsApp to the support number. No
   Graph API / Cloud API call exists anywhere in the repo. So nothing in
   the live registration path depends on the Meta app's Live status or
   business verification; parking the flip degrades NOTHING today. What
   stays unbuilt (was always future work, not a regression): (a)
   business-initiated OTP delivery (code pushed to the user's WhatsApp
   instead of shown in-app), (b) inbound webhook auto-confirmation that
   the user actually sent the message from that number — today
   possession of the WhatsApp number is not cryptographically proven
   (ceremonial, known since pass 1).
3. Facebook login button hidden (commit a32658e):
   kFacebookLoginEnabled=false in lib/shared/widgets/social_auth_buttons.dart
   removes the button from every surface (welcome, login, register —
   the only three callers; driver/merchant apps have no Facebook UI).
   OAuth data layer untouched; flipping the const back re-enables.
   Registration/login now: phone + WhatsApp OTP, Google.
   ANTIGRAVITY BUILD LIST: rebuild the app so the hidden button ships.

## UI/UX audit (user voice-note review, 2026-11-21 PM)

Code-level only (no Flutter SDK in sandbox); every item needs an Antigravity rebuild to verify on device.

1. Login redesign: biometric fingerprint icon moved beside a shrunken login button (login_page.dart); bottom biometric block removed. (e8413cc)
2. Auto-login bug: registration never saved device credentials, so the app-lock gate never engaged for accounts created on device. register_page now saves credentials after signup (mirrors _handlePostLoginSave). Biometrics/app-lock is wired in all 4 apps' routers, not owner-only. (e8413cc)
3. Welcome page restyled to CinematicAuthBackground + login-style buttons to match auth screens. (e8413cc)
4. Driver app: settings gear pushed dead route '/settings' -> now '/settings/privacy-security'. Location permission errors classified as AppErrorKind.location with clear message + Open Settings action (was generic error). Profile quick actions in driver flavor pushed customer dead routes (/wallet, /rewards, /market/orders) -> now driver routes. (e8413cc, bd9da42)
5. Customer app: full static route audit (recursive nested-route resolver vs registry) — no dead routes; provider tiles are flavor-gated and never fire in customer flavor. (bd9da42)
6. Admin quick-access page: 3-4col cube grid replaced with grouped list rows (icon chip + label + chevron); search retained. Also fixed dead '/welcome' in admin app (registered WelcomeModule). (bd9da42)
7. Dedupe: privacy/terms links removed from privacy hub (kept once in profile Support & Legal). (bd9da42)
8. Verification card: registration DOES upload docs (id/license/trade/photo) at signup; admin fetch only surfaced ID+photo. Added VerificationDocuments + repo/service/provider + _VerificationDocsSection on admin verification page (thumbs of all docs, openable; red no-docs warning). Reject-with-reason already existed (p_reason). (5cd21b2)

## Launch checklist (owner decisions 2026-11-21 PM)

- [ ] Test data STAYS during testing (owner decision: Bughunt accounts and all test data remain for now).
- [ ] DAY BEFORE STORE UPLOAD: full test-data cleanup pass — remove Bughunt test accounts (bughunt.customer/merchant/driver), test orders, wallets, transactions, notifications and any other seeded rows from production; verify admin/driver/customer apps show clean state. Only then proceed to store release.
- [ ] Store upload / release after cleanup is verified.

## Open policy confirmations (asked 2:50 PM, answer pending — DO NOT change until confirmed)

- 184 cancel cutoff: implemented = self-cancel blocked only at 'delivering' (migration line 53). His first line said cancellation closes at DRIVER ACCEPTANCE. If confirmed: extend the status guard to driver-accepted/preparing states.
- 184 refusal suspension: implemented = warn at refusals 1-2, suspend at 3rd (`v_count >= 3`, line 372). If he means 2nd: change to `>= 2` and adjust warning copy.

## Migration 185-186: monthly allowances + driver-delay compensation (applied + live-probed 2026-11-21 3:05 PM, commit 9f7eafd)

Owner confirmation: written WhatsApp recap 2:58 PM + his "تمام" reply 2:59 PM. Refusal threshold (warn 1+2, suspend 3rd) confirmed UNCHANGED; window is now monthly.

- cancel allowance: 2/calendar-month (UTC) replacing lifetime; 'delivering' cutoff unchanged. Probed: 2 this-month cancels -> CANCEL_ALLOWANCE_EXHAUSTED; 40-day-old cancel excluded; cancel succeeds with room.
- edits: 3/month via order_edit_events; probed EDIT_ALLOWANCE_EXHAUSTED fires before item validation.
- refusals: monthly count from orders.cancelled_by='customer_refusal'; suspension at 3rd IN MONTH. (Window logic mirrors cancel probe; refusal RPC path itself not re-probed end-to-end - needs a delivering order fixture.)
- driver delay: report_driver_delay / redispatch_delayed_order -> _driver_delay_redispatch (server-only). Ride -> searching, re-offered (146 engine), driver excused no deduction, monthly allowance (platform_settings.driver_delay_monthly_allowance, default 3), beyond-allowance -> high-priority ops complaint, no auto penalty. Probed end-to-end on bughunt rig: event row, ride/order state, driver+customer notifications (Egyptian Arabic apology naming previous captain's breakdown), PENDING_DISPATCH fallback when no drivers free.
- apology credit: platform_settings.delay_apology_discount_egp (default 5) wallet credit, once per order, event row ties amount to order for ops-share reporting.
- 186 (bug found by probing): wallet_refund's 145 guard silently dropped credits to ANOTHER user - hit 185's apology AND 184's driver-reported refusal refund AND admin-cancel refunds. Fixed via revoked server-only _wallet_credit; all three flows rerouted. Re-probed: wallet +5 and delay_apology txn land.
- ANTIGRAVITY BUILD LIST: driver app button to report a delay/breakdown (report_driver_delay), merchant re-dispatch action (redispatch_delayed_order), surface EDIT/CANCEL_ALLOWANCE_EXHAUSTED errors in customer app.
- OPEN for owner: driver-delay allowance exact number (3 now, he said 3-4 - one UPDATE to platform_settings); apology amount exact (5 now, he said ~5-7 - same); consequence beyond driver allowance (currently: logged + ops complaint, no penalty); refusal suspension 2nd-vs-3rd was NOT answered (kept 3rd).

## Migration 187: Cairo month windows (applied + probed 3:07 PM, commit 2a9cecc)

All four allowance functions (cancel_order, add_order_items, report_delivery_refusal, _driver_delay_redispatch) now bound months by Africa/Cairo local month start (verified: Nov 2026 Cairo start = 2026-10-31 22:00 UTC). Cancel path re-probed live after the swap. Change made on main's call under the owner's blanket authority.

## Migration 188 - Policy spec 2026 rules (shipped 2026-11-21 ~15:24 EET)

Source: owner's 2026-11-21 15:14 voice note (full spec, all 5 items).

1. **Delay compensation redesign** - `_driver_delay_redispatch`: no deduction from the
   delayed driver; platform takes NO commission on the replacement driver's order
   (waiver wired into `_record_delivery_earnings` + `_record_order_settlement` for
   delay-flagged orders); customer gift = `delay_apology_percent` (default 7%) of
   order total as a platform gift ("patience appreciation"); monthly delay
   allowance still settles at 3/month (185).
2. **Cancellations** - 2/month (185); on the 3rd, cancel executes then a 5-day
   suspension via `_member_exec_sanction` + Arabic notification; appeal can
   reinstate at management discretion.
3. **Refusals** - refusals 1-2 keep the warn+cancel flow; the 3rd monthly refusal
   is NOT a cancellation: the order stays out for delivery (forced receipt),
   suspension executes at the driver's report, and a `delivery_incidents` row
   (kind `final_refusal_suspension`) is filed for ops. New `refusal_events` table
   is the single monthly counting source.
4. **Admin regions** - `_admin_covers_region` + `_duty_admin_for_region`
   (assigned+available -> nearest ancestor region -> any global admin -> owner),
   `admin_availability` + `set_admin_availability`, `appeals` table with
   `submit_appeal` (customer) / `decide_appeal` (duty admin or owner; approve
   revokes the sanction). `_lift_expired_member_sanctions` runs every 15 min via
   pg_cron so expired suspensions clear without manual action.
5. **Ops automation** - internal AI only; nothing built for Instinct embedding
   (concept-only per spec).
+ `create_order` now rejects suspended/banned customers (`ACCOUNT_SUSPENDED`).

### Live probes (all passed, fixtures cleaned)
- 3rd cancel -> `suspended:true, 5 days`; sanction row + `account_status=suspended`.
- `create_order` while suspended -> `ACCOUNT_SUSPENDED`.
- Appeal: `submit_appeal` routed to duty admin (owner, no region on test user);
  `decide_appeal(approve)` -> sanction `action_status=revoked`, account active.
- Duty resolver: no assignments -> owner (region and null-region cases).
- Refusals: 1st/2nd -> warning + order cancelled; 3rd -> `account_suspended`,
  order NOT cancelled (`delivering`), incident filed, suspension active.
- Delay: `report_driver_delay` -> `apology_amount 8.40` = 7% of 120 order total,
  wallet 240 -> 248.40, ride back to `searching` for redispatch.
- Static: commission waiver present in both settlement functions'
  live prosrc; `_duty_admin_for_region` + `_lift_expired_member_sanctions` exist.

### pg_cron episode during 188 - RESOLVED: never installed, not dropped
- 188's cron.schedule failed with schema "cron" does not exist; initially
  misreported as an extension drop between 15:07-15:19.
- Forensic follow-up (owner-requested) via pg_stat_statements per-statement
  stats_since + job-execution history proved pg_cron was NEVER installed:
  zero executions of any 055 job since August setup, no August-era
  create-extension for pg_cron, and the extension was already absent on
  2026-11-20 ~19:32 EET (agent's own extension-list read during settlement
  design). The 3 historical applications of migration 055 all failed at
  statement 1 unnoticed ("need pg_cron to be scheduled" assumption).
- No intruder, no credential compromise, no dashboard actor. Only platform
  automation (realtime partition housekeeping) touched the DB today.
- Fix applied 2026-11-21 15:19 EET: extension created, all 3 jobs from 055
  scheduled for the FIRST time, plus 188's lift-expired-member-sanctions.
  First-ever runs: run_member_engines hourly, deactivate-stale-tokens daily,
  apply-retention-policies weekly (Sun 02:00 UTC; will first purge
  location_updates/driver_locations > 90d and notifications > 365d).

### App-side work (Antigravity, not in this migration)
- Appeal button in the customer app (routes to `submit_appeal`).
- Pre-warning copy for customers with 2 refusals ("next refusal = 5-day
  suspension, order must be received").
- Friendly error surfaces for `ACCOUNT_SUSPENDED`.
- Admin app: appeals queue (decide_appeal), availability toggle
  (set_admin_availability), incidents queue already exists (146).

### Open residuals
- Region scoping beyond appeals (member moderation, verifications) not yet
  enforced - `is_admin_for_region` exists but unapplied there.
- No lat/lon on regions: "nearest available admin" falls back to region-tree
  distance, not geography.
- Beyond-allowance driver-delay consequence: still ops-flag-only (no owner pick).
