-- Run after migration 155. Fixtures and rows roll back.
-- Verifies the restored campaign/region/promotion RPCs: provider scoping,
-- admin guards, region upsert, and the expanded role CHECK.
BEGIN;
DO $$
DECLARE
  m uuid := gen_random_uuid();   -- merchant owner user
  m2 uuid := gen_random_uuid();  -- second merchant owner
  cu uuid := gen_random_uuid();  -- plain customer
  adm uuid := gen_random_uuid(); -- admin
  mer uuid := gen_random_uuid(); -- merchants row for m
  mer2 uuid := gen_random_uuid();
  v_res jsonb;
  v_cid uuid;
  v_cnt int;
  v_blocked boolean;
  v_region uuid;
BEGIN
  INSERT INTO auth.users(id,email) VALUES
    (m,m::text||'@example.invalid'),(m2,m2::text||'@example.invalid'),
    (cu,cu::text||'@example.invalid'),(adm,adm::text||'@example.invalid');
  INSERT INTO public.users(id,email,role) VALUES
    (m,m::text||'@example.invalid','merchant'),
    (m2,m2::text||'@example.invalid','merchant'),
    (cu,cu::text||'@example.invalid','customer'),
    (adm,adm::text||'@example.invalid','admin')
    ON CONFLICT(id) DO NOTHING;
  -- the auth.users sync trigger pre-creates public.users rows with the default
  -- role, so force the intended roles explicitly
  UPDATE public.users SET role = 'merchant' WHERE id IN (m, m2);
  UPDATE public.users SET role = 'customer' WHERE id = cu;
  UPDATE public.users SET role = 'admin' WHERE id = adm;
  INSERT INTO public.merchants(id, owner_user_id, name)
    VALUES (mer, m, 'Fixture Store A'), (mer2, m2, 'Fixture Store B');
  -- is_admin() requires an active admin_management row; supervisor is self here
  INSERT INTO public.admin_management(admin_id, supervisor_id, is_active)
    VALUES (adm, m, true);

  -- ── provider_create_banner_campaign: merchant creates a draft + submit ──
  PERFORM set_config('request.jwt.claim.sub', m::text, true);
  PERFORM set_config('role','authenticated',true);
  SELECT public.provider_create_banner_campaign('حملة تجريبية', null, null, null, null)
    INTO v_res;
  v_cid := (v_res->>'campaign_id')::uuid;
  IF v_cid IS NULL THEN RAISE EXCEPTION 'provider create returned no campaign: %', v_res; END IF;
  -- verify as service_role (RLS hides non-published campaigns from clients)
  PERFORM set_config('role','service_role',true);
  PERFORM set_config('request.jwt.claim.sub', '', true);
  IF NOT EXISTS (SELECT 1 FROM public.campaigns c WHERE c.id = v_cid AND c.proposed_by = m AND c.status = 'pending_review') THEN
    RAISE EXCEPTION 'campaign not owned by proposer or not pending_review';
  END IF;
  PERFORM set_config('role','authenticated',true);
  PERFORM set_config('request.jwt.claim.sub', m::text, true);

  -- ── provider_list_my_campaigns: owner sees it, other merchant does not ──
  EXECUTE 'SELECT count(*) FROM public.provider_list_my_campaigns() WHERE id = $1'
    INTO v_cnt USING v_cid;
  IF v_cnt <> 1 THEN RAISE EXCEPTION 'owner cannot list own campaign'; END IF;

  PERFORM set_config('request.jwt.claim.sub', m2::text, true);
  EXECUTE 'SELECT count(*) FROM public.provider_list_my_campaigns() WHERE id = $1'
    INTO v_cnt USING v_cid;
  IF v_cnt <> 0 THEN RAISE EXCEPTION 'other merchant sees someone elses campaign'; END IF;

  -- ── plain customer cannot create a provider campaign ──
  PERFORM set_config('request.jwt.claim.sub', cu::text, true);
  v_blocked := false;
  BEGIN
    PERFORM public.provider_create_banner_campaign('x', null, null, null, null);
  EXCEPTION WHEN OTHERS THEN v_blocked := true; END;
  IF NOT v_blocked THEN RAISE EXCEPTION 'customer created a provider campaign'; END IF;

  -- ── non-admin cannot use admin region builder ──
  v_blocked := false;
  BEGIN
    PERFORM public.admin_upsert_region(null, null, 'village', 'قرية اختبار', null, 30.1, 31.2, 2.0);
  EXCEPTION WHEN OTHERS THEN v_blocked := true; END;
  IF NOT v_blocked THEN RAISE EXCEPTION 'customer upserted a region'; END IF;

  -- ── admin: upsert region, update banner, delete banner ──
  PERFORM set_config('request.jwt.claim.sub', adm::text, true);
  SELECT public.admin_upsert_region(null, null, 'village', 'قرية اختبار', 'Test Village', 30.1, 31.2, 2.0)
    INTO v_res;
  v_region := (v_res->>'id')::uuid;
  IF v_region IS NULL THEN RAISE EXCEPTION 'admin_upsert_region returned no id: %', v_res; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.regions r WHERE r.id = v_region
                 AND r.metadata->>'lat' IS NOT NULL) THEN
    RAISE EXCEPTION 'region metadata missing geo';
  END IF;

  SELECT public.admin_update_banner(v_cid, 'حملة معدلة') INTO v_res;
  PERFORM set_config('role','service_role',true);
  PERFORM set_config('request.jwt.claim.sub', '', true);
  IF NOT EXISTS (SELECT 1 FROM public.campaigns c WHERE c.id = v_cid AND c.name_ar = 'حملة معدلة') THEN
    RAISE EXCEPTION 'admin_update_banner did not rename';
  END IF;
  PERFORM set_config('role','authenticated',true);
  PERFORM set_config('request.jwt.claim.sub', adm::text, true);

  SELECT public.admin_delete_banner(v_cid) INTO v_res;
  PERFORM set_config('role','service_role',true);
  PERFORM set_config('request.jwt.claim.sub', '', true);
  IF EXISTS (SELECT 1 FROM public.campaigns c WHERE c.id = v_cid) THEN
    RAISE EXCEPTION 'admin_delete_banner left the campaign';
  END IF;

  -- ── expanded role CHECK accepts a hierarchical admin role ──
  -- (as service_role: the users guard trigger freezes role for client roles;
  --  done last because is_admin() no longer matches village_admin)
  UPDATE public.users SET role = 'village_admin' WHERE id = adm;
  IF NOT EXISTS (SELECT 1 FROM public.users WHERE id = adm AND role = 'village_admin') THEN
    RAISE EXCEPTION 'expanded role check not applied';
  END IF;
END $$;
ROLLBACK;
