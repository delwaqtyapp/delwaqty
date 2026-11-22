-- 367: admin policy sweep stage 2 - close every remaining bare
-- is_admin()/_is_active_admin_uid policy branch (61 policies, 45 tables).
-- Platform-global admin/audit/config tables -> _is_country_admin_uid.
-- Region-scoped admin tables -> is_admin_for_region/_admin_write_scope.
-- Member/merchant-scoped reads -> _admin_member_scope / merchant-region
-- scope; bare passthroughs dropped where is_merchant_owner already admits
-- scoped admins (361). Campaign gate function hardened so unassigned admins
-- no longer pass campaign management on zero-target campaigns.
BEGIN;

-- Harden the campaign gate: is_admin() -> owner OR active admin (region
-- coverage is already enforced per target via campaign_can_target_region).
CREATE OR REPLACE FUNCTION public.campaign_targets_authorized(p_campaign_id uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT (public._is_owner_uid(auth.uid()) OR public._is_active_admin_uid(auth.uid()))
    AND NOT EXISTS (
      SELECT 1 FROM public.campaign_targets t
      WHERE t.campaign_id = p_campaign_id
        AND NOT public.campaign_can_target_region(t.region_id)
    );
$function$;

ALTER POLICY "activity_logs admin select" ON public.activity_logs USING (public._is_country_admin_uid(auth.uid()));
ALTER POLICY "activity_logs_archive_admin_select" ON public.activity_logs_archive USING (public._is_country_admin_uid(auth.uid()));
ALTER POLICY "admin_management admin all" ON public.admin_management USING (public._is_country_admin_uid(auth.uid())) WITH CHECK (public._is_country_admin_uid(auth.uid()));
ALTER POLICY "admin_permission_grants admin all" ON public.admin_permission_grants USING (public._is_country_admin_uid(auth.uid())) WITH CHECK (public._is_country_admin_uid(auth.uid()));
ALTER POLICY "admin_receiving_wallets_self_region" ON public.admin_receiving_wallets USING (public._admin_write_scope(region_id)) WITH CHECK (public._admin_write_scope(region_id));
ALTER POLICY "admin_region_assignments admin all" ON public.admin_region_assignments USING (public._is_country_admin_uid(auth.uid())) WITH CHECK (public._is_country_admin_uid(auth.uid()));
ALTER POLICY "admin_users admin select" ON public.admin_users USING (public._is_country_admin_uid(auth.uid()));
ALTER POLICY "approval_requests admin all" ON public.approval_requests USING (public._is_country_admin_uid(auth.uid())) WITH CHECK (public._is_country_admin_uid(auth.uid()));
ALTER POLICY "audit_log_select" ON public.audit_log USING (((auth.uid() = actor) OR _is_owner_uid(auth.uid()) OR public._is_country_admin_uid(auth.uid())));
ALTER POLICY "branches_view" ON public.branches USING (((merchant_id IN ( SELECT merchants.id
   FROM merchants
  WHERE (merchants.status = 'active'::text))) OR is_merchant_owner(merchant_id)));
ALTER POLICY "campaign_banners admin select" ON public.campaign_banners USING (public._is_country_admin_uid(auth.uid()));
ALTER POLICY "campaign_cta_routes admin manage" ON public.campaign_cta_routes USING (public._is_country_admin_uid(auth.uid())) WITH CHECK (public._is_country_admin_uid(auth.uid()));
ALTER POLICY "campaign_media admin delete" ON public.campaign_media USING (public.campaign_targets_authorized(campaign_id));
ALTER POLICY "campaign_media admin insert" ON public.campaign_media WITH CHECK (public.campaign_targets_authorized(campaign_id));
ALTER POLICY "campaign_media admin select" ON public.campaign_media USING (public._is_country_admin_uid(auth.uid()));
ALTER POLICY "campaign_media admin update" ON public.campaign_media USING (public.campaign_targets_authorized(campaign_id)) WITH CHECK (public.campaign_targets_authorized(campaign_id));
ALTER POLICY "campaign_reviews admin select" ON public.campaign_reviews USING (public._is_country_admin_uid(auth.uid()));
ALTER POLICY "campaign_targets admin delete" ON public.campaign_targets USING (public.campaign_targets_authorized(campaign_id));
ALTER POLICY "campaign_targets admin insert" ON public.campaign_targets WITH CHECK (public.campaign_can_target_region(region_id));
ALTER POLICY "campaign_targets admin select" ON public.campaign_targets USING (public._is_country_admin_uid(auth.uid()));
ALTER POLICY "campaigns admin insert" ON public.campaigns WITH CHECK (public._is_country_admin_uid(auth.uid()));
ALTER POLICY "campaigns admin select" ON public.campaigns USING (public._is_country_admin_uid(auth.uid()));
ALTER POLICY "campaigns admin update" ON public.campaigns USING (public.campaign_targets_authorized(id)) WITH CHECK (public.campaign_targets_authorized(id));
ALTER POLICY "cashier_license_events_owner_read" ON public.cashier_license_events USING ((EXISTS ( SELECT 1
   FROM cashier_licenses l
  WHERE ((l.id = cashier_license_events.license_id) AND (is_merchant_owner(l.merchant_id))))));
ALTER POLICY "chat_escalations admin all" ON public.chat_escalations USING (public._is_country_admin_uid(auth.uid())) WITH CHECK (public._is_country_admin_uid(auth.uid()));
ALTER POLICY "typing admin delete" ON public.chat_typing USING (public._is_country_admin_uid(auth.uid()));
ALTER POLICY "typing select room participants" ON public.chat_typing USING ((public._is_country_admin_uid(auth.uid()) OR (room_id IN ( SELECT cr.id
   FROM chat_rooms cr
  WHERE (auth.uid() = ANY (cr.participant_ids))))));
ALTER POLICY "driver_obligations_read_own" ON public.driver_obligations USING ((public._admin_write_scope(public._ops_scope_region(public._merchant_region_id(driver_obligations.merchant_id))) OR (EXISTS ( SELECT 1
   FROM drivers d
  WHERE ((d.id = driver_obligations.driver_id) AND (d.user_id = auth.uid())))) OR (EXISTS ( SELECT 1
   FROM merchants m
  WHERE ((m.id = driver_obligations.merchant_id) AND (m.owner_user_id = auth.uid()))))));
ALTER POLICY "escalation_events admin select" ON public.escalation_events USING (public._is_country_admin_uid(auth.uid()));
ALTER POLICY "geo_admin_boundaries admin write" ON public.geo_admin_boundaries USING (public._is_country_admin_uid(auth.uid())) WITH CHECK (public._is_country_admin_uid(auth.uid()));
ALTER POLICY "geo_aliases admin write" ON public.geo_aliases USING (public._is_country_admin_uid(auth.uid())) WITH CHECK (public._is_country_admin_uid(auth.uid()));
ALTER POLICY "geo_places admin write" ON public.geo_places USING (public._is_country_admin_uid(auth.uid())) WITH CHECK (public._is_country_admin_uid(auth.uid()));
ALTER POLICY "grace_admin_select" ON public.grace_audit_log USING (((account_id = auth.uid()) OR public._admin_member_scope(account_id)));
ALTER POLICY "merchant_ledger_read_own" ON public.merchant_ledger USING ((public._admin_write_scope(public._ops_scope_region(public._merchant_region_id(merchant_ledger.merchant_id))) OR (EXISTS ( SELECT 1
   FROM merchants m
  WHERE ((m.id = merchant_ledger.merchant_id) AND (m.owner_user_id = auth.uid()))))));
ALTER POLICY "merchant_payout_requests_read_own" ON public.merchant_payout_requests USING ((public._admin_write_scope(public._ops_scope_region(public._merchant_region_id(merchant_payout_requests.merchant_id))) OR (EXISTS ( SELECT 1
   FROM merchants m
  WHERE ((m.id = merchant_payout_requests.merchant_id) AND (m.owner_user_id = auth.uid()))))));
ALTER POLICY "Merchants readable by signed-in users" ON public.merchants USING (((status = 'active'::text) OR public.is_merchant_owner(id)));
ALTER POLICY "offers_view" ON public.offers USING (((merchant_id IN ( SELECT merchants.id
   FROM merchants
  WHERE (merchants.status = 'active'::text))) OR is_merchant_owner(merchant_id)));
ALTER POLICY "order_dispatch_owner_admin" ON public.order_dispatch USING ((_is_owner_uid(auth.uid()) OR public._is_country_admin_uid(auth.uid())));
ALTER POLICY "ot_insert_participants" ON public.order_tracking WITH CHECK ((EXISTS (SELECT 1 FROM public.orders oa WHERE oa.id = order_tracking.order_id AND public._admin_write_scope(public._ops_scope_region(public._merchant_region_id(oa.merchant_id)))) OR (EXISTS ( SELECT 1
   FROM orders o
  WHERE ((o.id = order_tracking.order_id) AND ((o.merchant_id IN ( SELECT m.id
           FROM merchants m
          WHERE (m.owner_user_id = auth.uid()))) OR (o.driver_id IN ( SELECT d.id
           FROM drivers d
          WHERE (d.user_id = auth.uid())))))))));
ALTER POLICY "ot_view_participants" ON public.order_tracking USING ((EXISTS (SELECT 1 FROM public.orders oa WHERE oa.id = order_tracking.order_id AND public._admin_write_scope(public._ops_scope_region(public._merchant_region_id(oa.merchant_id)))) OR (EXISTS ( SELECT 1
   FROM orders o
  WHERE ((o.id = order_tracking.order_id) AND ((o.user_id = auth.uid()) OR (o.merchant_id IN ( SELECT m.id
           FROM merchants m
          WHERE (m.owner_user_id = auth.uid()))) OR (o.driver_id IN ( SELECT d.id
           FROM drivers d
          WHERE (d.user_id = auth.uid())))))))));
ALTER POLICY "pharmacy_messages_read" ON public.pharmacy_messages USING ((EXISTS ( SELECT 1
   FROM pharmacy_links k
  WHERE ((k.id = pharmacy_messages.link_id) AND (is_merchant_owner(k.pharmacy_a) OR is_merchant_owner(k.pharmacy_b))))));
ALTER POLICY "pharmacy_ledger_read" ON public.pharmacy_transfer_ledger USING ((EXISTS ( SELECT 1
   FROM pharmacy_links k
  WHERE ((k.id = pharmacy_transfer_ledger.link_id) AND (is_merchant_owner(k.pharmacy_a) OR is_merchant_owner(k.pharmacy_b))))));
ALTER POLICY "receiving_accounts_admin_select" ON public.platform_receiving_accounts USING (public._is_country_admin_uid(auth.uid()));
ALTER POLICY "platform_settings admin delete" ON public.platform_settings USING (public._is_country_admin_uid(auth.uid()));
ALTER POLICY "platform_settings admin insert" ON public.platform_settings WITH CHECK (public._is_country_admin_uid(auth.uid()));
ALTER POLICY "platform_settings admin update" ON public.platform_settings USING (public._is_country_admin_uid(auth.uid())) WITH CHECK (public._is_country_admin_uid(auth.uid()));
ALTER POLICY "settlements_admin_insert" ON public.platform_settlements WITH CHECK (((admin_id = auth.uid()) AND public._is_country_admin_uid(auth.uid())));
ALTER POLICY "settlements_admin_region" ON public.platform_settlements USING ((public._is_country_admin_uid(auth.uid()) OR (public._is_active_admin_uid(auth.uid()) AND region_id IS NOT NULL AND public.is_admin_for_region(region_id))));
ALTER POLICY "Products are viewable by everyone" ON public.products USING (((merchant_id IN ( SELECT merchants.id
   FROM merchants
  WHERE (merchants.status = 'active'::text))) OR is_merchant_owner(merchant_id)));
ALTER POLICY "pbp_insert_own" ON public.provider_business_profiles WITH CHECK (((user_id = auth.uid()) OR public._admin_member_scope(user_id)));
ALTER POLICY "pbp_select_own_or_admin" ON public.provider_business_profiles USING (((user_id = auth.uid()) OR public._admin_member_scope(user_id)));
ALTER POLICY "pbp_update_admin" ON public.provider_business_profiles USING (public._admin_member_scope(user_id)) WITH CHECK (public._admin_member_scope(user_id));
ALTER POLICY "regional_collections_admin_region" ON public.regional_collections USING ((public._is_country_admin_uid(auth.uid()) OR (public._is_active_admin_uid(auth.uid()) AND region_id IS NOT NULL AND public.is_admin_for_region(region_id))));
ALTER POLICY "retention_policies_admin_all" ON public.retention_policies USING (public._is_country_admin_uid(auth.uid())) WITH CHECK (public._is_country_admin_uid(auth.uid()));
ALTER POLICY "Reviews are viewable by everyone" ON public.reviews USING (((merchant_id IN ( SELECT merchants.id
   FROM merchants
  WHERE (merchants.status = 'active'::text))) OR public.is_merchant_owner(merchant_id)));
ALTER POLICY "reviews_admin_delete" ON public.reviews USING (public._is_country_admin_uid(auth.uid()));
ALTER POLICY "Admins can view all rides" ON public.rides USING (public._is_country_admin_uid(auth.uid()));
ALTER POLICY "service_bookings_select_provider" ON public.service_bookings USING (((user_id = auth.uid()) OR (EXISTS ( SELECT 1
   FROM service_providers sp
  WHERE ((sp.id = service_bookings.provider_id) AND (sp.user_id = auth.uid())))) OR public._admin_member_scope(service_bookings.user_id)));
ALTER POLICY "service_bookings_update_provider" ON public.service_bookings USING (((user_id = auth.uid()) OR (EXISTS ( SELECT 1
   FROM service_providers sp
  WHERE ((sp.id = service_bookings.provider_id) AND (sp.user_id = auth.uid())))) OR public._admin_member_scope(service_bookings.user_id))) WITH CHECK (((user_id = auth.uid()) OR (EXISTS ( SELECT 1
   FROM service_providers sp
  WHERE ((sp.id = service_bookings.provider_id) AND (sp.user_id = auth.uid())))) OR public._admin_member_scope(service_bookings.user_id)));
ALTER POLICY "service_reviews_admin_all" ON public.service_reviews USING (public._is_country_admin_uid(auth.uid()));
ALTER POLICY "topup_admin_region_select" ON public.topup_requests USING ((public._is_country_admin_uid(auth.uid()) OR (public._is_active_admin_uid(auth.uid()) AND region_id IS NOT NULL AND public.is_admin_for_region(region_id))));

-- Sweep verification: no bare is_admin()/_is_active_admin_uid policy branches
-- may remain (expect 0).
SELECT count(*) AS remaining_bare_admin_policies
  FROM pg_policies
 WHERE schemaname='public'
   AND (qual ILIKE '%is_admin()%' OR with_check ILIKE '%is_admin()%'
        OR qual ILIKE '%_is_active_admin_uid%' OR with_check ILIKE '%_is_active_admin_uid%');

COMMIT;