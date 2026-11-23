-- 426: RLS cost reduction on orders, notifications, chat_messages
-- (load-team item 5, 2026-11-23). Three changes, zero access change:
--
-- 1. auth.uid() -> (select auth.uid()) in every policy predicate on these
--    tables, so the claim is planned once per query (initplan) instead of
--    per row.
-- 2. Merge the two duplicate merchant-read SELECT policies on orders:
--    "orders_select_merchant_owner" is dropped; its extra branch
--    (_is_merchant_owner_only(merchant_id), which also covers the legacy
--    merchants.id = auth.uid() pattern) is folded into "Merchants can view
--    orders for their merchant". Its other branch (user_id = auth.uid())
--    is already granted by "Users can view own orders", so the union of
--    granted rows is unchanged for every role, including anon.
-- 3. Cheap conditions first: orders_update_merchant_owner evaluates the
--    scalar user_id check before the SECURITY DEFINER call.
--
-- Admin policies (admin_has_permission / _admin_write_scope /
-- _admin_member_scope) contain no auth.uid() and are untouched, as are all
-- ACLs. Convergent: prod and staging share this policy surface.
--
-- Guard: one DO block. Every touched policy is classified against exact
-- canonical pre-state (qual, with_check, cmd, roles, permissive):
-- already at target -> no-op; exact pre-state -> apply; anything else ->
-- abort BEFORE any mutation with the actual state in the message.
-- A post-verify phase then asserts every target state and the drop.
-- The guard body below is copied VERBATIM into
-- supabase/tests/426_rls_wrap_merge_test.sql, which proves the apply path,
-- the no-op path, drift-abort-without-mutation, and identical access
-- (before/after probe battery over real roles, including a legacy
-- merchants.id = auth.uid() merchant and a stranger).

BEGIN;

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

COMMIT;
