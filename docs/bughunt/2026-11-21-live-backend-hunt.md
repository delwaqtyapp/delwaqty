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
