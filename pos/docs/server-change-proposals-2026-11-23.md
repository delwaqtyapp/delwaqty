# Server change proposals from the desktop review pass (2026-11-23)

From the code-review/security-review fix round on `work/pos-cashier`
(client fixes #114–#120). These are PROPOSALS for the builder agent, who
owns migration numbering. None of them are applied or numbered here.

---

## 1. License gate on cashier mutations (review #119, HIGH)

**Problem.** The client now enforces the license continuously (periodic
verified refresh + offline cutoff), but a tampered client can still push.
`cashier_sync_push` and `cashier_daily_close` check only
`is_merchant_owner`; a merchant whose license is `suspended` or `expired`
past grace can keep writing sales forever.

**Ask.** Add a shared guard and call it at the top of every cashier
mutation RPC (sync_push, daily_close, pharmacy_import_drug is already
covered by the PRO gate in 378 — verify it also covers suspension):

```sql
-- sketch, NOT a migration
CREATE OR REPLACE FUNCTION public.cashier_license_gate(p_merchant_id uuid)
RETURNS void LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path TO 'public', 'pg_temp' AS $f$
DECLARE
  v_worst record;
BEGIN
  SELECT l.status, l.expires_at, l.grace_days INTO v_worst
    FROM public.cashier_licenses l
   WHERE l.merchant_id = p_merchant_id
   ORDER BY (l.status = 'active') DESC, l.expires_at DESC NULLS FIRST
   LIMIT 1;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'LICENSE_REQUIRED';
  END IF;
  IF v_worst.status = 'suspended' THEN
    RAISE EXCEPTION 'LICENSE_SUSPENDED';
  END IF;
  IF v_worst.expires_at IS NOT NULL
     AND now() > v_worst.expires_at + (v_worst.grace_days || ' days')::interval THEN
    RAISE EXCEPTION 'LICENSE_EXPIRED';
  END IF;
END;
$f$;
```

Notes for the client contract: a raised exception surfaces to the client as
an op failure reason; the desktop client treats LICENSE_* reasons as
retryable (they stay queued and upload after renewal — unsynced data must
never be dropped). Consider returning per-op `{ok:false, reason}` instead
of raising for sync_push so one merchant's licensing does not kill the
whole batch... actually sync_push is single-merchant per call, raising is
fine and simpler.

## 2. Resolve client customer ids in sync_push (review #118)

**Problem.** A deferred (آجل) sale to a NEW customer created while offline
was impossible: the sale needs `customer_id` but the server id only exists
after the customer op syncs.

**Client side (done in this pass).** The customer op's own id IS the stable
client customer id; the sale and debt_payment payloads reference it in
`customer_id`.

**Ask.** In `cashier_sync_push`, resolve a `customer_id` that is not an
existing `pos_customers.id` through `client_op_id`:

```sql
-- sketch, NOT a migration; applies to the 'sale' and 'debt_payment' arms
v_cust := NULLIF(v_op->'payload'->>'customer_id','')::uuid;
IF v_cust IS NOT NULL THEN
  SELECT c.id INTO v_cust FROM public.pos_customers c
   WHERE c.merchant_id = p_merchant_id
     AND (c.id = v_cust OR c.client_op_id = v_cust);
END IF;
-- then use v_cust for pos_customer_id / pos_debt_ledger.customer_id
```

Ops arrive in array order and the client now always pushes the customer op
before (or in an earlier batch than) any dependent sale/payment, so the
lookup resolves inside the same call. Until this lands, such sales fail
visibly (FK violation reason) and stay queued — data-safe, but the feature
is dark. Please prioritize.

## 3. Staff identity for the cashier (security review structural follow-up)

**Problem.** Cashier PCs sign in with the merchant OWNER login. The owner
account holds every permission on the platform; a stolen session or a
dishonest cashier is a full-account compromise. Not implemented in this
pass (per the reviewer's instruction) — design proposal below.

**Proposal.**
- New table `pos_staff` (per merchant): id, merchant_id, name, pin_hash,
  role (`cashier`, `manager`), is_active, created_at. No platform user
  account needed per cashier.
- The desktop app still holds ONE Supabase session (the device session,
  created at activation), but every op payload gains `staff_id`; the server
  validates it through a new helper `is_merchant_staff(merchant_id,
  staff_id)` before attributing the sale (`pos_sales.cashier_user_id` stays
  the device account; add `pos_sales.pos_staff_id`).
- PIN unlock locally per shift/sale (fast for Egyptian counters);
  manager-only actions (void, price change, bulk price, debt write-off)
  require a manager PIN. Audit: pos_staff_id on sales, voids, price
  history.
- `cashier_device_link` already binds the device; staff rows sync down via
  cashier_sync_pull (add a `staff` array: id, name, role — never pins).
- Migration sketch: `pos_staff` table + RLS (owner manages, staff rows
  readable by the device session of that merchant), `pos_staff_id` columns,
  the `is_merchant_staff` gate in the cashier RPCs.

**Why not now:** client UX (PIN pad, staff switching), pull contract and
server gates must land together; doing it halfway would weaken audit data.

---

## Also documented in this pass (no server change)

- The device-bound license is per license KEY: a full data-dir copy to a
  second PC fails to restore (DPAPI machine binding + seal device check),
  but DPAPI is machine-bound, not license-bound — any process on the same
  PC can unprotect. Support resets the device binding when a PC is
  replaced. (Noted in license-activation-e2e.md.)
