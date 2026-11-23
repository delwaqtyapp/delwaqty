-- 426 actual-role staging run (transaction-wrapped, everything rolled back).
-- Section A: identical-access battery. Fixtures cover customer, merchant
--   owner, legacy merchant (merchants.id = auth.uid()), stranger, admin and
--   a NULL-uid session. The SAME probe battery runs before and after the
--   verbatim guard body; every result must be identical.
-- Section B: guard paths. The guard body below is a VERBATIM copy of
--   supabase/migrations/426_rls_wrap_merge.sql: apply path (first run),
--   no-op path (second run), drift abort without mutation.
BEGIN;

CREATE TEMP TABLE _probe(phase text, name text, val text);
-- the battery records results while impersonating authenticated
GRANT INSERT ON pg_temp._probe TO authenticated;
-- fixture ids, shared across DO blocks (an on_auth_user_created trigger
-- auto-creates public.users rows, so email lookups are unreliable)
CREATE TEMP TABLE _fx(name text PRIMARY KEY, id uuid);

-- fixtures
DO $$
DECLARE
  ca uuid := gen_random_uuid(); mo uuid := gen_random_uuid(); lg uuid := gen_random_uuid();
  st uuid := gen_random_uuid(); ad uuid := gen_random_uuid(); ow uuid := gen_random_uuid();
  m1 uuid := gen_random_uuid(); o1 uuid := gen_random_uuid(); o2 uuid := gen_random_uuid();
  rm uuid := gen_random_uuid();
BEGIN
  INSERT INTO auth.users(id,email) SELECT g, '426'||g::text||'@x.i' FROM unnest(ARRAY[ca,mo,lg,st,ad,ow]) g;
  INSERT INTO _fx(name,id) VALUES ('custa',ca),('mown',mo),('leg',lg),('stranger',st),('adm',ad),('ow',ow),
    ('m1',m1),('o1',o1),('o2',o2),('room',rm);
  INSERT INTO public.users(id,email,role) VALUES
    (ca,'426'||ca::text||'@x.i','customer'),
    (mo,'426'||mo::text||'@x.i','merchant'),
    (lg,'426'||lg::text||'@x.i','merchant'),
    (st,'426'||st::text||'@x.i','customer'),
    (ad,'426'||ad::text||'@x.i','admin'),
    (ow,'426'||ow::text||'@x.i','owner')
    ON CONFLICT(id) DO UPDATE SET role=EXCLUDED.role;
  INSERT INTO public.admin_management(admin_id,supervisor_id,is_active) VALUES (ad,ow,true);
  INSERT INTO public.regions(id,code,country_code,name_ar,type,is_active) VALUES (gen_random_uuid(),'426R','EG','426','city',true);
  INSERT INTO public.admin_region_assignments(admin_id,region_id) SELECT ad, id FROM public.regions WHERE code='426R';
  INSERT INTO public.admin_permission_grants(admin_id,permission) VALUES (ad,'ORDER_VIEW'),(ad,'ORDER_MANAGE');
  INSERT INTO public.merchants(id,name,owner_user_id,type,status,is_open) VALUES (m1,'426 M1',mo,'restaurant','active',true);
  -- legacy merchant: the merchant ROW id IS the user id (exercises the
  -- m.id = auth.uid() branch of _is_merchant_owner_only)
  INSERT INTO public.merchants(id,name,owner_user_id,type,status,is_open) VALUES (lg,'426 LEG',mo,'restaurant','active',true);
  INSERT INTO public.orders(id,user_id,merchant_id,status,dispatch_status,payment_status,payment_method,subtotal,total_amount,delivery_fee,delivery_latitude,delivery_longitude)
    VALUES (o1,ca,m1,'delivering','ACCEPTED','unpaid','cash',100,120,20,30.426,31.426),
           (o2,ca,lg,'delivering','ACCEPTED','unpaid','cash',100,120,20,30.426,31.426);
  INSERT INTO public.notifications(user_id,title,body) VALUES (ca,'426 a','b'),(st,'426 c','d');
  INSERT INTO public.chat_rooms(id,room_type,participant_ids) VALUES (rm,'support',ARRAY[ca,mo]);
  INSERT INTO public.chat_messages(room_id,sender_id,message) VALUES (rm,ca,'seed');
END $$;

-- battery BEFORE (guard classifies pre vs target itself; access must be
-- identical under either starting state)
DO $$
DECLARE
  v_r text; v_c int;
  v_custa uuid; v_mown uuid; v_leg uuid; v_adm uuid; v_stranger uuid;
  v_room uuid; v_o1 uuid;
