-- 428 PROD EXTRACT: platform suggestions (owner request 2026-11-23).
-- Applies migration 428_suggestions.sql to prod (bttnlkmwhorjamzemwda).
-- Fresh additive feature; pre-state on prod and staging is identical (no
-- suggestions objects), so the applied body equals the reviewed migration
-- body verbatim (sha256 of the migration file:
-- 15218bc68b0da432b302c449edbe3903ce0e322d4edb5f1572d54ff6abbaa1e3).
-- One transaction: strict fresh-only guard, body, registry row,
-- postchecks. Any miss aborts with zero mutation.
BEGIN;

-- 428: platform suggestions (owner request, 2026-11-23).
--
-- Users of all four apps (customer, driver, admin, provider) can send
-- ideas to improve the platform. Mirrors the complaints pattern
-- (000_baseline complaints table + complaints_guard_admin_fields) but
-- deliberately narrower: no order/ride links, no respondent, no
-- escalation, no attachments, no chat rooms, no sanctions hooks.
--
-- v2 (reviews #142/#143/#144 + security):
-- - No client INSERT at all: the INSERT grant and the user INSERT policy
--   are gone, so rows are created ONLY by submit_suggestion (SECURITY
--   DEFINER). A client cannot forge status, admin_notes, reviewed_* or a
--   backdated created_at (this also covers the complaints BEFORE INSERT
--   fixup trigger's job, which RPC-only creation makes unnecessary).
-- - submit_suggestion takes a per-user advisory xact lock before the
--   rate-limit count, so overlapping sessions cannot both pass the
--   count; created_at stays server-owned.
-- - Guard block covers suggestions_guard_admin_fields() too.
-- - admin_notes / reviewed_at / reviewed_by are internal: authenticated
--   SELECT is column-granted and excludes them; users see their own rows
--   with resolution_note only. Admins read full rows via
--   admin_list_suggestions (definer-owned, not column-limited).
-- - submit_suggestion pre-checks the 120/2000 length limits for clean
--   22023 errors; admin_update_suggestion_status sets resolution_note
--   unconditionally so an admin can clear it; app_role is display-only
--   (the client states which app it is; it grants no permission).
--
-- - suggestions table with RLS: a user reads/updates only their own
--   rows; admins (is_admin()) have full access. Suggestions are
--   platform-wide ideas, so there is no regional scoping (unlike 411
--   complaints scoping, which protected case data, not ideas).
-- - suggestions_guard_admin_fields trigger: non-admin clients can edit
--   their own text but never the handling fields.
-- - submit_suggestion RPC: validated submit, 10-per-24h per-user rate
--   limit, serialized per user.
-- - admin_list_suggestions / admin_update_suggestion_status RPCs:
--   is_admin() gated admin list + triage.
--
-- Guard: fresh objects only. Aborts without mutation if the table or any
-- of the functions already exists.

DO $g$
BEGIN
  IF to_regclass('public.suggestions') IS NOT NULL THEN
    RAISE EXCEPTION 'public.suggestions already exists; aborting';
  END IF;
  IF to_regprocedure('public.submit_suggestion(text,text,text,text)') IS NOT NULL
     OR to_regprocedure('public.admin_list_suggestions(text,integer,integer)') IS NOT NULL
     OR to_regprocedure('public.admin_update_suggestion_status(uuid,text,text)') IS NOT NULL
     OR to_regprocedure('public.suggestions_guard_admin_fields()') IS NOT NULL THEN
    RAISE EXCEPTION 'suggestions functions already exist; aborting';
  END IF;
END
$g$;

CREATE TABLE public.suggestions (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  user_id uuid NOT NULL,
  app_role text NOT NULL,
  category text DEFAULT 'general'::text NOT NULL,
  subject text NOT NULL,
  description text NOT NULL,
  status text DEFAULT 'pending'::text NOT NULL,
  admin_notes text[] DEFAULT '{}'::text[] NOT NULL,
  resolution_note text,
  reviewed_at timestamp with time zone,
  reviewed_by uuid,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  updated_at timestamp with time zone,
  CONSTRAINT suggestions_pkey PRIMARY KEY (id),
  CONSTRAINT suggestions_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE,
  CONSTRAINT suggestions_reviewed_by_fkey FOREIGN KEY (reviewed_by) REFERENCES public.users(id) ON DELETE SET NULL,
  CONSTRAINT suggestions_app_role_check CHECK ((app_role = ANY (ARRAY['customer'::text, 'driver'::text, 'provider'::text, 'admin'::text]))),
  CONSTRAINT suggestions_category_check CHECK ((category = ANY (ARRAY['general'::text, 'app'::text, 'feature'::text, 'payment'::text, 'other'::text]))),
  CONSTRAINT suggestions_status_check CHECK ((status = ANY (ARRAY['pending'::text, 'reviewing'::text, 'accepted'::text, 'rejected'::text, 'implemented'::text]))),
  CONSTRAINT suggestions_subject_len CHECK ((char_length(btrim(subject)) BETWEEN 1 AND 120)),
  CONSTRAINT suggestions_description_len CHECK ((char_length(btrim(description)) BETWEEN 1 AND 2000))
);

CREATE INDEX idx_suggestions_user ON public.suggestions USING btree (user_id);
CREATE INDEX idx_suggestions_status_created ON public.suggestions USING btree (status, created_at DESC);
CREATE INDEX idx_suggestions_created ON public.suggestions USING btree (created_at DESC);

ALTER TABLE public.suggestions ENABLE ROW LEVEL SECURITY;

-- No user INSERT policy on purpose: creation goes through
-- submit_suggestion only (review #142 / security).
CREATE POLICY "users select own suggestions" ON public.suggestions AS PERMISSIVE
  FOR SELECT TO public USING (user_id = auth.uid());
CREATE POLICY "users update own suggestions" ON public.suggestions AS PERMISSIVE
  FOR UPDATE TO public USING (user_id = auth.uid());
CREATE POLICY "admins select suggestions" ON public.suggestions AS PERMISSIVE
  FOR SELECT TO public USING (is_admin());
CREATE POLICY "admins insert suggestions" ON public.suggestions AS PERMISSIVE
  FOR INSERT TO public WITH CHECK (is_admin());
CREATE POLICY "admins update suggestions" ON public.suggestions AS PERMISSIVE
  FOR UPDATE TO public USING (is_admin());
CREATE POLICY "admins delete suggestions" ON public.suggestions AS PERMISSIVE
  FOR DELETE TO public USING (is_admin());

-- Non-admin clients may edit their own text, never the handling fields
-- (same shape as complaints_guard_admin_fields in 000_baseline).
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
     OR NEW.user_id IS DISTINCT FROM OLD.user_id
     OR NEW.created_at IS DISTINCT FROM OLD.created_at THEN
    RAISE EXCEPTION 'suggestion handling fields are managed by the admin team';
  END IF;
  RETURN NEW;
END;
$function$;

CREATE TRIGGER trg_suggestions_guard_admin_fields
  BEFORE UPDATE ON public.suggestions
  FOR EACH ROW EXECUTE FUNCTION public.suggestions_guard_admin_fields();

CREATE TRIGGER suggestions_set_updated_at
  BEFORE UPDATE ON public.suggestions
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- Submit RPC: validated insert on behalf of the caller. app_role is
-- display-only (which app the idea came from); it grants no permission.
-- Rate limit: 10 per user per rolling 24h, serialized per user by an
-- advisory xact lock so overlapping sessions cannot both pass the count.
CREATE OR REPLACE FUNCTION public.submit_suggestion(
  p_subject text,
  p_description text,
  p_category text DEFAULT 'general'::text,
  p_app_role text DEFAULT 'customer'::text
)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_id uuid;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'not authenticated' USING ERRCODE = '28000';
  END IF;
  IF p_subject IS NULL OR char_length(btrim(p_subject)) = 0 THEN
    RAISE EXCEPTION 'subject is required' USING ERRCODE = '22023';
  END IF;
  IF char_length(btrim(p_subject)) > 120 THEN
    RAISE EXCEPTION 'subject too long (max 120)' USING ERRCODE = '22023';
  END IF;
  IF p_description IS NULL OR char_length(btrim(p_description)) = 0 THEN
    RAISE EXCEPTION 'description is required' USING ERRCODE = '22023';
  END IF;
  IF char_length(btrim(p_description)) > 2000 THEN
    RAISE EXCEPTION 'description too long (max 2000)' USING ERRCODE = '22023';
  END IF;
  IF p_category IS NULL OR p_category NOT IN ('general','app','feature','payment','other') THEN
    RAISE EXCEPTION 'invalid category' USING ERRCODE = '22023';
  END IF;
  IF p_app_role IS NULL OR p_app_role NOT IN ('customer','driver','provider','admin') THEN
    RAISE EXCEPTION 'invalid app_role' USING ERRCODE = '22023';
  END IF;
  PERFORM pg_advisory_xact_lock(hashtext('submit_suggestion'), hashtext(v_uid::text));
  IF (SELECT count(*) FROM public.suggestions s
       WHERE s.user_id = v_uid
         AND s.created_at > now() - interval '24 hours') >= 10 THEN
    RAISE EXCEPTION 'too many suggestions; please try again later' USING ERRCODE = 'P0001';
  END IF;
  INSERT INTO public.suggestions (user_id, app_role, category, subject, description)
  VALUES (v_uid, p_app_role, p_category, btrim(p_subject), btrim(p_description))
  RETURNING id INTO v_id;
  RETURN v_id;
END;
$function$;

-- Admin list RPC: full rows (including internal admin_notes), newest first.
CREATE OR REPLACE FUNCTION public.admin_list_suggestions(
  p_status text DEFAULT NULL::text,
  p_limit integer DEFAULT 100,
  p_offset integer DEFAULT 0
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
  RETURN QUERY
    SELECT s.* FROM public.suggestions s
     WHERE (p_status IS NULL OR s.status = p_status)
     ORDER BY s.created_at DESC
     LIMIT GREATEST(1, LEAST(COALESCE(p_limit, 100), 500))
     OFFSET GREATEST(0, COALESCE(p_offset, 0));
END;
$function$;

-- Admin triage RPC: set status; resolution_note is set unconditionally so
-- passing NULL clears a previous note. Stamps reviewed_at/reviewed_by.
CREATE OR REPLACE FUNCTION public.admin_update_suggestion_status(
  p_suggestion_id uuid,
  p_status text,
  p_resolution_note text DEFAULT NULL::text
)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'admin only' USING ERRCODE = '42501';
  END IF;
  IF p_status IS NULL OR p_status NOT IN ('pending','reviewing','accepted','rejected','implemented') THEN
    RAISE EXCEPTION 'invalid status' USING ERRCODE = '22023';
  END IF;
  UPDATE public.suggestions
     SET status = p_status,
         resolution_note = p_resolution_note,
         reviewed_at = now(),
         reviewed_by = auth.uid()
   WHERE id = p_suggestion_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'suggestion not found' USING ERRCODE = 'P0002';
  END IF;
END;
$function$;

-- Table grants. Default privileges (000_baseline) would hand anon and
-- authenticated table-level rights on every new table; strip them first,
-- then grant exactly what each role needs. SELECT for authenticated is
-- column-granted: internal handling fields (admin_notes, reviewed_at,
-- reviewed_by) stay server-side; users see resolution_note only. No
-- INSERT for authenticated (RPC-only creation). UPDATE/DELETE are
-- RLS-gated.
REVOKE ALL ON TABLE public.suggestions FROM PUBLIC, anon, authenticated;
GRANT SELECT (id, user_id, app_role, category, subject, description, status, resolution_note, created_at, updated_at)
  ON TABLE public.suggestions TO authenticated;
GRANT UPDATE, DELETE ON TABLE public.suggestions TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.suggestions TO postgres;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.suggestions TO service_role;

REVOKE ALL ON FUNCTION public.suggestions_guard_admin_fields() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.suggestions_guard_admin_fields() TO postgres, service_role;
REVOKE ALL ON FUNCTION public.submit_suggestion(text, text, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.submit_suggestion(text, text, text, text) TO authenticated, postgres, service_role;
REVOKE ALL ON FUNCTION public.admin_list_suggestions(text, integer, integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_list_suggestions(text, integer, integer) TO authenticated, postgres, service_role;
REVOKE ALL ON FUNCTION public.admin_update_suggestion_status(uuid, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_update_suggestion_status(uuid, text, text) TO authenticated, postgres, service_role;

-- Verify (inside the transaction; any miss aborts).
DO $v$
BEGIN
  IF to_regclass('public.suggestions') IS NULL THEN
    RAISE EXCEPTION 'suggestions table missing after create';
  END IF;
  IF to_regprocedure('public.submit_suggestion(text,text,text,text)') IS NULL
     OR to_regprocedure('public.admin_list_suggestions(text,integer,integer)') IS NULL
     OR to_regprocedure('public.admin_update_suggestion_status(uuid,text,text)') IS NULL
     OR to_regprocedure('public.suggestions_guard_admin_fields()') IS NULL THEN
    RAISE EXCEPTION 'suggestions functions missing after create';
  END IF;
  IF (SELECT count(*) FROM pg_policies
       WHERE schemaname = 'public' AND tablename = 'suggestions') <> 6 THEN
    RAISE EXCEPTION 'expected 6 RLS policies on suggestions';
  END IF;
END
$v$;



-- Registry row: exact reviewed migration bytes.
INSERT INTO supabase_migrations.schema_migrations(version, name, statements)
VALUES ('428', '428_suggestions', ARRAY[$reg$-- 428: platform suggestions (owner request, 2026-11-23).
--
-- Users of all four apps (customer, driver, admin, provider) can send
-- ideas to improve the platform. Mirrors the complaints pattern
-- (000_baseline complaints table + complaints_guard_admin_fields) but
-- deliberately narrower: no order/ride links, no respondent, no
-- escalation, no attachments, no chat rooms, no sanctions hooks.
--
-- v2 (reviews #142/#143/#144 + security):
-- - No client INSERT at all: the INSERT grant and the user INSERT policy
--   are gone, so rows are created ONLY by submit_suggestion (SECURITY
--   DEFINER). A client cannot forge status, admin_notes, reviewed_* or a
--   backdated created_at (this also covers the complaints BEFORE INSERT
--   fixup trigger's job, which RPC-only creation makes unnecessary).
-- - submit_suggestion takes a per-user advisory xact lock before the
--   rate-limit count, so overlapping sessions cannot both pass the
--   count; created_at stays server-owned.
-- - Guard block covers suggestions_guard_admin_fields() too.
-- - admin_notes / reviewed_at / reviewed_by are internal: authenticated
--   SELECT is column-granted and excludes them; users see their own rows
--   with resolution_note only. Admins read full rows via
--   admin_list_suggestions (definer-owned, not column-limited).
-- - submit_suggestion pre-checks the 120/2000 length limits for clean
--   22023 errors; admin_update_suggestion_status sets resolution_note
--   unconditionally so an admin can clear it; app_role is display-only
--   (the client states which app it is; it grants no permission).
--
-- - suggestions table with RLS: a user reads/updates only their own
--   rows; admins (is_admin()) have full access. Suggestions are
--   platform-wide ideas, so there is no regional scoping (unlike 411
--   complaints scoping, which protected case data, not ideas).
-- - suggestions_guard_admin_fields trigger: non-admin clients can edit
--   their own text but never the handling fields.
-- - submit_suggestion RPC: validated submit, 10-per-24h per-user rate
--   limit, serialized per user.
-- - admin_list_suggestions / admin_update_suggestion_status RPCs:
--   is_admin() gated admin list + triage.
--
-- Guard: fresh objects only. Aborts without mutation if the table or any
-- of the functions already exists.

BEGIN;

DO $g$
BEGIN
  IF to_regclass('public.suggestions') IS NOT NULL THEN
    RAISE EXCEPTION 'public.suggestions already exists; aborting';
  END IF;
  IF to_regprocedure('public.submit_suggestion(text,text,text,text)') IS NOT NULL
     OR to_regprocedure('public.admin_list_suggestions(text,integer,integer)') IS NOT NULL
     OR to_regprocedure('public.admin_update_suggestion_status(uuid,text,text)') IS NOT NULL
     OR to_regprocedure('public.suggestions_guard_admin_fields()') IS NOT NULL THEN
    RAISE EXCEPTION 'suggestions functions already exist; aborting';
  END IF;
END
$g$;

CREATE TABLE public.suggestions (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  user_id uuid NOT NULL,
  app_role text NOT NULL,
  category text DEFAULT 'general'::text NOT NULL,
  subject text NOT NULL,
  description text NOT NULL,
  status text DEFAULT 'pending'::text NOT NULL,
  admin_notes text[] DEFAULT '{}'::text[] NOT NULL,
  resolution_note text,
  reviewed_at timestamp with time zone,
  reviewed_by uuid,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  updated_at timestamp with time zone,
  CONSTRAINT suggestions_pkey PRIMARY KEY (id),
  CONSTRAINT suggestions_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE,
  CONSTRAINT suggestions_reviewed_by_fkey FOREIGN KEY (reviewed_by) REFERENCES public.users(id) ON DELETE SET NULL,
  CONSTRAINT suggestions_app_role_check CHECK ((app_role = ANY (ARRAY['customer'::text, 'driver'::text, 'provider'::text, 'admin'::text]))),
  CONSTRAINT suggestions_category_check CHECK ((category = ANY (ARRAY['general'::text, 'app'::text, 'feature'::text, 'payment'::text, 'other'::text]))),
  CONSTRAINT suggestions_status_check CHECK ((status = ANY (ARRAY['pending'::text, 'reviewing'::text, 'accepted'::text, 'rejected'::text, 'implemented'::text]))),
  CONSTRAINT suggestions_subject_len CHECK ((char_length(btrim(subject)) BETWEEN 1 AND 120)),
  CONSTRAINT suggestions_description_len CHECK ((char_length(btrim(description)) BETWEEN 1 AND 2000))
);

CREATE INDEX idx_suggestions_user ON public.suggestions USING btree (user_id);
CREATE INDEX idx_suggestions_status_created ON public.suggestions USING btree (status, created_at DESC);
CREATE INDEX idx_suggestions_created ON public.suggestions USING btree (created_at DESC);

ALTER TABLE public.suggestions ENABLE ROW LEVEL SECURITY;

-- No user INSERT policy on purpose: creation goes through
-- submit_suggestion only (review #142 / security).
CREATE POLICY "users select own suggestions" ON public.suggestions AS PERMISSIVE
  FOR SELECT TO public USING (user_id = auth.uid());
CREATE POLICY "users update own suggestions" ON public.suggestions AS PERMISSIVE
  FOR UPDATE TO public USING (user_id = auth.uid());
CREATE POLICY "admins select suggestions" ON public.suggestions AS PERMISSIVE
  FOR SELECT TO public USING (is_admin());
CREATE POLICY "admins insert suggestions" ON public.suggestions AS PERMISSIVE
  FOR INSERT TO public WITH CHECK (is_admin());
CREATE POLICY "admins update suggestions" ON public.suggestions AS PERMISSIVE
  FOR UPDATE TO public USING (is_admin());
CREATE POLICY "admins delete suggestions" ON public.suggestions AS PERMISSIVE
  FOR DELETE TO public USING (is_admin());

-- Non-admin clients may edit their own text, never the handling fields
-- (same shape as complaints_guard_admin_fields in 000_baseline).
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
     OR NEW.user_id IS DISTINCT FROM OLD.user_id
     OR NEW.created_at IS DISTINCT FROM OLD.created_at THEN
    RAISE EXCEPTION 'suggestion handling fields are managed by the admin team';
  END IF;
  RETURN NEW;
END;
$function$;

CREATE TRIGGER trg_suggestions_guard_admin_fields
  BEFORE UPDATE ON public.suggestions
  FOR EACH ROW EXECUTE FUNCTION public.suggestions_guard_admin_fields();

CREATE TRIGGER suggestions_set_updated_at
  BEFORE UPDATE ON public.suggestions
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- Submit RPC: validated insert on behalf of the caller. app_role is
-- display-only (which app the idea came from); it grants no permission.
-- Rate limit: 10 per user per rolling 24h, serialized per user by an
-- advisory xact lock so overlapping sessions cannot both pass the count.
CREATE OR REPLACE FUNCTION public.submit_suggestion(
  p_subject text,
  p_description text,
  p_category text DEFAULT 'general'::text,
  p_app_role text DEFAULT 'customer'::text
)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_id uuid;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'not authenticated' USING ERRCODE = '28000';
  END IF;
  IF p_subject IS NULL OR char_length(btrim(p_subject)) = 0 THEN
    RAISE EXCEPTION 'subject is required' USING ERRCODE = '22023';
  END IF;
  IF char_length(btrim(p_subject)) > 120 THEN
    RAISE EXCEPTION 'subject too long (max 120)' USING ERRCODE = '22023';
  END IF;
  IF p_description IS NULL OR char_length(btrim(p_description)) = 0 THEN
    RAISE EXCEPTION 'description is required' USING ERRCODE = '22023';
  END IF;
  IF char_length(btrim(p_description)) > 2000 THEN
    RAISE EXCEPTION 'description too long (max 2000)' USING ERRCODE = '22023';
  END IF;
  IF p_category IS NULL OR p_category NOT IN ('general','app','feature','payment','other') THEN
    RAISE EXCEPTION 'invalid category' USING ERRCODE = '22023';
  END IF;
  IF p_app_role IS NULL OR p_app_role NOT IN ('customer','driver','provider','admin') THEN
    RAISE EXCEPTION 'invalid app_role' USING ERRCODE = '22023';
  END IF;
  PERFORM pg_advisory_xact_lock(hashtext('submit_suggestion'), hashtext(v_uid::text));
  IF (SELECT count(*) FROM public.suggestions s
       WHERE s.user_id = v_uid
         AND s.created_at > now() - interval '24 hours') >= 10 THEN
    RAISE EXCEPTION 'too many suggestions; please try again later' USING ERRCODE = 'P0001';
  END IF;
  INSERT INTO public.suggestions (user_id, app_role, category, subject, description)
  VALUES (v_uid, p_app_role, p_category, btrim(p_subject), btrim(p_description))
  RETURNING id INTO v_id;
  RETURN v_id;
END;
$function$;

-- Admin list RPC: full rows (including internal admin_notes), newest first.
CREATE OR REPLACE FUNCTION public.admin_list_suggestions(
  p_status text DEFAULT NULL::text,
  p_limit integer DEFAULT 100,
  p_offset integer DEFAULT 0
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
  RETURN QUERY
    SELECT s.* FROM public.suggestions s
     WHERE (p_status IS NULL OR s.status = p_status)
     ORDER BY s.created_at DESC
     LIMIT GREATEST(1, LEAST(COALESCE(p_limit, 100), 500))
     OFFSET GREATEST(0, COALESCE(p_offset, 0));
END;
$function$;

-- Admin triage RPC: set status; resolution_note is set unconditionally so
-- passing NULL clears a previous note. Stamps reviewed_at/reviewed_by.
CREATE OR REPLACE FUNCTION public.admin_update_suggestion_status(
  p_suggestion_id uuid,
  p_status text,
  p_resolution_note text DEFAULT NULL::text
)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'admin only' USING ERRCODE = '42501';
  END IF;
  IF p_status IS NULL OR p_status NOT IN ('pending','reviewing','accepted','rejected','implemented') THEN
    RAISE EXCEPTION 'invalid status' USING ERRCODE = '22023';
  END IF;
  UPDATE public.suggestions
     SET status = p_status,
         resolution_note = p_resolution_note,
         reviewed_at = now(),
         reviewed_by = auth.uid()
   WHERE id = p_suggestion_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'suggestion not found' USING ERRCODE = 'P0002';
  END IF;
END;
$function$;

-- Table grants. Default privileges (000_baseline) would hand anon and
-- authenticated table-level rights on every new table; strip them first,
-- then grant exactly what each role needs. SELECT for authenticated is
-- column-granted: internal handling fields (admin_notes, reviewed_at,
-- reviewed_by) stay server-side; users see resolution_note only. No
-- INSERT for authenticated (RPC-only creation). UPDATE/DELETE are
-- RLS-gated.
REVOKE ALL ON TABLE public.suggestions FROM PUBLIC, anon, authenticated;
GRANT SELECT (id, user_id, app_role, category, subject, description, status, resolution_note, created_at, updated_at)
  ON TABLE public.suggestions TO authenticated;
GRANT UPDATE, DELETE ON TABLE public.suggestions TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.suggestions TO postgres;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.suggestions TO service_role;

REVOKE ALL ON FUNCTION public.suggestions_guard_admin_fields() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.suggestions_guard_admin_fields() TO postgres, service_role;
REVOKE ALL ON FUNCTION public.submit_suggestion(text, text, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.submit_suggestion(text, text, text, text) TO authenticated, postgres, service_role;
REVOKE ALL ON FUNCTION public.admin_list_suggestions(text, integer, integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_list_suggestions(text, integer, integer) TO authenticated, postgres, service_role;
REVOKE ALL ON FUNCTION public.admin_update_suggestion_status(uuid, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_update_suggestion_status(uuid, text, text) TO authenticated, postgres, service_role;

-- Verify (inside the transaction; any miss aborts).
DO $v$
BEGIN
  IF to_regclass('public.suggestions') IS NULL THEN
    RAISE EXCEPTION 'suggestions table missing after create';
  END IF;
  IF to_regprocedure('public.submit_suggestion(text,text,text,text)') IS NULL
     OR to_regprocedure('public.admin_list_suggestions(text,integer,integer)') IS NULL
     OR to_regprocedure('public.admin_update_suggestion_status(uuid,text,text)') IS NULL
     OR to_regprocedure('public.suggestions_guard_admin_fields()') IS NULL THEN
    RAISE EXCEPTION 'suggestions functions missing after create';
  END IF;
  IF (SELECT count(*) FROM pg_policies
       WHERE schemaname = 'public' AND tablename = 'suggestions') <> 6 THEN
    RAISE EXCEPTION 'expected 6 RLS policies on suggestions';
  END IF;
END
$v$;

COMMIT;
$reg$]);

-- Postchecks.
DO $p$
BEGIN
  IF to_regclass('public.suggestions') IS NULL THEN
    RAISE EXCEPTION 'postcheck: suggestions table missing';
  END IF;
  IF NOT (SELECT relrowsecurity FROM pg_class WHERE oid = 'public.suggestions'::regclass) THEN
    RAISE EXCEPTION 'postcheck: RLS not enabled on suggestions';
  END IF;
  IF to_regprocedure('public.submit_suggestion(text,text,text,text)') IS NULL
     OR to_regprocedure('public.admin_list_suggestions(text,integer,integer)') IS NULL
     OR to_regprocedure('public.admin_update_suggestion_status(uuid,text,text)') IS NULL
     OR to_regprocedure('public.suggestions_guard_admin_fields()') IS NULL THEN
    RAISE EXCEPTION 'postcheck: suggestions functions missing';
  END IF;
  IF (SELECT count(*) FROM pg_policies
       WHERE schemaname = 'public' AND tablename = 'suggestions') <> 6 THEN
    RAISE EXCEPTION 'postcheck: expected 6 RLS policies';
  END IF;
  -- No table-level SELECT for authenticated (column-granted only), and the
  -- internal columns are not among the column grants.
  IF EXISTS (SELECT 1 FROM information_schema.role_table_grants
              WHERE table_schema='public' AND table_name='suggestions'
                AND grantee='authenticated' AND privilege_type='SELECT') THEN
    RAISE EXCEPTION 'postcheck: authenticated still has table-level SELECT';
  END IF;
  -- NB: role_column_grants explodes table-level UPDATE/DELETE to every
  -- column, so this check must filter privilege_type='SELECT'.
  IF EXISTS (SELECT 1 FROM information_schema.role_column_grants
              WHERE table_schema='public' AND table_name='suggestions'
                AND grantee='authenticated' AND privilege_type='SELECT'
                AND column_name IN ('admin_notes','reviewed_at','reviewed_by')) THEN
    RAISE EXCEPTION 'postcheck: internal columns granted to authenticated';
  END IF;
  IF (SELECT count(*) FROM information_schema.role_column_grants
       WHERE table_schema='public' AND table_name='suggestions'
         AND grantee='authenticated' AND privilege_type='SELECT') <> 10 THEN
    RAISE EXCEPTION 'postcheck: expected exactly 10 column SELECT grants';
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.role_table_grants
              WHERE table_schema='public' AND table_name='suggestions'
                AND grantee='authenticated' AND privilege_type='INSERT') THEN
    RAISE EXCEPTION 'postcheck: authenticated has INSERT (must be RPC-only)';
  END IF;
END
$p$;

COMMIT;
