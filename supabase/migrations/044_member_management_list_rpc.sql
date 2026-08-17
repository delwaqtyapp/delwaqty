-- ============================================================
-- 044 — Member management: list/search RPC + feature scaffold
-- ============================================================
-- Nightly full-platform build, STEP 9.
--
-- Adds list_members RPC for admin member search (the DB has single-member
-- lookups via get_member_profile/get_member_status/get_member_timeline but
-- no paginated list/search).
--
-- list_members(p_search, p_role, p_account_status, p_region_id, p_cursor, p_limit):
--   Region-scoped (admin can only see members in their region + descendants).
--   Search by name/email partial match. Filter by role + account_status.
--   Keyset-paginated via created_at DESC cursor.
--   Returns: id, full_name, email, phone, role, account_status,
--            verification_status, region_id, created_at.
--
-- Idempotent / additive. SECURITY DEFINER + SET search_path = public, pg_temp.
-- ============================================================

BEGIN;

CREATE OR REPLACE FUNCTION public.list_members(
  p_search        text DEFAULT NULL,
  p_role          text DEFAULT NULL,
  p_account_status text DEFAULT NULL,
  p_region_id     uuid DEFAULT NULL,
  p_cursor        timestamptz DEFAULT NULL,
  p_limit         int DEFAULT 20
)
RETURNS TABLE (
  id                  uuid,
  full_name           text,
  email               text,
  phone               text,
  role                text,
  account_status      text,
  verification_status text,
  region_id           uuid,
  created_at          timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_uid    uuid := auth.uid();
  v_limit  int := LEAST(COALESCE(p_limit, 20), 50);
BEGIN
  IF v_uid IS NULL THEN
    RETURN;
  END IF;

  IF NOT public.has_permission('MEMBER_VIEW', public._member_region_id(v_uid)) THEN
    RETURN;
  END IF;

  RETURN QUERY
  SELECT u.id,
         u.full_name,
         u.email,
         u.phone,
         u.role,
         COALESCE(u.account_status, 'active'),
         COALESCE(u.verification_status, 'unverified'),
         up.region_id,
         u.created_at
    FROM public.users u
    LEFT JOIN public.user_region_preferences up ON up.user_id = u.id
      AND up.updated_at = (
        SELECT MAX(up2.updated_at)
          FROM public.user_region_preferences up2
         WHERE up2.user_id = u.id
      )
   WHERE (p_search IS NULL
           OR u.full_name ILIKE '%' || p_search || '%'
           OR u.email ILIKE '%' || p_search || '%')
     AND (p_role IS NULL OR u.role = p_role)
     AND (p_account_status IS NULL
           OR COALESCE(u.account_status, 'active') = p_account_status)
     AND (p_region_id IS NULL
           OR up.region_id = p_region_id
           OR up.region_id IN (
             WITH RECURSIVE region_chain AS (
               SELECT p_region_id AS rid
               UNION ALL
               SELECT r.parent_region_id
                 FROM public.regions r
                 JOIN region_chain rc ON r.id = rc.rid
                WHERE r.parent_region_id IS NOT NULL
             )
             SELECT rid FROM region_chain
           ))
     AND (p_cursor IS NULL OR u.created_at < p_cursor)
   ORDER BY u.created_at DESC
   LIMIT v_limit;
END;
$$;

COMMENT ON FUNCTION public.list_members(text, text, text, uuid, timestamptz, int) IS
  'Admin member search (044). Region-scoped, keyset-paginated, with optional '
  'text search on name/email. Returns basic member info for list views.';

REVOKE ALL ON FUNCTION public.list_members(text, text, text, uuid, timestamptz, int) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.list_members(text, text, text, uuid, timestamptz, int) FROM anon;
GRANT EXECUTE ON FUNCTION public.list_members(text, text, text, uuid, timestamptz, int)
  TO authenticated, service_role;

COMMIT;
