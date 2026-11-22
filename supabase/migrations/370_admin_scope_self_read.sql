-- 370: restore admin scope self-reads (367 regression). The country-only ALL
-- policies on admin_region_assignments and admin_management hid a scoped
-- admin's OWN rows, so the admin web could not discover its scope and fell
-- back to all-governorates / empty members / zero counters. Add narrow
-- self-read SELECT policies: an admin reads only their own management row
-- and their own region assignments. Writes stay country-only.
BEGIN;

CREATE POLICY "admin_region_assignments self read"
  ON public.admin_region_assignments FOR SELECT
  USING (admin_id = auth.uid());

CREATE POLICY "admin_management self read"
  ON public.admin_management FOR SELECT
  USING (admin_id = auth.uid());

COMMIT;
