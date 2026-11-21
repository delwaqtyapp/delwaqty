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