BEGIN
  SELECT id INTO v_custa FROM _fx WHERE name='custa';
  SELECT id INTO v_mown FROM _fx WHERE name='mown';
  SELECT id INTO v_leg FROM _fx WHERE name='leg';
  SELECT id INTO v_adm FROM _fx WHERE name='adm';
  SELECT id INTO v_stranger FROM _fx WHERE name='stranger';
  SELECT id INTO v_room FROM _fx WHERE name='room';
  SELECT id INTO v_o1 FROM _fx WHERE name='o1';
  PERFORM set_config('role','authenticated',true);
  PERFORM set_config('request.jwt.claim.sub', v_custa::text, true);
  SELECT count(*) || '|' || coalesce(string_agg(id::text, ',' ORDER BY id::text), '') FROM public.orders INTO v_r;
  INSERT INTO _probe VALUES ('before','orders_select_custA', v_r);
  PERFORM set_config('request.jwt.claim.sub', v_mown::text, true);
  SELECT count(*) || '|' || coalesce(string_agg(id::text, ',' ORDER BY id::text), '') FROM public.orders INTO v_r;
  INSERT INTO _probe VALUES ('before','orders_select_mown', v_r);
  PERFORM set_config('request.jwt.claim.sub', v_leg::text, true);
  SELECT count(*) || '|' || coalesce(string_agg(id::text, ',' ORDER BY id::text), '') FROM public.orders INTO v_r;
  INSERT INTO _probe VALUES ('before','orders_select_leg', v_r);
  PERFORM set_config('request.jwt.claim.sub', v_stranger::text, true);
  SELECT count(*) || '|' || coalesce(string_agg(id::text, ',' ORDER BY id::text), '') FROM public.orders INTO v_r;
  INSERT INTO _probe VALUES ('before','orders_select_stranger', v_r);
  PERFORM set_config('request.jwt.claim.sub', v_adm::text, true);
  SELECT count(*) || '|' || coalesce(string_agg(id::text, ',' ORDER BY id::text), '') FROM public.orders INTO v_r;
  INSERT INTO _probe VALUES ('before','orders_select_adm', v_r);
  PERFORM set_config('request.jwt.claim.sub', '', true);
  SELECT count(*) || '|' || coalesce(string_agg(id::text, ',' ORDER BY id::text), '') FROM public.orders INTO v_r;
  INSERT INTO _probe VALUES ('before','orders_select_nulluid', v_r);
  PERFORM set_config('request.jwt.claim.sub', v_custa::text, true);
  SELECT count(*) || '|' || coalesce(string_agg(id::text, ',' ORDER BY id::text), '') FROM public.notifications INTO v_r;
  INSERT INTO _probe VALUES ('before','notif_select_custA', v_r);
  PERFORM set_config('request.jwt.claim.sub', v_stranger::text, true);
  SELECT count(*) || '|' || coalesce(string_agg(id::text, ',' ORDER BY id::text), '') FROM public.notifications INTO v_r;
  INSERT INTO _probe VALUES ('before','notif_select_stranger', v_r);
  PERFORM set_config('request.jwt.claim.sub', v_custa::text, true);
  SELECT count(*) FROM public.chat_messages WHERE message <> 'PROBE' INTO v_r;
  INSERT INTO _probe VALUES ('before','chat_select_custA', v_r);
  PERFORM set_config('request.jwt.claim.sub', v_mown::text, true);
  SELECT count(*) FROM public.chat_messages WHERE message <> 'PROBE' INTO v_r;
  INSERT INTO _probe VALUES ('before','chat_select_mown', v_r);
  PERFORM set_config('request.jwt.claim.sub', v_stranger::text, true);
  SELECT count(*) FROM public.chat_messages WHERE message <> 'PROBE' INTO v_r;
  INSERT INTO _probe VALUES ('before','chat_select_stranger', v_r);
  PERFORM set_config('request.jwt.claim.sub', v_custa::text, true);
  BEGIN
    INSERT INTO public.chat_messages(room_id,sender_id,message) VALUES (v_room, v_custa, 'PROBE');
    GET DIAGNOSTICS v_c = ROW_COUNT;
    v_r := 'ok:' || v_c;
  EXCEPTION WHEN OTHERS THEN
    v_r := SQLSTATE;
  END;
  INSERT INTO _probe VALUES ('before','chat_insert_custA', v_r);
  PERFORM set_config('request.jwt.claim.sub', v_stranger::text, true);
  BEGIN
    INSERT INTO public.chat_messages(room_id,sender_id,message) VALUES (v_room, v_stranger, 'PROBE');
    GET DIAGNOSTICS v_c = ROW_COUNT;
    v_r := 'ok:' || v_c;
  EXCEPTION WHEN OTHERS THEN
    v_r := SQLSTATE;
  END;
  INSERT INTO _probe VALUES ('before','chat_insert_stranger', v_r);
  PERFORM set_config('request.jwt.claim.sub', v_custa::text, true);
  BEGIN
    UPDATE public.orders SET delivery_fee = delivery_fee WHERE id = v_o1;
    GET DIAGNOSTICS v_c = ROW_COUNT;
    v_r := 'ok:' || v_c;
  EXCEPTION WHEN OTHERS THEN
    v_r := SQLSTATE;
  END;
  INSERT INTO _probe VALUES ('before','orders_update_custA', v_r);
  PERFORM set_config('request.jwt.claim.sub', v_stranger::text, true);
  BEGIN
    UPDATE public.orders SET delivery_fee = delivery_fee WHERE id = v_o1;
    GET DIAGNOSTICS v_c = ROW_COUNT;
    v_r := 'ok:' || v_c;
  EXCEPTION WHEN OTHERS THEN
    v_r := SQLSTATE;
  END;
  INSERT INTO _probe VALUES ('before','orders_update_stranger', v_r);
  PERFORM set_config('request.jwt.claim.sub', v_custa::text, true);
  BEGIN
    UPDATE public.notifications SET title = title WHERE user_id = v_custa;
    GET DIAGNOSTICS v_c = ROW_COUNT;
    v_r := 'ok:' || v_c;
  EXCEPTION WHEN OTHERS THEN
    v_r := SQLSTATE;
  END;
  INSERT INTO _probe VALUES ('before','notif_update_custA', v_r);
  PERFORM set_config('request.jwt.claim.sub', v_stranger::text, true);
  BEGIN
    UPDATE public.notifications SET title = title WHERE user_id = v_custa;
    GET DIAGNOSTICS v_c = ROW_COUNT;
    v_r := 'ok:' || v_c;
  EXCEPTION WHEN OTHERS THEN
    v_r := SQLSTATE;
  END;
  INSERT INTO _probe VALUES ('before','notif_update_stranger', v_r);
  PERFORM set_config('role','none',true);
END $$;

-- apply path: run the verbatim guard body
DO $g$
DECLARE
  r       record;
  v       record;
  v_drift text := '';
  v_bad   int;
