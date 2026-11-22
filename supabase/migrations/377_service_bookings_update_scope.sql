-- 377: close the customer-region admin branch on service_bookings.
-- 367 ORed _admin_member_scope(user_id) into the SELECT/UPDATE provider
-- policies, which combined with the provider-geocode ALL policy let an
-- admin write ANY provider's booking as long as the CUSTOMER lived in
-- the admin's region. Admin access now flows only through the
-- provider-geocode "Admins can manage bookings" policy; the provider
-- policies cover the customer and the provider themselves.

-- SELECT keeps the customer-region admin branch: the admin read model is
-- member-scoped (a region admin must see bookings of customers in their
-- region even when the provider is outside it). Only WRITES are narrowed
-- to the provider geocode.
ALTER POLICY "service_bookings_select_provider" ON public.service_bookings
  USING (((user_id = auth.uid()) OR (EXISTS (
    SELECT 1 FROM service_providers sp
    WHERE ((sp.id = service_bookings.provider_id) AND (sp.user_id = auth.uid())))) OR public._admin_member_scope(service_bookings.user_id)));

ALTER POLICY "service_bookings_update_provider" ON public.service_bookings
  USING (((user_id = auth.uid()) OR (EXISTS (
    SELECT 1 FROM service_providers sp
    WHERE ((sp.id = service_bookings.provider_id) AND (sp.user_id = auth.uid()))))))
  WITH CHECK (((user_id = auth.uid()) OR (EXISTS (
    SELECT 1 FROM service_providers sp
    WHERE ((sp.id = service_bookings.provider_id) AND (sp.user_id = auth.uid()))))));
