-- 429: suggestions triage loop (#19).
--
-- Adds to the 428 suggestions table:
-- - linked_url: optional link to the GitHub issue or task note a
--   suggestion became (admin-only; not in the authenticated column grant,
--   so users never read it).
-- - admin_list_suggestions gains an optional app filter (p_app_role).
--   The 3-argument version is dropped and replaced by a 4-argument one with
--   a default, so existing 3-argument calls keep working.
-- - admin_set_suggestion_link(uuid, text): admin-only; NULL or empty
--   clears the link. Separate from admin_update_suggestion_status so
--   older app builds calling the status RPC can never clear a link.
--
-- Guard: aborts without mutation if the 428 objects are missing or this
-- migration already ran.

BEGIN;

DO $g$
BEGIN
  IF to_regclass('public.suggestions') IS NULL THEN
    RAISE EXCEPTION 'public.suggestions missing; run 428 first';
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns
              WHERE table_schema = 'public' AND table_name = 'suggestions'
                AND column_name = 'linked_url') THEN
    RAISE EXCEPTION 'suggestions.linked_url already exists; aborting';
  END IF;
  IF to_regprocedure('public.admin_set_suggestion_link(uuid,text)') IS NOT NULL
     OR to_regprocedure('public.admin_list_suggestions(text,integer,integer,text)') IS NOT NULL THEN
    RAISE EXCEPTION '429 functions already exist; aborting';
  END IF;
END
$g$;

ALTER TABLE public.suggestions
  ADD COLUMN linked_url text,
  ADD CONSTRAINT suggestions_linked_url_check
    CHECK (linked_url IS NULL OR (char_length(linked_url) <= 500 AND linked_url ~ '^https://[^[:space:]]+$'));

-- Non-admin clients must not touch the new handling field either.
CREATE OR REPLACE FUNCTION public.suggestions_guard_admin_fields()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF current_user NOT IN ('authenticated', 'anon') THEN
    RETURN NEW;
  END IF;
  IF public.is_admin() THEN
    RETURN NEW;
  END IF;
  IF NEW.status IS DISTINCT FROM OLD.status
     OR NEW.admin_notes IS DISTINCT FROM OLD.admin_notes
     OR NEW.resolution_note IS DISTINCT FROM OLD.resolution_note
     OR NEW.reviewed_at IS DISTINCT FROM OLD.reviewed_at
     OR NEW.reviewed_by IS DISTINCT FROM OLD.reviewed_by
     OR NEW.linked_url IS DISTINCT FROM OLD.linked_url
     OR NEW.user_id IS DISTINCT FROM OLD.user_id
     OR NEW.created_at IS DISTINCT FROM OLD.created_at THEN
    RAISE EXCEPTION 'suggestion handling fields are managed by the admin team';
  END IF;
  RETURN NEW;
END;
$function$;

DROP FUNCTION public.admin_list_suggestions(text, integer, integer);

CREATE OR REPLACE FUNCTION public.admin_list_suggestions(
  p_status text DEFAULT NULL::text,
  p_limit integer DEFAULT 100,
  p_offset integer DEFAULT 0,
  p_app_role text DEFAULT NULL::text
)
 RETURNS SETOF public.suggestions
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'admin only' USING ERRCODE = '42501';
  END IF;
  IF p_status IS NOT NULL AND p_status NOT IN ('pending','reviewing','accepted','rejected','implemented') THEN
    RAISE EXCEPTION 'invalid status' USING ERRCODE = '22023';
  END IF;
  IF p_app_role IS NOT NULL AND p_app_role NOT IN ('customer','driver','provider','admin') THEN
    RAISE EXCEPTION 'invalid app_role' USING ERRCODE = '22023';
  END IF;
  RETURN QUERY
    SELECT s.* FROM public.suggestions s
     WHERE (p_status IS NULL OR s.status = p_status)
       AND (p_app_role IS NULL OR s.app_role = p_app_role)
     ORDER BY s.created_at DESC
     LIMIT GREATEST(1, LEAST(COALESCE(p_limit, 100), 500))
     OFFSET GREATEST(0, COALESCE(p_offset, 0));
END;
$function$;

CREATE OR REPLACE FUNCTION public.admin_set_suggestion_link(
  p_suggestion_id uuid,
  p_linked_url text
)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_url text := NULLIF(btrim(COALESCE(p_linked_url, '')), '');
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'admin only' USING ERRCODE = '42501';
  END IF;
  IF v_url IS NOT NULL AND (char_length(v_url) > 500 OR v_url !~ '^https://[^[:space:]]+$') THEN
    RAISE EXCEPTION 'link must be an https URL (max 500)' USING ERRCODE = '22023';
  END IF;
  UPDATE public.suggestions
     SET linked_url = v_url,
         reviewed_at = now(),
         reviewed_by = auth.uid()
   WHERE id = p_suggestion_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'suggestion not found' USING ERRCODE = 'P0002';
  END IF;
END;
$function$;

REVOKE ALL ON FUNCTION public.admin_list_suggestions(text, integer, integer, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_list_suggestions(text, integer, integer, text) TO authenticated, postgres, service_role;
REVOKE ALL ON FUNCTION public.admin_set_suggestion_link(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_set_suggestion_link(uuid, text) TO authenticated, postgres, service_role;

-- linked_url stays out of the authenticated column grant (428 granted a
-- fixed column list); nothing to add. Verify.
DO $v$
BEGIN
  IF to_regprocedure('public.admin_list_suggestions(text,integer,integer,text)') IS NULL
     OR to_regprocedure('public.admin_list_suggestions(text,integer,integer)') IS NOT NULL
     OR to_regprocedure('public.admin_set_suggestion_link(uuid,text)') IS NULL THEN
    RAISE EXCEPTION '429 functions wrong after create';
  END IF;
  IF has_column_privilege('authenticated', 'public.suggestions', 'linked_url', 'SELECT') THEN
    RAISE EXCEPTION 'authenticated must not read linked_url';
  END IF;
END
$v$;

COMMIT;
