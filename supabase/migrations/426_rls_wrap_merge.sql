-- 426 v2: RLS cost reduction on orders, notifications, chat_messages
-- (load-team item 5, 2026-11-23; v2 per review #135). Zero access change:
--
-- 1. auth.uid() -> (select auth.uid()) in every touched policy predicate,
--    so the claim is planned once per query (initplan) instead of per row.
-- 2. Duplicate merchant-read dedupe on orders: orders_select_merchant_owner
--    keeps ONLY its unique branch (_is_merchant_owner_only(merchant_id),
--    which also covers the legacy merchants.id = auth.uid() pattern) and
--    stays TO authenticated - the helper is not executable by anon, so the
--    branch must never sit in a TO public policy. Its user_id branch is
--    dropped: "Users can view own orders" (TO public) already grants it.
-- 3. Cheap conditions first: orders_update_merchant_owner evaluates the
--    scalar user_id check before the SECURITY DEFINER call.
--
-- Admin policies (admin_has_permission / _admin_write_scope /
-- _admin_member_scope) contain no auth.uid() and are untouched, as are all
-- ACLs. Convergent: prod and staging share this policy surface.
--
-- Guard: one DO block over pg_temp._g426 (ON COMMIT DROP). Every touched
-- policy is classified against exact canonical state (qual, with_check,
-- cmd, roles, permissive): all at pre-state -> apply; all at target ->
-- no-op; any drift, any missing policy, or a mixed/hybrid state -> abort
-- BEFORE any mutation with the actual state in the message. A post-verify
-- phase asserts every target state. The guard body below is copied
-- VERBATIM into supabase/tests/426_rls_wrap_merge_test.sql.

BEGIN;

DO $g$
DECLARE
  r       record;
  v       record;
  v_drift text := '';
  v_bad   int;
BEGIN
  -- Expected pre/post state per touched policy (canonical pg_policies text,
  -- captured live 2026-11-23).
  DROP TABLE IF EXISTS pg_temp._g426;
  CREATE TEMP TABLE pg_temp._g426(
    tablename text, policyname text, cmd text, roles name[], permissive text,
    pre_qual text, pre_check text, tgt_qual text, tgt_check text,
    tgt_ddl text, state text
  ) ON COMMIT DROP;
  INSERT INTO pg_temp._g426(tablename,policyname,cmd,roles,permissive,pre_qual,pre_check,tgt_qual,tgt_check,tgt_ddl)
  VALUES
  ($v0$chat_messages$v0$, $v1$users insert own room messages$v1$, $v2$INSERT$v2$, '{public}'::name[], $v3$PERMISSIVE$v3$, NULL, $v4$((sender_id = auth.uid()) AND (EXISTS ( SELECT 1
   FROM chat_rooms
  WHERE ((chat_rooms.id = chat_messages.room_id) AND (auth.uid() = ANY (chat_rooms.participant_ids))))))$v4$, NULL, $v5$((sender_id = ( SELECT auth.uid() AS uid)) AND (EXISTS ( SELECT 1
   FROM chat_rooms
  WHERE ((chat_rooms.id = chat_messages.room_id) AND (( SELECT auth.uid() AS uid) = ANY (chat_rooms.participant_ids))))))$v5$, $v6$CREATE POLICY "users insert own room messages" ON public.chat_messages AS PERMISSIVE FOR INSERT TO public WITH CHECK (((sender_id = (select auth.uid())) AND (EXISTS ( SELECT 1
   FROM chat_rooms
  WHERE ((chat_rooms.id = chat_messages.room_id) AND ((select auth.uid()) = ANY (chat_rooms.participant_ids)))))));$v6$),
  ($v7$chat_messages$v7$, $v8$users select own room messages$v8$, $v9$SELECT$v9$, '{public}'::name[], $v10$PERMISSIVE$v10$, $v11$(EXISTS ( SELECT 1
   FROM chat_rooms
  WHERE ((chat_rooms.id = chat_messages.room_id) AND (auth.uid() = ANY (chat_rooms.participant_ids)))))$v11$, NULL, $v12$(EXISTS ( SELECT 1
   FROM chat_rooms
  WHERE ((chat_rooms.id = chat_messages.room_id) AND (( SELECT auth.uid() AS uid) = ANY (chat_rooms.participant_ids)))))$v12$, NULL, $v13$CREATE POLICY "users select own room messages" ON public.chat_messages AS PERMISSIVE FOR SELECT TO public USING ((EXISTS ( SELECT 1
   FROM chat_rooms
  WHERE ((chat_rooms.id = chat_messages.room_id) AND ((select auth.uid()) = ANY (chat_rooms.participant_ids))))));$v13$),
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
  WHERE ((chat_rooms.id = chat_messages.room_id) AND ((select auth.uid()) = ANY (chat_rooms.participant_ids)))))));$v22$),
  ($v23$notifications$v23$, $v24$Users can view own notifications$v24$, $v25$SELECT$v25$, '{public}'::name[], $v26$PERMISSIVE$v26$, $v27$(auth.uid() = user_id)$v27$, NULL, $v28$(( SELECT auth.uid() AS uid) = user_id)$v28$, NULL, $v29$CREATE POLICY "Users can view own notifications" ON public.notifications AS PERMISSIVE FOR SELECT TO public USING (((select auth.uid()) = user_id));$v29$),
  ($v30$notifications$v30$, $v31$Users delete own notifications$v31$, $v32$DELETE$v32$, '{public}'::name[], $v33$PERMISSIVE$v33$, $v34$(auth.uid() = user_id)$v34$, NULL, $v35$(( SELECT auth.uid() AS uid) = user_id)$v35$, NULL, $v36$CREATE POLICY "Users delete own notifications" ON public.notifications AS PERMISSIVE FOR DELETE TO public USING (((select auth.uid()) = user_id));$v36$),
  ($v37$notifications$v37$, $v38$Users update own notifications$v38$, $v39$UPDATE$v39$, '{public}'::name[], $v40$PERMISSIVE$v40$, $v41$(auth.uid() = user_id)$v41$, $v42$(auth.uid() = user_id)$v42$, $v43$(( SELECT auth.uid() AS uid) = user_id)$v43$, $v44$(( SELECT auth.uid() AS uid) = user_id)$v44$, $v45$CREATE POLICY "Users update own notifications" ON public.notifications AS PERMISSIVE FOR UPDATE TO public USING (((select auth.uid()) = user_id)) WITH CHECK (((select auth.uid()) = user_id));$v45$),
  ($v46$orders$v46$, $v47$Merchants can view orders for their merchant$v47$, $v48$SELECT$v48$, '{public}'::name[], $v49$PERMISSIVE$v49$, $v50$(merchant_id IN ( SELECT merchants.id
   FROM merchants
  WHERE (merchants.owner_user_id = auth.uid())))$v50$, NULL, $v51$(merchant_id IN ( SELECT merchants.id
   FROM merchants
  WHERE (merchants.owner_user_id = ( SELECT auth.uid() AS uid))))$v51$, NULL, $v52$CREATE POLICY "Merchants can view orders for their merchant" ON public.orders AS PERMISSIVE FOR SELECT TO public USING ((merchant_id IN ( SELECT merchants.id
   FROM merchants
  WHERE (merchants.owner_user_id = (select auth.uid())))));$v52$),
  ($v53$orders$v53$, $v54$Users can view own orders$v54$, $v55$SELECT$v55$, '{public}'::name[], $v56$PERMISSIVE$v56$, $v57$(auth.uid() = user_id)$v57$, NULL, $v58$(( SELECT auth.uid() AS uid) = user_id)$v58$, NULL, $v59$CREATE POLICY "Users can view own orders" ON public.orders AS PERMISSIVE FOR SELECT TO public USING (((select auth.uid()) = user_id));$v59$),
  ($v60$orders$v60$, $v61$orders_select_merchant_owner$v61$, $v62$SELECT$v62$, '{authenticated}'::name[], $v63$PERMISSIVE$v63$, $v64$(_is_merchant_owner_only(merchant_id) OR (user_id = auth.uid()))$v64$, NULL, $v65$_is_merchant_owner_only(merchant_id)$v65$, NULL, $v66$CREATE POLICY "orders_select_merchant_owner" ON public.orders AS PERMISSIVE FOR SELECT TO authenticated USING (_is_merchant_owner_only(merchant_id));$v66$),
  ($v67$orders$v67$, $v68$orders_update_merchant_owner$v68$, $v69$UPDATE$v69$, '{authenticated}'::name[], $v70$PERMISSIVE$v70$, $v71$(_is_merchant_owner_only(merchant_id) OR (user_id = auth.uid()))$v71$, $v72$(_is_merchant_owner_only(merchant_id) OR (user_id = auth.uid()))$v72$, $v73$((user_id = ( SELECT auth.uid() AS uid)) OR _is_merchant_owner_only(merchant_id))$v73$, $v74$((user_id = ( SELECT auth.uid() AS uid)) OR _is_merchant_owner_only(merchant_id))$v74$, $v75$CREATE POLICY "orders_update_merchant_owner" ON public.orders AS PERMISSIVE FOR UPDATE TO authenticated USING (((user_id = (select auth.uid())) OR _is_merchant_owner_only(merchant_id))) WITH CHECK (((user_id = (select auth.uid())) OR _is_merchant_owner_only(merchant_id)));$v75$);

  -- Verify phase: classify every touched policy, collect drift, mutate nothing.
  FOR r IN SELECT * FROM pg_temp._g426 LOOP
    SELECT p.cmd, p.roles, p.permissive, p.qual, p.with_check INTO v
      FROM pg_policies p
     WHERE p.schemaname='public' AND p.tablename=r.tablename AND p.policyname=r.policyname;
    IF NOT FOUND THEN
      v_drift := v_drift || r.tablename||'/'||r.policyname||': missing; ';
    ELSIF v.cmd=r.cmd AND v.roles=r.roles AND v.permissive=r.permissive
          AND v.qual IS NOT DISTINCT FROM r.tgt_qual AND v.with_check IS NOT DISTINCT FROM r.tgt_check THEN
      UPDATE pg_temp._g426 SET state='noop' WHERE tablename=r.tablename AND policyname=r.policyname;
    ELSIF v.cmd=r.cmd AND v.roles=r.roles AND v.permissive=r.permissive
          AND v.qual IS NOT DISTINCT FROM r.pre_qual AND v.with_check IS NOT DISTINCT FROM r.pre_check THEN
      UPDATE pg_temp._g426 SET state='apply' WHERE tablename=r.tablename AND policyname=r.policyname;
    ELSE
      v_drift := v_drift || r.tablename||'/'||r.policyname||': drifted (cmd='||v.cmd||', roles='||v.roles::text
                 ||', permissive='||v.permissive||', qual='||coalesce(v.qual,'<null>')
                 ||', with_check='||coalesce(v.with_check,'<null>')||'); ';
    END IF;
  END LOOP;

  IF v_drift <> '' THEN
    RAISE EXCEPTION '426: policy drift detected - aborting WITHOUT mutation: %', v_drift;
  END IF;

  -- Hybrid check: the only legitimate states are all-pre (apply) or
  -- all-target (no-op). A mixture means a partial apply or manual edits.
  IF EXISTS (SELECT 1 FROM pg_temp._g426 WHERE state='apply')
     AND EXISTS (SELECT 1 FROM pg_temp._g426 WHERE state='noop') THEN
    RAISE EXCEPTION '426: unknown hybrid state (some policies at pre-state, some at target) - aborting WITHOUT mutation';
  END IF;

  -- Apply phase.
  FOR r IN SELECT * FROM pg_temp._g426 WHERE state='apply' LOOP
    EXECUTE format('DROP POLICY %I ON public.%I', r.policyname, r.tablename);
    EXECUTE r.tgt_ddl;
  END LOOP;

  -- Post-verify phase: every policy at its exact target.
  SELECT count(*) INTO v_bad
    FROM pg_temp._g426 gr
   WHERE NOT EXISTS (
     SELECT 1 FROM pg_policies p
      WHERE p.schemaname='public' AND p.tablename=gr.tablename AND p.policyname=gr.policyname
        AND p.cmd=gr.cmd AND p.roles=gr.roles AND p.permissive=gr.permissive
        AND p.qual IS NOT DISTINCT FROM gr.tgt_qual AND p.with_check IS NOT DISTINCT FROM gr.tgt_check);
  IF v_bad > 0 THEN
    RAISE EXCEPTION '426: post-verify failed - % policies not at target state', v_bad;
  END IF;
END;
$g$;

COMMIT;