BEGIN
  -- Expected pre/post state per touched policy (canonical pg_policies text,
  -- captured live 2026-11-23). action: 'replace' rewrites the policy,
  -- 'drop' removes it (its access is folded into the merged policy).
  DROP TABLE IF EXISTS _g426;
  CREATE TEMP TABLE _g426(
    tablename text, policyname text, cmd text, roles name[], permissive text,
    pre_qual text, pre_check text, tgt_qual text, tgt_check text,
    tgt_ddl text, action text, state text
  );
  INSERT INTO _g426(tablename,policyname,cmd,roles,permissive,pre_qual,pre_check,tgt_qual,tgt_check,tgt_ddl,action)
  VALUES
  ($v0$chat_messages$v0$, $v1$users insert own room messages$v1$, $v2$INSERT$v2$, '{public}'::name[], $v3$PERMISSIVE$v3$, NULL, $v4$((sender_id = auth.uid()) AND (EXISTS ( SELECT 1
   FROM chat_rooms
  WHERE ((chat_rooms.id = chat_messages.room_id) AND (auth.uid() = ANY (chat_rooms.participant_ids))))))$v4$, NULL, $v5$((sender_id = ( SELECT auth.uid() AS uid)) AND (EXISTS ( SELECT 1
   FROM chat_rooms
  WHERE ((chat_rooms.id = chat_messages.room_id) AND (( SELECT auth.uid() AS uid) = ANY (chat_rooms.participant_ids))))))$v5$, $v6$CREATE POLICY "users insert own room messages" ON public.chat_messages AS PERMISSIVE FOR INSERT TO public WITH CHECK (((sender_id = (select auth.uid())) AND (EXISTS ( SELECT 1
   FROM chat_rooms
  WHERE ((chat_rooms.id = chat_messages.room_id) AND ((select auth.uid()) = ANY (chat_rooms.participant_ids)))))));$v6$, 'replace'),
  ($v7$chat_messages$v7$, $v8$users select own room messages$v8$, $v9$SELECT$v9$, '{public}'::name[], $v10$PERMISSIVE$v10$, $v11$(EXISTS ( SELECT 1
   FROM chat_rooms
  WHERE ((chat_rooms.id = chat_messages.room_id) AND (auth.uid() = ANY (chat_rooms.participant_ids)))))$v11$, NULL, $v12$(EXISTS ( SELECT 1
   FROM chat_rooms
  WHERE ((chat_rooms.id = chat_messages.room_id) AND (( SELECT auth.uid() AS uid) = ANY (chat_rooms.participant_ids)))))$v12$, NULL, $v13$CREATE POLICY "users select own room messages" ON public.chat_messages AS PERMISSIVE FOR SELECT TO public USING ((EXISTS ( SELECT 1
   FROM chat_rooms
  WHERE ((chat_rooms.id = chat_messages.room_id) AND ((select auth.uid()) = ANY (chat_rooms.participant_ids))))));$v13$, 'replace'),
  ($v14$chat_messages$v14$, $v15$users update own room messages$v15$, $v16$UPDATE$v16$, '{public}'::name[], $v17$PERMISSIVE$v17$, $v18$((sender_id = auth.uid()) AND (EXISTS ( SELECT 1
   FROM chat_rooms
  WHERE ((chat_rooms.id = chat_messages.room_id) AND (auth.uid() = ANY (chat_rooms.participant_ids))))))$v18$, $v19$((sender_id = auth.uid()) AND (EXISTS ( SELECT 1
   FROM chat_rooms
  WHERE ((chat_rooms.id = chat_messages.room_id) AND (auth.uid() = ANY (chat_rooms.participant_ids))))))$v19$, $v20$((sender_id = ( SELECT auth.uid() AS uid)) AND (EXISTS ( SELECT 1
   FROM chat_rooms
  WHERE ((chat_rooms.id = chat_messages.room_id) AND (( SELECT auth.uid() AS uid) = ANY (chat_rooms.participant_ids))))))$v20$, $v21$((sender_id = ( SELECT auth.uid() AS uid)) AND (EXISTS ( SELECT 1
   FROM chat_rooms
  WHERE ((chat_rooms.id = chat_messages.room_id) AND (( SELECT auth.uid() AS uid) = ANY (chat_rooms.participant_ids))))))$v21$, $v22$CREATE POLICY "users update own room messages" ON public.chat_messages AS PERMISSIVE FOR UPDATE TO public USING (((sender_id = (select auth.uid())) AND (EXISTS ( SELECT 1
   FROM chat_rooms
  WHERE ((chat_rooms.id = chat_messages.room_id) AND ((select auth.uid()) = ANY (chat_rooms.participant_ids))))))) WITH CHECK (((sender_id = (select auth.uid())) AND (EXISTS ( SELECT 1
   FROM chat_rooms
  WHERE ((chat_rooms.id = chat_messages.room_id) AND ((select auth.uid()) = ANY (chat_rooms.participant_ids)))))));$v22$, 'replace'),
  ($v23$notifications$v23$, $v24$Users can view own notifications$v24$, $v25$SELECT$v25$, '{public}'::name[], $v26$PERMISSIVE$v26$, $v27$(auth.uid() = user_id)$v27$, NULL, $v28$(( SELECT auth.uid() AS uid) = user_id)$v28$, NULL, $v29$CREATE POLICY "Users can view own notifications" ON public.notifications AS PERMISSIVE FOR SELECT TO public USING (((select auth.uid()) = user_id));$v29$, 'replace'),
  ($v30$notifications$v30$, $v31$Users delete own notifications$v31$, $v32$DELETE$v32$, '{public}'::name[], $v33$PERMISSIVE$v33$, $v34$(auth.uid() = user_id)$v34$, NULL, $v35$(( SELECT auth.uid() AS uid) = user_id)$v35$, NULL, $v36$CREATE POLICY "Users delete own notifications" ON public.notifications AS PERMISSIVE FOR DELETE TO public USING (((select auth.uid()) = user_id));$v36$, 'replace'),
  ($v37$notifications$v37$, $v38$Users update own notifications$v38$, $v39$UPDATE$v39$, '{public}'::name[], $v40$PERMISSIVE$v40$, $v41$(auth.uid() = user_id)$v41$, $v42$(auth.uid() = user_id)$v42$, $v43$(( SELECT auth.uid() AS uid) = user_id)$v43$, $v44$(( SELECT auth.uid() AS uid) = user_id)$v44$, $v45$CREATE POLICY "Users update own notifications" ON public.notifications AS PERMISSIVE FOR UPDATE TO public USING (((select auth.uid()) = user_id)) WITH CHECK (((select auth.uid()) = user_id));$v45$, 'replace'),
  ($v46$orders$v46$, $v47$Merchants can view orders for their merchant$v47$, $v48$SELECT$v48$, '{public}'::name[], $v49$PERMISSIVE$v49$, $v50$(merchant_id IN ( SELECT merchants.id
   FROM merchants
  WHERE (merchants.owner_user_id = auth.uid())))$v50$, NULL, $v51$((merchant_id IN ( SELECT merchants.id
   FROM merchants
  WHERE (merchants.owner_user_id = ( SELECT auth.uid() AS uid)))) OR _is_merchant_owner_only(merchant_id))$v51$, NULL, $v52$CREATE POLICY "Merchants can view orders for their merchant" ON public.orders AS PERMISSIVE FOR SELECT TO public USING (((merchant_id IN ( SELECT merchants.id
   FROM merchants
  WHERE (merchants.owner_user_id = (select auth.uid())))) OR _is_merchant_owner_only(merchant_id)));$v52$, 'replace'),
  ($v53$orders$v53$, $v54$Users can view own orders$v54$, $v55$SELECT$v55$, '{public}'::name[], $v56$PERMISSIVE$v56$, $v57$(auth.uid() = user_id)$v57$, NULL, $v58$(( SELECT auth.uid() AS uid) = user_id)$v58$, NULL, $v59$CREATE POLICY "Users can view own orders" ON public.orders AS PERMISSIVE FOR SELECT TO public USING (((select auth.uid()) = user_id));$v59$, 'replace'),
  ($v60$orders$v60$, $v61$orders_select_merchant_owner$v61$, $v62$SELECT$v62$, '{authenticated}'::name[], $v63$PERMISSIVE$v63$, $v64$(_is_merchant_owner_only(merchant_id) OR (user_id = auth.uid()))$v64$, NULL, NULL, NULL, NULL, 'drop'),
  ($v65$orders$v65$, $v66$orders_update_merchant_owner$v66$, $v67$UPDATE$v67$, '{authenticated}'::name[], $v68$PERMISSIVE$v68$, $v69$(_is_merchant_owner_only(merchant_id) OR (user_id = auth.uid()))$v69$, $v70$(_is_merchant_owner_only(merchant_id) OR (user_id = auth.uid()))$v70$, $v71$((user_id = ( SELECT auth.uid() AS uid)) OR _is_merchant_owner_only(merchant_id))$v71$, $v72$((user_id = ( SELECT auth.uid() AS uid)) OR _is_merchant_owner_only(merchant_id))$v72$, $v73$CREATE POLICY "orders_update_merchant_owner" ON public.orders AS PERMISSIVE FOR UPDATE TO authenticated USING (((user_id = (select auth.uid())) OR _is_merchant_owner_only(merchant_id))) WITH CHECK (((user_id = (select auth.uid())) OR _is_merchant_owner_only(merchant_id)));$v73$, 'replace');

  -- Verify phase: classify every touched policy, collect drift, mutate nothing.
  FOR r IN SELECT * FROM _g426 LOOP
    SELECT p.cmd, p.roles, p.permissive, p.qual, p.with_check INTO v
      FROM pg_policies p
     WHERE p.schemaname='public' AND p.tablename=r.tablename AND p.policyname=r.policyname;
    IF NOT FOUND THEN
      IF r.action='drop' THEN
        UPDATE _g426 SET state='noop' WHERE tablename=r.tablename AND policyname=r.policyname;
      ELSE
        v_drift := v_drift || r.tablename||'/'||r.policyname||': missing; ';
      END IF;
    ELSIF r.action='replace' AND v.cmd=r.cmd AND v.roles=r.roles AND v.permissive=r.permissive
          AND v.qual IS NOT DISTINCT FROM r.tgt_qual AND v.with_check IS NOT DISTINCT FROM r.tgt_check THEN
      UPDATE _g426 SET state='noop' WHERE tablename=r.tablename AND policyname=r.policyname;
    ELSIF v.cmd=r.cmd AND v.roles=r.roles AND v.permissive=r.permissive
          AND v.qual IS NOT DISTINCT FROM r.pre_qual AND v.with_check IS NOT DISTINCT FROM r.pre_check THEN
      UPDATE _g426 SET state='apply' WHERE tablename=r.tablename AND policyname=r.policyname;
    ELSE
      v_drift := v_drift || r.tablename||'/'||r.policyname||': drifted (cmd='||v.cmd||', roles='||v.roles::text
                 ||', permissive='||v.permissive||', qual='||coalesce(v.qual,'<null>')
                 ||', with_check='||coalesce(v.with_check,'<null>')||'); ';
    END IF;
  END LOOP;

  IF v_drift <> '' THEN
    RAISE EXCEPTION '426: policy drift detected - aborting WITHOUT mutation: %', v_drift;
  END IF;

  -- Apply phase.
  FOR r IN SELECT * FROM _g426 WHERE state='apply' LOOP
    EXECUTE format('DROP POLICY %I ON public.%I', r.policyname, r.tablename);
    IF r.action='replace' THEN
      EXECUTE r.tgt_ddl;
    END IF;
  END LOOP;

  -- Post-verify phase: every replaced policy at its exact target, every
  -- dropped policy gone.
  SELECT count(*) INTO v_bad
    FROM _g426 gr
   WHERE gr.action='replace' AND NOT EXISTS (
     SELECT 1 FROM pg_policies p
      WHERE p.schemaname='public' AND p.tablename=gr.tablename AND p.policyname=gr.policyname
        AND p.cmd=gr.cmd AND p.roles=gr.roles AND p.permissive=gr.permissive
        AND p.qual IS NOT DISTINCT FROM gr.tgt_qual AND p.with_check IS NOT DISTINCT FROM gr.tgt_check);
  IF v_bad > 0 THEN
    RAISE EXCEPTION '426: post-verify failed - % replaced policies not at target state', v_bad;
  END IF;
  SELECT count(*) INTO v_bad
    FROM _g426 gr
   WHERE gr.action='drop' AND EXISTS (
     SELECT 1 FROM pg_policies p
      WHERE p.schemaname='public' AND p.tablename=gr.tablename AND p.policyname=gr.policyname);
  IF v_bad > 0 THEN
    RAISE EXCEPTION '426: post-verify failed - % dropped policies still present', v_bad;
  END IF;
