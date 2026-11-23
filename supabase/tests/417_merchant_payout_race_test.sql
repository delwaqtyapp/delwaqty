-- 417 actual-role staging run (transaction-wrapped, fixtures rolled back).
-- Serial functional matrix with real roles on live staging; the concurrency
-- race itself, the retarget/delete-under-lock hardening and the live
-- PostgREST one-arg POST were proven by the worker's local rig
-- (run_payout_tests.sh + evidence log, both reviewers GO). The one-arg
-- default resolution is covered here by a positional one-arg SQL call plus
-- the pg_proc catalog assertion.
BEGIN;
DO $$
DECLARE
  u1 uuid := gen_random_uuid(); u2 uuid := gen_random_uuid(); u3 uuid := gen_random_uuid();
  u4 uuid := gen_random_uuid(); adm uuid := gen_random_uuid();
  m1 uuid := gen_random_uuid(); m2a uuid := gen_random_uuid(); m2b uuid := gen_random_uuid();
  m3 uuid := gen_random_uuid();
  v_root uuid := '00000000-0000-0000-0000-000000000001';
  v_r jsonb; v_id uuid; v_id2 uuid; v_n integer;
BEGIN
  -- fixtures
  INSERT INTO auth.users(id,email) SELECT g, g::text||'@x.i' FROM unnest(ARRAY[u1,u2,u3,u4,adm]) g;
  INSERT INTO public.users(id,email,role)
    SELECT g, g::text||'@x.i', CASE WHEN g=adm THEN 'admin' ELSE 'merchant' END
    FROM unnest(ARRAY[u1,u2,u3,u4,adm]) g
    ON CONFLICT(id) DO UPDATE SET role = EXCLUDED.role;
  INSERT INTO public.admin_management(admin_id,supervisor_id,is_active) VALUES (adm,u4,true);
  INSERT INTO public.admin_region_assignments(admin_id,region_id,scope) VALUES (adm,v_root,'descendants');
  INSERT INTO public.merchants(id,owner_user_id,name,type) VALUES
    (m1,u1,'417-a','grocery'),(m2a,u2,'417-b1','grocery'),(m2b,u2,'417-b2','grocery'),(m3,u3,'417-c','grocery');
  INSERT INTO public.merchant_ledger(merchant_id,entry_type,amount,description) VALUES
    (m1,'credit',500,'417 fixture'),(m2a,'credit',200,'417 fixture'),(m3,'credit',100,'417 fixture');

  -- unauthenticated
  PERFORM set_config('role','authenticated',true);
  PERFORM set_config('request.jwt.claim.sub','',true);
  v_r := public.merchant_request_payout(100);
  ASSERT v_r->>'code' = 'UNAUTHENTICATED', '417: unauthenticated not refused';
  v_r := public.admin_review_payout(gen_random_uuid(), true);
  ASSERT v_r->>'code' = 'FORBIDDEN', '417: unauthenticated review not refused';

  -- U1: keyed request, duplicate retry, conflict, blank/oversize key,
  -- pending-exists, insufficient balance, invalid amount
  PERFORM set_config('request.jwt.claim.sub', u1::text, true);
  v_r := public.merchant_request_payout(100, NULL, '417-K1');
  ASSERT (v_r->>'ok')::boolean, '417: first request failed: ' || v_r::text;
  v_id := (v_r->>'id')::uuid;
  v_r := public.merchant_request_payout(100, NULL, '417-K1');
  ASSERT (v_r->>'ok')::boolean AND (v_r->>'duplicate')::boolean AND (v_r->>'id')::uuid = v_id,
    '417: idempotent retry not returned as duplicate';
  ASSERT (SELECT count(*) FROM public.merchant_payout_requests WHERE merchant_id=m1) = 1,
    '417: duplicate retry inserted a second row';
  v_r := public.merchant_request_payout(150, NULL, '417-K1');
  ASSERT v_r->>'code' = 'IDEMPOTENCY_CONFLICT', '417: key+amount conflict not detected';
  v_r := public.merchant_request_payout(100, NULL, '   ');
  ASSERT v_r->>'code' = 'INVALID_IDEMPOTENCY_KEY', '417: blank key accepted';
  v_r := public.merchant_request_payout(100, NULL, repeat('k',129));
  ASSERT v_r->>'code' = 'INVALID_IDEMPOTENCY_KEY', '417: oversize key accepted';
  v_r := public.merchant_request_payout(60);
  ASSERT v_r->>'code' = 'PENDING_EXISTS', '417: second pending allowed';
  v_r := public.merchant_request_payout(100000, m2a);
  ASSERT v_r->>'code' = 'FORBIDDEN', '417: foreign merchant not refused';
  v_r := public.merchant_request_payout(100000, m1);
  ASSERT v_r->>'code' = 'INSUFFICIENT_BALANCE', '417: over-balance request allowed';
  v_r := public.merchant_request_payout(0, m1);
  ASSERT v_r->>'code' = 'INVALID_AMOUNT', '417: zero amount accepted';

  -- U4: no merchant at all
  PERFORM set_config('request.jwt.claim.sub', u4::text, true);
  v_r := public.merchant_request_payout(10);
  ASSERT v_r->>'code' = 'NO_MERCHANT', '417: ownerless caller not refused';

  -- U2: ambiguous one-arg; explicit resolves
  PERFORM set_config('request.jwt.claim.sub', u2::text, true);
  v_r := public.merchant_request_payout(50);
  ASSERT v_r->>'code' = 'AMBIGUOUS_MERCHANT' AND (v_r->>'owned_merchants')::int = 2,
    '417: ambiguity not detected: ' || v_r::text;
  v_r := public.merchant_request_payout(50, m2a);
  ASSERT (v_r->>'ok')::boolean, '417: explicit merchant request failed: ' || v_r::text;

  -- merchant cannot review
  v_r := public.admin_review_payout(v_id, true);
  ASSERT v_r->>'code' = 'FORBIDDEN', '417: merchant could review payouts';

  -- admin: NULL decision, approve happy path with ledger debit
  PERFORM set_config('request.jwt.claim.sub', adm::text, true);
  v_r := public.admin_review_payout(v_id, NULL);
  ASSERT v_r->>'code' = 'INVALID_DECISION', '417: NULL decision acted on';
  ASSERT (SELECT status FROM public.merchant_payout_requests WHERE id=v_id) = 'pending',
    '417: NULL decision changed status';
  v_r := public.admin_review_payout(v_id, true);
  ASSERT (v_r->>'ok')::boolean, '417: approve failed: ' || v_r::text;
  ASSERT (SELECT status FROM public.merchant_payout_requests WHERE id=v_id) = 'approved', '417: not approved';
  ASSERT (SELECT amount FROM public.merchant_ledger WHERE merchant_id=m1 AND entry_type='debit') = 100,
    '417: approve posted no debit';
  v_r := public.admin_review_payout(v_id, true);
  ASSERT v_r->>'code' = 'INVALID_STATE', '417: double review allowed';

  -- U1 one-arg call now that nothing is pending (positional default
  -- resolution; PostgREST proven by worker rig + catalog assertion below)
  PERFORM set_config('request.jwt.claim.sub', u1::text, true);
  v_r := public.merchant_request_payout(50);
  ASSERT (v_r->>'ok')::boolean, '417: one-arg call failed: ' || v_r::text;
  v_id2 := (v_r->>'id')::uuid;

  -- U3: approve-time balance recheck (NO-GO #126 core)
  PERFORM set_config('request.jwt.claim.sub', u3::text, true);
  v_r := public.merchant_request_payout(80, m3);
  ASSERT (v_r->>'ok')::boolean, '417: u3 request failed';
  v_id2 := (v_r->>'id')::uuid;
  PERFORM set_config('role','none',true);
  INSERT INTO public.merchant_ledger(merchant_id,entry_type,amount,description) VALUES (m3,'debit',70,'417 race sim');
  PERFORM set_config('role','authenticated',true);
  PERFORM set_config('request.jwt.claim.sub', adm::text, true);
  v_r := public.admin_review_payout(v_id2, true);
  ASSERT v_r->>'code' = 'INSUFFICIENT_BALANCE' AND (v_r->>'balance')::numeric = 30,
    '417: approve-time recheck missing: ' || v_r::text;
  ASSERT (SELECT status FROM public.merchant_payout_requests WHERE id=v_id2) = 'pending',
    '417: insufficient approve changed status';
  -- restore funds, approve succeeds; then reject path on a fresh request
  PERFORM set_config('role','none',true);
  DELETE FROM public.merchant_ledger WHERE merchant_id=m3 AND entry_type='debit' AND description='417 race sim';
  PERFORM set_config('role','authenticated',true);
  v_r := public.admin_review_payout(v_id2, true);
  ASSERT (v_r->>'ok')::boolean, '417: funded approve failed';
  PERFORM set_config('request.jwt.claim.sub', u3::text, true);
  v_r := public.merchant_request_payout(10, m3);
  v_id2 := (v_r->>'id')::uuid;
  PERFORM set_config('request.jwt.claim.sub', adm::text, true);
  v_r := public.admin_review_payout(v_id2, false, '417 reject test');
  ASSERT (v_r->>'ok')::boolean, '417: reject failed';
  ASSERT (SELECT status FROM public.merchant_payout_requests WHERE id=v_id2) = 'rejected'
     AND (SELECT rejection_reason FROM public.merchant_payout_requests WHERE id=v_id2) = '417 reject test',
    '417: rejection not recorded';
-- m3 has exactly one debit: the earlier approved 80. The rejected 10 must
  -- not add another.
  ASSERT (SELECT count(*) FROM public.merchant_ledger WHERE merchant_id=m3 AND entry_type='debit') = 1
     AND (SELECT sum(amount) FROM public.merchant_ledger WHERE merchant_id=m3 AND entry_type='debit') = 80,
    '417: rejection posted a debit';
  PERFORM set_config('role','none',true);

  -- catalog: one overload, 3 args, 2 defaulted (old one-arg callers resolve)
  ASSERT (SELECT count(*) FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
           WHERE n.nspname='public' AND p.proname='merchant_request_payout') = 1,
    '417: more than one merchant_request_payout overload';
  ASSERT (SELECT p.pronargs=3 AND p.pronargdefaults=2 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
           WHERE n.nspname='public' AND p.proname='merchant_request_payout'),
    '417: signature/default mismatch';
  ASSERT (SELECT count(*) FROM pg_indexes WHERE schemaname='public'
           AND tablename='merchant_payout_requests'
           AND indexname IN ('merchant_payout_requests_one_pending_per_merchant','merchant_payout_requests_idempotency_key_unique')) = 2,
    '417: guard indexes missing';
END $$;
SELECT '417 actual-role matrix passed' AS result;
ROLLBACK;