END;
$g$;

-- battery AFTER
DO $$
DECLARE
  v_r text; v_c int;
  v_custa uuid; v_mown uuid; v_leg uuid; v_adm uuid; v_stranger uuid;
  v_room uuid; v_o1 uuid;
BEGIN
  SELECT id INTO v_custa FROM _fx WHERE name='custa';
  SELECT id INTO v_mown FROM _fx WHERE name='mown';
  SELECT id INTO v_leg FROM _fx WHERE name='leg';
  SELECT id INTO v_adm FROM _fx WHERE name='adm';
  SELECT id INTO v_stranger FROM _fx WHERE name='stranger';
  SELECT id INTO v_room FROM _fx WHERE name='room';
  SELECT id INTO v_o1 FROM _fx WHERE name='o1';
  PERFORM set_config('role','authenticated',true);
  PERFORM set_config('request.jwt.claim.sub', v_custa::text, true);
  SELECT count(*) || '|' || coalesce(string_agg(id::text, ',' ORDER BY id::text), '') FROM public.orders INTO v_r;
  INSERT INTO _probe VALUES ('after','orders_select_custA', v_r);
  PERFORM set_config('request.jwt.claim.sub', v_mown::text, true);
  SELECT count(*) || '|' || coalesce(string_agg(id::text, ',' ORDER BY id::text), '') FROM public.orders INTO v_r;
  INSERT INTO _probe VALUES ('after','orders_select_mown', v_r);
  PERFORM set_config('request.jwt.claim.sub', v_leg::text, true);
  SELECT count(*) || '|' || coalesce(string_agg(id::text, ',' ORDER BY id::text), '') FROM public.orders INTO v_r;
  INSERT INTO _probe VALUES ('after','orders_select_leg', v_r);
  PERFORM set_config('request.jwt.claim.sub', v_stranger::text, true);
  SELECT count(*) || '|' || coalesce(string_agg(id::text, ',' ORDER BY id::text), '') FROM public.orders INTO v_r;
  INSERT INTO _probe VALUES ('after','orders_select_stranger', v_r);
  PERFORM set_config('request.jwt.claim.sub', v_adm::text, true);
  SELECT count(*) || '|' || coalesce(string_agg(id::text, ',' ORDER BY id::text), '') FROM public.orders INTO v_r;
  INSERT INTO _probe VALUES ('after','orders_select_adm', v_r);
  PERFORM set_config('request.jwt.claim.sub', '', true);
  SELECT count(*) || '|' || coalesce(string_agg(id::text, ',' ORDER BY id::text), '') FROM public.orders INTO v_r;
  INSERT INTO _probe VALUES ('after','orders_select_nulluid', v_r);
  PERFORM set_config('request.jwt.claim.sub', v_custa::text, true);
  SELECT count(*) || '|' || coalesce(string_agg(id::text, ',' ORDER BY id::text), '') FROM public.notifications INTO v_r;
  INSERT INTO _probe VALUES ('after','notif_select_custA', v_r);
  PERFORM set_config('request.jwt.claim.sub', v_stranger::text, true);
  SELECT count(*) || '|' || coalesce(string_agg(id::text, ',' ORDER BY id::text), '') FROM public.notifications INTO v_r;
  INSERT INTO _probe VALUES ('after','notif_select_stranger', v_r);
  PERFORM set_config('request.jwt.claim.sub', v_custa::text, true);
  SELECT count(*) FROM public.chat_messages WHERE message <> 'PROBE' INTO v_r;
  INSERT INTO _probe VALUES ('after','chat_select_custA', v_r);
  PERFORM set_config('request.jwt.claim.sub', v_mown::text, true);
  SELECT count(*) FROM public.chat_messages WHERE message <> 'PROBE' INTO v_r;
  INSERT INTO _probe VALUES ('after','chat_select_mown', v_r);
  PERFORM set_config('request.jwt.claim.sub', v_stranger::text, true);
  SELECT count(*) FROM public.chat_messages WHERE message <> 'PROBE' INTO v_r;
  INSERT INTO _probe VALUES ('after','chat_select_stranger', v_r);
  PERFORM set_config('request.jwt.claim.sub', v_custa::text, true);
  BEGIN
    INSERT INTO public.chat_messages(room_id,sender_id,message) VALUES (v_room, v_custa, 'PROBE');
    GET DIAGNOSTICS v_c = ROW_COUNT;
    v_r := 'ok:' || v_c;
  EXCEPTION WHEN OTHERS THEN
    v_r := SQLSTATE;
  END;
  INSERT INTO _probe VALUES ('after','chat_insert_custA', v_r);
  PERFORM set_config('request.jwt.claim.sub', v_stranger::text, true);
  BEGIN
    INSERT INTO public.chat_messages(room_id,sender_id,message) VALUES (v_room, v_stranger, 'PROBE');
    GET DIAGNOSTICS v_c = ROW_COUNT;
    v_r := 'ok:' || v_c;
  EXCEPTION WHEN OTHERS THEN
    v_r := SQLSTATE;
  END;
  INSERT INTO _probe VALUES ('after','chat_insert_stranger', v_r);
  PERFORM set_config('request.jwt.claim.sub', v_custa::text, true);
  BEGIN
    UPDATE public.orders SET delivery_fee = delivery_fee WHERE id = v_o1;
    GET DIAGNOSTICS v_c = ROW_COUNT;
    v_r := 'ok:' || v_c;
  EXCEPTION WHEN OTHERS THEN
    v_r := SQLSTATE;
  END;
  INSERT INTO _probe VALUES ('after','orders_update_custA', v_r);
  PERFORM set_config('request.jwt.claim.sub', v_stranger::text, true);
  BEGIN
    UPDATE public.orders SET delivery_fee = delivery_fee WHERE id = v_o1;
    GET DIAGNOSTICS v_c = ROW_COUNT;
    v_r := 'ok:' || v_c;
  EXCEPTION WHEN OTHERS THEN
    v_r := SQLSTATE;
  END;
  INSERT INTO _probe VALUES ('after','orders_update_stranger', v_r);
  PERFORM set_config('request.jwt.claim.sub', v_custa::text, true);
  BEGIN
    UPDATE public.notifications SET title = title WHERE user_id = v_custa;
    GET DIAGNOSTICS v_c = ROW_COUNT;
    v_r := 'ok:' || v_c;
  EXCEPTION WHEN OTHERS THEN
    v_r := SQLSTATE;
  END;
  INSERT INTO _probe VALUES ('after','notif_update_custA', v_r);
  PERFORM set_config('request.jwt.claim.sub', v_stranger::text, true);
  BEGIN
    UPDATE public.notifications SET title = title WHERE user_id = v_custa;
    GET DIAGNOSTICS v_c = ROW_COUNT;
    v_r := 'ok:' || v_c;
  EXCEPTION WHEN OTHERS THEN
    v_r := SQLSTATE;
  END;
  INSERT INTO _probe VALUES ('after','notif_update_stranger', v_r);
  PERFORM set_config('role','none',true);
END $$;

-- identical access: the two batteries must match exactly
DO $$
DECLARE v_n int; v_r text;
BEGIN
  SELECT count(*) INTO v_n FROM (
    (SELECT name, val FROM _probe WHERE phase='before' EXCEPT SELECT name, val FROM _probe WHERE phase='after')
    UNION ALL
    (SELECT name, val FROM _probe WHERE phase='after' EXCEPT SELECT name, val FROM _probe WHERE phase='before')
  ) d;
  ASSERT v_n = 0, '426: access changed for ' || v_n || ' probes';

  -- sanity: the battery is not vacuous
  SELECT val INTO v_r FROM _probe WHERE phase='after' AND name='orders_select_custA';
  ASSERT v_r LIKE '2|%', '426 sanity: customer does not see own 2 orders: ' || v_r;
  SELECT val INTO v_r FROM _probe WHERE phase='after' AND name='orders_select_mown';
  ASSERT v_r LIKE '2|%', '426 sanity: merchant owner does not see 2 orders: ' || v_r;
  SELECT val INTO v_r FROM _probe WHERE phase='after' AND name='orders_select_leg';
  ASSERT v_r LIKE '1|%', '426 sanity: legacy merchant lost order access: ' || v_r;
  SELECT val INTO v_r FROM _probe WHERE phase='after' AND name='orders_select_stranger';
  ASSERT v_r = '0|', '426 sanity: stranger sees orders: ' || v_r;
  SELECT val INTO v_r FROM _probe WHERE phase='after' AND name='orders_select_nulluid';
  ASSERT v_r = '0|', '426 sanity: null-uid sees orders: ' || v_r;
  SELECT val INTO v_r FROM _probe WHERE phase='after' AND name='chat_insert_stranger';
  ASSERT v_r = '42501', '426 sanity: stranger chat insert not denied: ' || v_r;
  SELECT val INTO v_r FROM _probe WHERE phase='after' AND name='chat_insert_custA';
  ASSERT v_r LIKE 'ok:%', '426 sanity: participant chat insert failed: ' || v_r;
  SELECT val INTO v_r FROM _probe WHERE phase='after' AND name='notif_select_stranger';
  ASSERT v_r LIKE '1|%', '426 sanity: stranger lost own notification';
END $$;

-- no-op path: second verbatim run must not raise and must change nothing
DO $g$
DECLARE
  r       record;
  v       record;
  v_drift text := '';
  v_bad   int;
BEGIN
  -- Expected pre/post state per touched policy (canonical pg_policies text,
  -- captured live 2026-11-23). action: 'replace' rewrites the policy,
  -- 'drop' removes it (its access is folded into the merged policy).
  DROP TABLE IF EXISTS _g426;
  CREATE TEMP TABLE _g426(
    tablename text, policyname text, cmd text, roles name[], permissive text,
    pre_qual text, pre_check text, tgt_qual text, tgt_check text,
    tgt_ddl text, action text, state text
  );
  INSERT INTO _g426(tablename,policyname,cmd,roles,permissive,pre_qual,pre_check,tgt_qual,tgt_check,tgt_ddl,action)
  VALUES
  ($v0$chat_messages$v0$, $v1$users insert own room messages$v1$, $v2$INSERT$v2$, '{public}'::name[], $v3$PERMISSIVE$v3$, NULL, $v4$((sender_id = auth.uid()) AND (EXISTS ( SELECT 1
   FROM chat_rooms
  WHERE ((chat_rooms.id = chat_messages.room_id) AND (auth.uid() = ANY (chat_rooms.participant_ids))))))$v4$, NULL, $v5$((sender_id = ( SELECT auth.uid() AS uid)) AND (EXISTS ( SELECT 1
   FROM chat_rooms
  WHERE ((chat_rooms.id = chat_messages.room_id) AND (( SELECT auth.uid() AS uid) = ANY (chat_rooms.participant_ids))))))$v5$, $v6$CREATE POLICY "users insert own room messages" ON public.chat_messages AS PERMISSIVE FOR INSERT TO public WITH CHECK (((sender_id = (select auth.uid())) AND (EXISTS ( SELECT 1
   FROM chat_rooms
  WHERE ((chat_rooms.id = chat_messages.room_id) AND ((select auth.uid()) = ANY (chat_rooms.participant_ids)))))));$v6$, 'replace'),
  ($v7$chat_messages$v7$, $v8$users select own room messages$v8$, $v9$SELECT$v9$, '{public}'::name[], $v10$PERMISSIVE$v10$, $v11$(EXISTS ( SELECT 1
   FROM chat_rooms
  WHERE ((chat_rooms.id = chat_messages.room_id) AND (auth.uid() = ANY (chat_rooms.participant_ids)))))$v11$, NULL, $v12$(EXISTS ( SELECT 1
   FROM chat_rooms
  WHERE ((chat_rooms.id = chat_messages.room_id) AND (( SELECT auth.uid() AS uid) = ANY (chat_rooms.participant_ids)))))$v12$, NULL, $v13$CREATE POLICY "users select own room messages" ON public.chat_messages AS PERMISSIVE FOR SELECT TO public USING ((EXISTS ( SELECT 1
   FROM chat_rooms
  WHERE ((chat_rooms.id = chat_messages.room_id) AND ((select auth.uid()) = ANY (chat_rooms.participant_ids))))));$v13$, 'replace'),
  ($v14$chat_messages$v14$, $v15$users update own room messages$v15$, $v16$UPDATE$v16$, '{public}'::name[], $v17$PERMISSIVE$v17$, $v18$((sender_id = auth.uid()) AND (EXISTS ( SELECT 1
   FROM chat_rooms
  WHERE ((chat_rooms.id = chat_messages.room_id) AND (auth.uid() = ANY (chat_rooms.participant_ids))))))$v18$, $v19$((sender_id = auth.uid()) AND (EXISTS ( SELECT 1
   FROM chat_rooms
  WHERE ((chat_rooms.id = chat_messages.room_id) AND (auth.uid() = ANY (chat_rooms.participant_ids))))))$v19$, $v20$((sender_id = ( SELECT auth.uid() AS uid)) AND (EXISTS ( SELECT 1
   FROM chat_rooms
  WHERE ((chat_rooms.id = chat_messages.room_id) AND (( SELECT auth.uid() AS uid) = ANY (chat_rooms.participant_ids))))))$v20$, $v21$((sender_id = ( SELECT auth.uid() AS uid)) AND (EXISTS ( SELECT 1
   FROM chat_rooms
  WHERE ((chat_rooms.id = chat_messages.room_id) AND (( SELECT auth.uid() AS uid) = ANY (chat_rooms.participant_ids))))))$v21$, $v22$CREATE POLICY "users update own room messages" ON public.chat_messages AS PERMISSIVE FOR UPDATE TO public USING (((sender_id = (select auth.uid())) AND (EXISTS ( SELECT 1
   FROM chat_rooms
  WHERE ((chat_rooms.id = chat_messages.room_id) AND ((select auth.uid()) = ANY (chat_rooms.participant_ids))))))) WITH CHECK (((sender_id = (select auth.uid())) AND (EXISTS ( SELECT 1
   FROM chat_rooms
  WHERE ((chat_rooms.id = chat_messages.room_id) AND ((select auth.uid()) = ANY (chat_rooms.participant_ids)))))));$v22$, 'replace'),
  ($v23$notifications$v23$, $v24$Users can view own notifications$v24$, $v25$SELECT$v25$, '{public}'::name[], $v26$PERMISSIVE$v26$, $v27$(auth.uid() = user_id)$v27$, NULL, $v28$(( SELECT auth.uid() AS uid) = user_id)$v28$, NULL, $v29$CREATE POLICY "Users can view own notifications" ON public.notifications AS PERMISSIVE FOR SELECT TO public USING (((select auth.uid()) = user_id));$v29$, 'replace'),
  ($v30$notifications$v30$, $v31$Users delete own notifications$v31$, $v32$DELETE$v32$, '{public}'::name[], $v33$PERMISSIVE$v33$, $v34$(auth.uid() = user_id)$v34$, NULL, $v35$(( SELECT auth.uid() AS uid) = user_id)$v35$, NULL, $v36$CREATE POLICY "Users delete own notifications" ON public.notifications AS PERMISSIVE FOR DELETE TO public USING (((select auth.uid()) = user_id));$v36$, 'replace'),
  ($v37$notifications$v37$, $v38$Users update own notifications$v38$, $v39$UPDATE$v39$, '{public}'::name[], $v40$PERMISSIVE$v40$, $v41$(auth.uid() = user_id)$v41$, $v42$(auth.uid() = user_id)$v42$, $v43$(( SELECT auth.uid() AS uid) = user_id)$v43$, $v44$(( SELECT auth.uid() AS uid) = user_id)$v44$, $v45$CREATE POLICY "Users update own notifications" ON public.notifications AS PERMISSIVE FOR UPDATE TO public USING (((select auth.uid()) = user_id)) WITH CHECK (((select auth.uid()) = user_id));$v45$, 'replace'),
  ($v46$orders$v46$, $v47$Merchants can view orders for their merchant$v47$, $v48$SELECT$v48$, '{public}'::name[], $v49$PERMISSIVE$v49$, $v50$(merchant_id IN ( SELECT merchants.id
   FROM merchants
  WHERE (merchants.owner_user_id = auth.uid())))$v50$, NULL, $v51$((merchant_id IN ( SELECT merchants.id
   FROM merchants
  WHERE (merchants.owner_user_id = ( SELECT auth.uid() AS uid)))) OR _is_merchant_owner_only(merchant_id))$v51$, NULL, $v52$CREATE POLICY "Merchants can view orders for their merchant" ON public.orders AS PERMISSIVE FOR SELECT TO public USING (((merchant_id IN ( SELECT merchants.id
   FROM merchants
  WHERE (merchants.owner_user_id = (select auth.uid())))) OR _is_merchant_owner_only(merchant_id)));$v52$, 'replace'),
  ($v53$orders$v53$, $v54$Users can view own orders$v54$, $v55$SELECT$v55$, '{public}'::name[], $v56$PERMISSIVE$v56$, $v57$(auth.uid() = user_id)$v57$, NULL, $v58$(( SELECT auth.uid() AS uid) = user_id)$v58$, NULL, $v59$CREATE POLICY "Users can view own orders" ON public.orders AS PERMISSIVE FOR SELECT TO public USING (((select auth.uid()) = user_id));$v59$, 'replace'),
  ($v60$orders$v60$, $v61$orders_select_merchant_owner$v61$, $v62$SELECT$v62$, '{authenticated}'::name[], $v63$PERMISSIVE$v63$, $v64$(_is_merchant_owner_only(merchant_id) OR (user_id = auth.uid()))$v64$, NULL, NULL, NULL, NULL, 'drop'),
  ($v65$orders$v65$, $v66$orders_update_merchant_owner$v66$, $v67$UPDATE$v67$, '{authenticated}'::name[], $v68$PERMISSIVE$v68$, $v69$(_is_merchant_owner_only(merchant_id) OR (user_id = auth.uid()))$v69$, $v70$(_is_merchant_owner_only(merchant_id) OR (user_id = auth.uid()))$v70$, $v71$((user_id = ( SELECT auth.uid() AS uid)) OR _is_merchant_owner_only(merchant_id))$v71$, $v72$((user_id = ( SELECT auth.uid() AS uid)) OR _is_merchant_owner_only(merchant_id))$v72$, $v73$CREATE POLICY "orders_update_merchant_owner" ON public.orders AS PERMISSIVE FOR UPDATE TO authenticated USING (((user_id = (select auth.uid())) OR _is_merchant_owner_only(merchant_id))) WITH CHECK (((user_id = (select auth.uid())) OR _is_merchant_owner_only(merchant_id)));$v73$, 'replace');

  -- Verify phase: classify every touched policy, collect drift, mutate nothing.
  FOR r IN SELECT * FROM _g426 LOOP
    SELECT p.cmd, p.roles, p.permissive, p.qual, p.with_check INTO v
      FROM pg_policies p
     WHERE p.schemaname='public' AND p.tablename=r.tablename AND p.policyname=r.policyname;
    IF NOT FOUND THEN
      IF r.action='drop' THEN
        UPDATE _g426 SET state='noop' WHERE tablename=r.tablename AND policyname=r.policyname;
      ELSE
        v_drift := v_drift || r.tablename||'/'||r.policyname||': missing; ';
      END IF;
    ELSIF r.action='replace' AND v.cmd=r.cmd AND v.roles=r.roles AND v.permissive=r.permissive
          AND v.qual IS NOT DISTINCT FROM r.tgt_qual AND v.with_check IS NOT DISTINCT FROM r.tgt_check THEN
      UPDATE _g426 SET state='noop' WHERE tablename=r.tablename AND policyname=r.policyname;
    ELSIF v.cmd=r.cmd AND v.roles=r.roles AND v.permissive=r.permissive
          AND v.qual IS NOT DISTINCT FROM r.pre_qual AND v.with_check IS NOT DISTINCT FROM r.pre_check THEN
      UPDATE _g426 SET state='apply' WHERE tablename=r.tablename AND policyname=r.policyname;
    ELSE
      v_drift := v_drift || r.tablename||'/'||r.policyname||': drifted (cmd='||v.cmd||', roles='||v.roles::text
                 ||', permissive='||v.permissive||', qual='||coalesce(v.qual,'<null>')
                 ||', with_check='||coalesce(v.with_check,'<null>')||'); ';
    END IF;
  END LOOP;

  IF v_drift <> '' THEN
    RAISE EXCEPTION '426: policy drift detected - aborting WITHOUT mutation: %', v_drift;
  END IF;

  -- Apply phase.
  FOR r IN SELECT * FROM _g426 WHERE state='apply' LOOP
    EXECUTE format('DROP POLICY %I ON public.%I', r.policyname, r.tablename);
    IF r.action='replace' THEN
      EXECUTE r.tgt_ddl;
    END IF;
  END LOOP;

  -- Post-verify phase: every replaced policy at its exact target, every
  -- dropped policy gone.
  SELECT count(*) INTO v_bad
    FROM _g426 gr
   WHERE gr.action='replace' AND NOT EXISTS (
     SELECT 1 FROM pg_policies p
      WHERE p.schemaname='public' AND p.tablename=gr.tablename AND p.policyname=gr.policyname
        AND p.cmd=gr.cmd AND p.roles=gr.roles AND p.permissive=gr.permissive
        AND p.qual IS NOT DISTINCT FROM gr.tgt_qual AND p.with_check IS NOT DISTINCT FROM gr.tgt_check);
  IF v_bad > 0 THEN
    RAISE EXCEPTION '426: post-verify failed - % replaced policies not at target state', v_bad;
  END IF;
  SELECT count(*) INTO v_bad
    FROM _g426 gr
   WHERE gr.action='drop' AND EXISTS (
     SELECT 1 FROM pg_policies p
      WHERE p.schemaname='public' AND p.tablename=gr.tablename AND p.policyname=gr.policyname);
  IF v_bad > 0 THEN
    RAISE EXCEPTION '426: post-verify failed - % dropped policies still present', v_bad;
  END IF;
END;
$g$;

-- drift path: one policy off its expected state aborts the whole guard
-- BEFORE any mutation; the policy surface is unchanged afterwards.
DO $t$
DECLARE
  v_msg text;
  v_before text;
  v_after text;
BEGIN
  EXECUTE 'DROP POLICY "Users can view own orders" ON public.orders';
  EXECUTE 'CREATE POLICY "Users can view own orders" ON public.orders AS PERMISSIVE FOR SELECT TO public USING (((select auth.uid()) = user_id) AND (total_amount >= 0))';
  SELECT jsonb_agg(x ORDER BY x.tablename, x.policyname)::text INTO v_before
    FROM (SELECT tablename, policyname, permissive, roles, cmd, qual, with_check
            FROM pg_policies WHERE schemaname='public'
              AND tablename IN ('orders','notifications','chat_messages')) x;
  BEGIN
    DECLARE
      r       record;
      v       record;
      v_drift text := '';
      v_bad   int;
    BEGIN
      -- Expected pre/post state per touched policy (canonical pg_policies text,
      -- captured live 2026-11-23). action: 'replace' rewrites the policy,
      -- 'drop' removes it (its access is folded into the merged policy).
      DROP TABLE IF EXISTS _g426;
      CREATE TEMP TABLE _g426(
        tablename text, policyname text, cmd text, roles name[], permissive text,
        pre_qual text, pre_check text, tgt_qual text, tgt_check text,
        tgt_ddl text, action text, state text
      );
      INSERT INTO _g426(tablename,policyname,cmd,roles,permissive,pre_qual,pre_check,tgt_qual,tgt_check,tgt_ddl,action)
      VALUES
      ($v0$chat_messages$v0$, $v1$users insert own room messages$v1$, $v2$INSERT$v2$, '{public}'::name[], $v3$PERMISSIVE$v3$, NULL, $v4$((sender_id = auth.uid()) AND (EXISTS ( SELECT 1
       FROM chat_rooms
      WHERE ((chat_rooms.id = chat_messages.room_id) AND (auth.uid() = ANY (chat_rooms.participant_ids))))))$v4$, NULL, $v5$((sender_id = ( SELECT auth.uid() AS uid)) AND (EXISTS ( SELECT 1
       FROM chat_rooms
      WHERE ((chat_rooms.id = chat_messages.room_id) AND (( SELECT auth.uid() AS uid) = ANY (chat_rooms.participant_ids))))))$v5$, $v6$CREATE POLICY "users insert own room messages" ON public.chat_messages AS PERMISSIVE FOR INSERT TO public WITH CHECK (((sender_id = (select auth.uid())) AND (EXISTS ( SELECT 1
       FROM chat_rooms
      WHERE ((chat_rooms.id = chat_messages.room_id) AND ((select auth.uid()) = ANY (chat_rooms.participant_ids)))))));$v6$, 'replace'),
      ($v7$chat_messages$v7$, $v8$users select own room messages$v8$, $v9$SELECT$v9$, '{public}'::name[], $v10$PERMISSIVE$v10$, $v11$(EXISTS ( SELECT 1
       FROM chat_rooms
      WHERE ((chat_rooms.id = chat_messages.room_id) AND (auth.uid() = ANY (chat_rooms.participant_ids)))))$v11$, NULL, $v12$(EXISTS ( SELECT 1
       FROM chat_rooms
      WHERE ((chat_rooms.id = chat_messages.room_id) AND (( SELECT auth.uid() AS uid) = ANY (chat_rooms.participant_ids)))))$v12$, NULL, $v13$CREATE POLICY "users select own room messages" ON public.chat_messages AS PERMISSIVE FOR SELECT TO public USING ((EXISTS ( SELECT 1
       FROM chat_rooms
      WHERE ((chat_rooms.id = chat_messages.room_id) AND ((select auth.uid()) = ANY (chat_rooms.participant_ids))))));$v13$, 'replace'),
      ($v14$chat_messages$v14$, $v15$users update own room messages$v15$, $v16$UPDATE$v16$, '{public}'::name[], $v17$PERMISSIVE$v17$, $v18$((sender_id = auth.uid()) AND (EXISTS ( SELECT 1
       FROM chat_rooms
      WHERE ((chat_rooms.id = chat_messages.room_id) AND (auth.uid() = ANY (chat_rooms.participant_ids))))))$v18$, $v19$((sender_id = auth.uid()) AND (EXISTS ( SELECT 1
       FROM chat_rooms
      WHERE ((chat_rooms.id = chat_messages.room_id) AND (auth.uid() = ANY (chat_rooms.participant_ids))))))$v19$, $v20$((sender_id = ( SELECT auth.uid() AS uid)) AND (EXISTS ( SELECT 1
       FROM chat_rooms
      WHERE ((chat_rooms.id = chat_messages.room_id) AND (( SELECT auth.uid() AS uid) = ANY (chat_rooms.participant_ids))))))$v20$, $v21$((sender_id = ( SELECT auth.uid() AS uid)) AND (EXISTS ( SELECT 1
       FROM chat_rooms
      WHERE ((chat_rooms.id = chat_messages.room_id) AND (( SELECT auth.uid() AS uid) = ANY (chat_rooms.participant_ids))))))$v21$, $v22$CREATE POLICY "users update own room messages" ON public.chat_messages AS PERMISSIVE FOR UPDATE TO public USING (((sender_id = (select auth.uid())) AND (EXISTS ( SELECT 1
       FROM chat_rooms
      WHERE ((chat_rooms.id = chat_messages.room_id) AND ((select auth.uid()) = ANY (chat_rooms.participant_ids))))))) WITH CHECK (((sender_id = (select auth.uid())) AND (EXISTS ( SELECT 1
       FROM chat_rooms
      WHERE ((chat_rooms.id = chat_messages.room_id) AND ((select auth.uid()) = ANY (chat_rooms.participant_ids)))))));$v22$, 'replace'),
      ($v23$notifications$v23$, $v24$Users can view own notifications$v24$, $v25$SELECT$v25$, '{public}'::name[], $v26$PERMISSIVE$v26$, $v27$(auth.uid() = user_id)$v27$, NULL, $v28$(( SELECT auth.uid() AS uid) = user_id)$v28$, NULL, $v29$CREATE POLICY "Users can view own notifications" ON public.notifications AS PERMISSIVE FOR SELECT TO public USING (((select auth.uid()) = user_id));$v29$, 'replace'),
      ($v30$notifications$v30$, $v31$Users delete own notifications$v31$, $v32$DELETE$v32$, '{public}'::name[], $v33$PERMISSIVE$v33$, $v34$(auth.uid() = user_id)$v34$, NULL, $v35$(( SELECT auth.uid() AS uid) = user_id)$v35$, NULL, $v36$CREATE POLICY "Users delete own notifications" ON public.notifications AS PERMISSIVE FOR DELETE TO public USING (((select auth.uid()) = user_id));$v36$, 'replace'),
      ($v37$notifications$v37$, $v38$Users update own notifications$v38$, $v39$UPDATE$v39$, '{public}'::name[], $v40$PERMISSIVE$v40$, $v41$(auth.uid() = user_id)$v41$, $v42$(auth.uid() = user_id)$v42$, $v43$(( SELECT auth.uid() AS uid) = user_id)$v43$, $v44$(( SELECT auth.uid() AS uid) = user_id)$v44$, $v45$CREATE POLICY "Users update own notifications" ON public.notifications AS PERMISSIVE FOR UPDATE TO public USING (((select auth.uid()) = user_id)) WITH CHECK (((select auth.uid()) = user_id));$v45$, 'replace'),
      ($v46$orders$v46$, $v47$Merchants can view orders for their merchant$v47$, $v48$SELECT$v48$, '{public}'::name[], $v49$PERMISSIVE$v49$, $v50$(merchant_id IN ( SELECT merchants.id
       FROM merchants
      WHERE (merchants.owner_user_id = auth.uid())))$v50$, NULL, $v51$((merchant_id IN ( SELECT merchants.id
       FROM merchants
      WHERE (merchants.owner_user_id = ( SELECT auth.uid() AS uid)))) OR _is_merchant_owner_only(merchant_id))$v51$, NULL, $v52$CREATE POLICY "Merchants can view orders for their merchant" ON public.orders AS PERMISSIVE FOR SELECT TO public USING (((merchant_id IN ( SELECT merchants.id
       FROM merchants
      WHERE (merchants.owner_user_id = (select auth.uid())))) OR _is_merchant_owner_only(merchant_id)));$v52$, 'replace'),
      ($v53$orders$v53$, $v54$Users can view own orders$v54$, $v55$SELECT$v55$, '{public}'::name[], $v56$PERMISSIVE$v56$, $v57$(auth.uid() = user_id)$v57$, NULL, $v58$(( SELECT auth.uid() AS uid) = user_id)$v58$, NULL, $v59$CREATE POLICY "Users can view own orders" ON public.orders AS PERMISSIVE FOR SELECT TO public USING (((select auth.uid()) = user_id));$v59$, 'replace'),
      ($v60$orders$v60$, $v61$orders_select_merchant_owner$v61$, $v62$SELECT$v62$, '{authenticated}'::name[], $v63$PERMISSIVE$v63$, $v64$(_is_merchant_owner_only(merchant_id) OR (user_id = auth.uid()))$v64$, NULL, NULL, NULL, NULL, 'drop'),
      ($v65$orders$v65$, $v66$orders_update_merchant_owner$v66$, $v67$UPDATE$v67$, '{authenticated}'::name[], $v68$PERMISSIVE$v68$, $v69$(_is_merchant_owner_only(merchant_id) OR (user_id = auth.uid()))$v69$, $v70$(_is_merchant_owner_only(merchant_id) OR (user_id = auth.uid()))$v70$, $v71$((user_id = ( SELECT auth.uid() AS uid)) OR _is_merchant_owner_only(merchant_id))$v71$, $v72$((user_id = ( SELECT auth.uid() AS uid)) OR _is_merchant_owner_only(merchant_id))$v72$, $v73$CREATE POLICY "orders_update_merchant_owner" ON public.orders AS PERMISSIVE FOR UPDATE TO authenticated USING (((user_id = (select auth.uid())) OR _is_merchant_owner_only(merchant_id))) WITH CHECK (((user_id = (select auth.uid())) OR _is_merchant_owner_only(merchant_id)));$v73$, 'replace');
    
      -- Verify phase: classify every touched policy, collect drift, mutate nothing.
      FOR r IN SELECT * FROM _g426 LOOP
        SELECT p.cmd, p.roles, p.permissive, p.qual, p.with_check INTO v
          FROM pg_policies p
         WHERE p.schemaname='public' AND p.tablename=r.tablename AND p.policyname=r.policyname;
        IF NOT FOUND THEN
          IF r.action='drop' THEN
            UPDATE _g426 SET state='noop' WHERE tablename=r.tablename AND policyname=r.policyname;
          ELSE
            v_drift := v_drift || r.tablename||'/'||r.policyname||': missing; ';
          END IF;
        ELSIF r.action='replace' AND v.cmd=r.cmd AND v.roles=r.roles AND v.permissive=r.permissive
              AND v.qual IS NOT DISTINCT FROM r.tgt_qual AND v.with_check IS NOT DISTINCT FROM r.tgt_check THEN
          UPDATE _g426 SET state='noop' WHERE tablename=r.tablename AND policyname=r.policyname;
        ELSIF v.cmd=r.cmd AND v.roles=r.roles AND v.permissive=r.permissive
              AND v.qual IS NOT DISTINCT FROM r.pre_qual AND v.with_check IS NOT DISTINCT FROM r.pre_check THEN
          UPDATE _g426 SET state='apply' WHERE tablename=r.tablename AND policyname=r.policyname;
        ELSE
          v_drift := v_drift || r.tablename||'/'||r.policyname||': drifted (cmd='||v.cmd||', roles='||v.roles::text
                     ||', permissive='||v.permissive||', qual='||coalesce(v.qual,'<null>')
                     ||', with_check='||coalesce(v.with_check,'<null>')||'); ';
        END IF;
      END LOOP;
    
      IF v_drift <> '' THEN
        RAISE EXCEPTION '426: policy drift detected - aborting WITHOUT mutation: %', v_drift;
      END IF;
    
      -- Apply phase.
      FOR r IN SELECT * FROM _g426 WHERE state='apply' LOOP
        EXECUTE format('DROP POLICY %I ON public.%I', r.policyname, r.tablename);
        IF r.action='replace' THEN
          EXECUTE r.tgt_ddl;
        END IF;
      END LOOP;
    
      -- Post-verify phase: every replaced policy at its exact target, every
      -- dropped policy gone.
      SELECT count(*) INTO v_bad
        FROM _g426 gr
       WHERE gr.action='replace' AND NOT EXISTS (
         SELECT 1 FROM pg_policies p
          WHERE p.schemaname='public' AND p.tablename=gr.tablename AND p.policyname=gr.policyname
            AND p.cmd=gr.cmd AND p.roles=gr.roles AND p.permissive=gr.permissive
            AND p.qual IS NOT DISTINCT FROM gr.tgt_qual AND p.with_check IS NOT DISTINCT FROM gr.tgt_check);
      IF v_bad > 0 THEN
        RAISE EXCEPTION '426: post-verify failed - % replaced policies not at target state', v_bad;
      END IF;
      SELECT count(*) INTO v_bad
        FROM _g426 gr
       WHERE gr.action='drop' AND EXISTS (
         SELECT 1 FROM pg_policies p
          WHERE p.schemaname='public' AND p.tablename=gr.tablename AND p.policyname=gr.policyname);
      IF v_bad > 0 THEN
        RAISE EXCEPTION '426: post-verify failed - % dropped policies still present', v_bad;
      END IF;
    END;
  EXCEPTION WHEN raise_exception THEN
    GET STACKED DIAGNOSTICS v_msg = MESSAGE_TEXT;
  END;
  ASSERT v_msg LIKE '426: policy drift detected%',
    '426: drifted policy did not abort the guard: ' || coalesce(v_msg, '<no exception>');
  SELECT jsonb_agg(x ORDER BY x.tablename, x.policyname)::text INTO v_after
    FROM (SELECT tablename, policyname, permissive, roles, cmd, qual, with_check
            FROM pg_policies WHERE schemaname='public'
              AND tablename IN ('orders','notifications','chat_messages')) x;
  ASSERT v_after = v_before, '426: guard mutated the policy surface after drift abort';
END $t$;

ROLLBACK;
