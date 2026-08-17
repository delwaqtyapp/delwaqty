-- ============================================================
-- 049 — Member & Platform Operations Center (STEP 14, Phase 2)
-- ============================================================
-- Nightly full-platform build, STEP 14.
--
-- Adds the server-side backbone for the Member & Platform Operations
-- Center:
--
--  A. Commission rules (server-side, Phase 16/17 financial intelligence)
--     - commission_rules: versioned rate table (7% driver/provider,
--       3% merchant/restaurant/pharmacy) with effective_from/effective_to
--       so historical rates are never mutated.
--     - get_commission_rate() / calculate_commission(): the ONLY place
--       commission math lives (Constitution: no business logic in Flutter).
--     - platform_commissions: per-transaction ledger with a rate snapshot
--       for every order/ride/booking the operations center settles.
--     - platform_commission_for_reference(): computes + records the snapshot.
--     - platform_revenue_overview(): GMV + platform revenue by category and
--       period, computed from real completed transactions.
--
--  B. Operations Center RPCs
--     - member_ops_list(): the real platform member list (users + profiles)
--       with server-side search, filters, sort, region scoping and
--       keyset/cursor pagination. Supersedes list_members (kept for API
--       compatibility).
--     - member_ops_count(): matching total for pagination/badges.
--     - get_member_ops_profile(): full sectioned profile for the drawer.
--     - member_financial_summary(): wallet + earnings + commission breakdown.
--
--  C. Performance indexes (Phase 21) for member operations queries.
--
--  D. Grants: functions for authenticated + service_role only (tables are
--     RLS-denied to authenticated; reads flow through SECURITY DEFINER RPCs).
--
-- Idempotent / additive. SECURITY DEFINER + SET search_path = public, pg_temp.
-- ============================================================

BEGIN;

-- Platform-wide revenue must be an explicit, vocabulary-valid permission.
-- Additive extension of the existing permission vocabulary (keeps owner
-- short-circuit + grant-only semantics intact).
CREATE OR REPLACE FUNCTION public._valid_permission(p_permission text)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT p_permission IN (
    'ADMIN_CREATE', 'ADMIN_ASSIGN', 'ADMIN_ROLE_ASSIGN', 'ADMIN_REGION_ASSIGN',
    'ADMIN_SUPERVISOR_ASSIGN', 'ADMIN_SUSPEND',
    'MEMBER_VIEW', 'MEMBER_VIEW_LOCATION', 'MEMBER_VIEW_CHAT_HISTORY',
    'MEMBER_VIEW_COMPLAINTS', 'MEMBER_VIEW_TIMELINE', 'MEMBER_VIEW_DOCUMENTS',
    'MEMBER_MODERATE', 'MEMBER_WARN', 'MEMBER_RESTRICT', 'MEMBER_SUSPEND',
    'MEMBER_BAN', 'MEMBER_DELETE',
    'EMERGENCY_VIEW', 'EMERGENCY_AUDIO',
    'OFFER_CREATE', 'OFFER_REVIEW', 'OFFER_APPROVE', 'OFFER_PUBLISH',
    'PLATFORM_REVENUE'
  );
$function$;

-- ─────────────────────────────────────────────────────────────
-- A. Commission rules
-- ─────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.commission_rules (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  entity_type   text NOT NULL,
  entity_key    text NOT NULL,
  rate          numeric(5,2) NOT NULL,
  currency      text NOT NULL DEFAULT 'SAR',
  effective_from date NOT NULL DEFAULT CURRENT_DATE,
  effective_to  date,
  is_active     boolean NOT NULL DEFAULT true,
  description   text,
  created_by    uuid REFERENCES public.users(id),
  approved_by   uuid REFERENCES public.users(id),
  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT commission_rules_entity_type_check
    CHECK (entity_type IN ('account_type', 'service_type', 'service_category')),
  CONSTRAINT commission_rules_rate_check
    CHECK (rate >= 0 AND rate <= 100),
  CONSTRAINT commission_rules_dates_check
    CHECK (effective_to IS NULL OR effective_to >= effective_from)
);

-- One active rule per entity; historical rows are preserved (never mutated).
CREATE UNIQUE INDEX IF NOT EXISTS commission_rules_one_active_idx
  ON public.commission_rules (entity_type, entity_key)
  WHERE is_active = true;

-- updated_at maintenance (reuses the existing set_updated_at trigger fn).
DROP TRIGGER IF EXISTS trg_commission_rules_updated_at ON public.commission_rules;
CREATE TRIGGER trg_commission_rules_updated_at
  BEFORE UPDATE ON public.commission_rules
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- RLS: no direct reads/rights for authenticated users; data flows through
-- SECURITY DEFINER RPCs. Management API (superuser) retains full access.
ALTER TABLE public.commission_rules ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.commission_rules FROM PUBLIC;
REVOKE ALL ON public.commission_rules FROM anon, authenticated;

-- Seed the canonical commission model (7% provider/driver, 3% merchants).
INSERT INTO public.commission_rules
  (entity_type, entity_key, rate, effective_from, description, created_by, approved_by)
SELECT v.entity_type, v.entity_key, v.rate::numeric, v.effective_from::date,
       v.description, '8a23b719-a923-4a18-bd6e-04972097fb4b'::uuid,
       '8a23b719-a923-4a18-bd6e-04972097fb4b'::uuid
  FROM (VALUES
    ('account_type', 'customer',  '0.00', '2024-01-01', 'Customers never pay commission'),
    ('account_type', 'admin',     '0.00', '2024-01-01', 'Platform staff are exempt'),
    ('account_type', 'driver',    '7.00', '2024-01-01', 'Rideshare and delivery couriers pay 7%'),
    ('account_type', 'provider',  '7.00', '2024-01-01', 'Home-service providers pay 7%'),
    ('account_type', 'merchant',  '3.00', '2024-01-01', 'Merchants pay 3%')
  ) AS v(entity_type, entity_key, rate, effective_from, description)
 WHERE NOT EXISTS (
   SELECT 1 FROM public.commission_rules c
    WHERE c.entity_type = v.entity_type AND c.entity_key = v.entity_key
 );

INSERT INTO public.commission_rules
  (entity_type, entity_key, rate, effective_from, description, created_by, approved_by)
SELECT 'service_category', v.entity_key, v.rate::numeric, v.effective_from::date,
       v.description, '8a23b719-a923-4a18-bd6e-04972097fb4b'::uuid,
       '8a23b719-a923-4a18-bd6e-04972097fb4b'::uuid
  FROM (VALUES
    ('restaurant', '3.00', '2024-01-01', 'Restaurants pay the merchant standard 3%'),
    ('pharmacy',   '3.00', '2024-01-01', 'Pharmacies pay the merchant standard 3%'),
    ('grocery',    '3.00', '2024-01-01', 'Grocers pay the merchant standard 3%'),
    ('marketplace','3.00', '2024-01-01', 'Marketplace sellers pay the merchant standard 3%'),
    ('plumbing',   '7.00', '2024-01-01', 'Plumbing providers pay the provider standard 7%'),
    ('electrical', '7.00', '2024-01-01', 'Electrical providers pay the provider standard 7%'),
    ('cleaning',   '7.00', '2024-01-01', 'Cleaning providers pay the provider standard 7%')
  ) AS v(entity_key, rate, effective_from, description)
 WHERE NOT EXISTS (
   SELECT 1 FROM public.commission_rules c
    WHERE c.entity_type = 'service_category' AND c.entity_key = v.entity_key
 );

-- Per-service-type delivery override: delivery verticals follow the 7%
-- driver standard on the courier side.
INSERT INTO public.commission_rules
  (entity_type, entity_key, rate, effective_from, description, created_by, approved_by)
SELECT 'service_type', v.entity_key, '7.00'::numeric, v.effective_from::date,
       v.description, '8a23b719-a923-4a18-bd6e-04972097fb4b'::uuid,
       '8a23b719-a923-4a18-bd6e-04972097fb4b'::uuid
  FROM (VALUES
    ('ride',                  '2024-01-01', 'Ride hailing'),
    ('food_delivery',         '2024-01-01', 'Food delivery courier'),
    ('grocery_delivery',      '2024-01-01', 'Grocery delivery courier'),
    ('pharmacy_delivery',     '2024-01-01', 'Pharmacy delivery courier'),
    ('marketplace_delivery',  '2024-01-01', 'Marketplace delivery courier'),
    ('courier',               '2024-01-01', 'General courier'),
    ('package_delivery',      '2024-01-01', 'Package delivery courier'),
    ('document_delivery',     '2024-01-01', 'Document delivery courier'),
    ('flower_delivery',       '2024-01-01', 'Flower delivery courier'),
    ('retail_delivery',       '2024-01-01', 'Retail delivery courier')
  ) AS v(entity_key, effective_from, description)
 WHERE NOT EXISTS (
   SELECT 1 FROM public.commission_rules c
    WHERE c.entity_type = 'service_type' AND c.entity_key = v.entity_key
 );

-- ─────────────────────────────────────────────────────────────
-- Server-side commission math (single source of truth)
-- ─────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.get_commission_rate(
  p_account_type text,
  p_service_category text DEFAULT NULL
)
RETURNS numeric
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_rate numeric;
BEGIN
  -- Most specific rule wins: service_category > account_type default.
  IF p_service_category IS NOT NULL THEN
    SELECT c.rate INTO v_rate
      FROM public.commission_rules c
     WHERE c.entity_type = 'service_category'
       AND c.entity_key = p_service_category
       AND c.is_active
       AND c.effective_from <= CURRENT_DATE
       AND (c.effective_to IS NULL OR c.effective_to >= CURRENT_DATE)
     ORDER BY c.effective_from DESC
     LIMIT 1;
    IF v_rate IS NOT NULL THEN
      RETURN v_rate;
    END IF;
  END IF;
  SELECT c.rate INTO v_rate
    FROM public.commission_rules c
   WHERE c.entity_type = 'account_type'
     AND c.entity_key = COALESCE(p_account_type, 'customer')
     AND c.is_active
     AND c.effective_from <= CURRENT_DATE
     AND (c.effective_to IS NULL OR c.effective_to >= CURRENT_DATE)
   ORDER BY c.effective_from DESC
   LIMIT 1;
  RETURN v_rate;
END;
$$;

CREATE OR REPLACE FUNCTION public.calculate_commission(
  p_amount numeric,
  p_rate numeric
)
RETURNS numeric
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT ROUND(COALESCE(p_amount, 0) * COALESCE(p_rate, 0) / 100.0, 2);
$$;

COMMENT ON FUNCTION public.get_commission_rate(text, text) IS
  'Server-side commission rate (049). Most specific rule wins: '
  'service_category, then account_type default. Source of truth for 7%/3%.';
COMMENT ON FUNCTION public.calculate_commission(numeric, numeric) IS
  'Applies a commission rate to an amount. Server-side only (049).';

-- ─────────────────────────────────────────────────────────────
-- platform_commissions: per-transaction ledger with rate snapshot
-- ─────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.platform_commissions (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  member_id         uuid NOT NULL REFERENCES public.users(id),
  reference_type    text NOT NULL,
  reference_id      uuid NOT NULL,
  gross_amount      numeric(12,2) NOT NULL,
  commission_rate   numeric(5,2) NOT NULL,
  commission_amount numeric(12,2) NOT NULL,
  net_amount        numeric(12,2) NOT NULL,
  currency          text NOT NULL DEFAULT 'SAR',
  status            text NOT NULL DEFAULT 'computed',
  fulfilled_at      timestamptz,
  created_by        uuid REFERENCES public.users(id),
  created_at        timestamptz NOT NULL DEFAULT now(),
  updated_at        timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT platform_commissions_reference_type_check
    CHECK (reference_type IN ('order', 'ride', 'service_booking')),
  CONSTRAINT platform_commissions_status_check
    CHECK (status IN ('computed', 'settled', 'reversed')),
  CONSTRAINT platform_commissions_reference_unique
    UNIQUE (reference_type, reference_id)
);

DROP TRIGGER IF EXISTS trg_platform_commissions_updated_at ON public.platform_commissions;
CREATE TRIGGER trg_platform_commissions_updated_at
  BEFORE UPDATE ON public.platform_commissions
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

ALTER TABLE public.platform_commissions ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.platform_commissions FROM PUBLIC;
REVOKE ALL ON public.platform_commissions FROM anon, authenticated;

CREATE OR REPLACE FUNCTION public.platform_commission_for_reference(
  p_reference_type text,
  p_reference_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_uid           uuid := auth.uid();
  v_member_id     uuid;
  v_account_type  text;
  v_category      text;
  v_gross         numeric;
  v_rate          numeric;
  v_commission    numeric;
  v_net           numeric;
BEGIN
  IF v_uid IS NULL THEN
    RETURN NULL;
  END IF;
  IF NOT (public._is_owner_uid(v_uid)
          OR public.has_permission('MEMBER_VIEW', NULL)) THEN
    RETURN NULL;
  END IF;

  IF p_reference_type = 'order' THEN
    SELECT m.owner_user_id, 'merchant', m.type, o.total_amount
      INTO v_member_id, v_account_type, v_category, v_gross
      FROM public.orders o
      JOIN public.merchants m ON m.id = o.merchant_id
     WHERE o.id = p_reference_id;
  ELSIF p_reference_type = 'ride' THEN
    SELECT d.user_id, 'driver', NULL, COALESCE(r.fare, r.base_fare)
      INTO v_member_id, v_account_type, v_category, v_gross
      FROM public.rides r
      JOIN public.drivers d ON d.id = r.driver_id
     WHERE r.id = p_reference_id;
  ELSIF p_reference_type = 'service_booking' THEN
    SELECT sp.user_id, 'provider', sb.category_type,
           COALESCE(sb.final_price, sb.estimated_price)
      INTO v_member_id, v_account_type, v_category, v_gross
      FROM public.service_bookings sb
      JOIN public.service_providers sp ON sp.id = sb.provider_id
     WHERE sb.id = p_reference_id;
  END IF;

  IF v_member_id IS NULL THEN
    RETURN NULL;
  END IF;

  v_gross := COALESCE(v_gross, 0);
  v_rate  := public.get_commission_rate(v_account_type, v_category);
  IF v_rate IS NULL THEN
    RETURN NULL;
  END IF;
  v_commission := public.calculate_commission(v_gross, v_rate);
  v_net        := ROUND(v_gross - v_commission, 2);

  INSERT INTO public.platform_commissions
    (member_id, reference_type, reference_id, gross_amount, commission_rate,
     commission_amount, net_amount, currency, created_by)
  VALUES
    (v_member_id, p_reference_type, p_reference_id, v_gross, v_rate,
     v_commission, v_net, 'SAR', v_uid)
  ON CONFLICT (reference_type, reference_id) DO NOTHING;  -- preserve first snapshot

  RETURN jsonb_build_object(
    'member_id',       v_member_id,
    'reference_type',  p_reference_type,
    'reference_id',    p_reference_id,
    'account_type',    v_account_type,
    'service_category', v_category,
    'gross_amount',    v_gross,
    'commission_rate', v_rate,
    'commission_amount', v_commission,
    'net_amount',      v_net,
    'currency',        'SAR'
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.platform_revenue_overview(
  p_period text DEFAULT 'month',
  p_service_category text DEFAULT NULL,
  p_from date DEFAULT NULL,
  p_to date DEFAULT NULL
)
RETURNS TABLE (
  period_start    timestamptz,
  service_category text,
  account_type    text,
  gross_amount    numeric,
  transaction_count bigint,
  commission_rate numeric,
  commission_amount numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_uid uuid := auth.uid();
BEGIN
  IF v_uid IS NULL THEN
    RETURN;
  END IF;
  IF NOT (public._is_owner_uid(v_uid)
          OR public.has_permission('PLATFORM_REVENUE', NULL)) THEN
    RETURN;
  END IF;

  RETURN QUERY
  WITH source AS (
    SELECT 'order'::text AS ref_type, o.created_at AS happened_at,
           m.owner_user_id AS member_id, 'merchant'::text AS account_type,
           m.type AS category, o.total_amount AS gross
      FROM public.orders o
      JOIN public.merchants m ON m.id = o.merchant_id
     WHERE o.status = 'delivered' AND o.payment_status = 'paid'
    UNION ALL
    SELECT 'ride', r.created_at, d.user_id, 'driver',
           NULLIF(r.service_type, ''), COALESCE(r.fare, r.base_fare, 0)
      FROM public.rides r
      JOIN public.drivers d ON d.id = r.driver_id
     WHERE r.status = 'completed' AND r.payment_status = 'paid'
    UNION ALL
    SELECT 'service_booking', sb.created_at, sb.provider_id, 'provider',
           sb.category_type, COALESCE(sb.final_price, sb.estimated_price, 0)
      FROM public.service_bookings sb
     WHERE sb.status = 'completed'
  )
  SELECT date_trunc(p_period, s.happened_at)::timestamptz,
         COALESCE(s.category, 'general'),
         s.account_type,
         COALESCE(SUM(s.gross), 0),
         COUNT(*)::bigint,
         public.get_commission_rate(s.account_type, s.category),
         ROUND(COALESCE(SUM(s.gross), 0)
               * public.get_commission_rate(s.account_type, s.category) / 100.0, 2)
    FROM source s
   WHERE (p_from IS NULL OR s.happened_at >= p_from)
     AND (p_to IS NULL OR s.happened_at < p_to + interval '1 day')
     AND (p_service_category IS NULL
          OR COALESCE(s.category, 'general') = p_service_category)
   GROUP BY date_trunc(p_period, s.happened_at)::timestamptz,
            s.category, s.account_type
   ORDER BY 1 DESC, 3;
END;
$$;

COMMENT ON FUNCTION public.platform_commission_for_reference(text, uuid) IS
  'Computes and snapshots the platform commission for an order/ride/booking. '
  'Snapshot is immutable (first write wins) so historical revenue never drifts.';
COMMENT ON FUNCTION public.platform_revenue_overview(text, text, date, date) IS
  'Ad-hoc GMV + platform revenue (commission) by period and category from real '
  'completed+paid transactions. Owner/admins with PLATFORM_REVENUE only.';

-- ─────────────────────────────────────────────────────────────
-- B. Operations Center RPCs
-- ─────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public._region_label_path(p_region_id uuid)
RETURNS text
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  WITH RECURSIVE chain AS (
    SELECT r.id, r.parent_region_id,
           COALESCE(NULLIF(r.name_en, ''), NULLIF(r.name_ar, '')) AS nm,
           1 AS depth
      FROM public.regions r
     WHERE r.id = p_region_id
    UNION ALL
    SELECT r.id, r.parent_region_id,
           COALESCE(NULLIF(r.name_en, ''), NULLIF(r.name_ar, '')),
           c.depth + 1
      FROM public.regions r
      JOIN chain c ON r.id = c.parent_region_id
  )
  SELECT string_agg(nm, ' / ' ORDER BY depth DESC)
    FROM chain
   WHERE nm IS NOT NULL;
$$;

-- The platform member list. Region-scoped to the caller's assignments,
-- searchable/filterable/sortable, keyset-paginated (created_at, id).
CREATE OR REPLACE FUNCTION public.member_ops_list(
  p_search text DEFAULT NULL,
  p_role text DEFAULT NULL,
  p_user_type text DEFAULT NULL,
  p_account_status text DEFAULT NULL,
  p_verification_status text DEFAULT NULL,
  p_service_category text DEFAULT NULL,
  p_region_id uuid DEFAULT NULL,
  p_sanction_status text DEFAULT NULL,
  p_sort text DEFAULT 'newest',
  p_cursor timestamptz DEFAULT NULL,
  p_cursor_id uuid DEFAULT NULL,
  p_offset int DEFAULT 0,
  p_limit int DEFAULT 25
)
RETURNS TABLE (
  id uuid,
  full_name text,
  email text,
  phone text,
  avatar_url text,
  username text,
  role text,
  user_type text,
  account_status text,
  verification_status text,
  region_id uuid,
  region_label text,
  last_seen_at timestamptz,
  is_online boolean,
  service_types text[],
  service_categories text[],
  orders_count bigint,
  rides_count bigint,
  bookings_count bigint,
  wallet_balance numeric,
  wallet_currency text,
  active_sanctions_count bigint,
  created_at timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_uid    uuid := auth.uid();
  v_limit  int := LEAST(COALESCE(p_limit, 25), 100);
  v_offset int := GREATEST(COALESCE(p_offset, 0), 0);
  v_admin_scoped boolean;
BEGIN
  IF v_uid IS NULL THEN
    RETURN;
  END IF;
  IF NOT (public._is_owner_uid(v_uid) OR public.has_permission('MEMBER_VIEW', NULL)) THEN
    RETURN;
  END IF;

  SELECT EXISTS (
    SELECT 1 FROM public.admin_region_assignments WHERE admin_id = v_uid
  ) INTO v_admin_scoped;

  RETURN QUERY
  SELECT u.id,
         u.full_name,
         u.email,
         u.phone,
         u.avatar_url,
         u.username,
         u.role,
         u.user_type,
         COALESCE(u.account_status, 'active'),
         COALESCE(u.verification_status, 'unverified'),
         up.region_id,
         CASE WHEN up.region_id IS NULL THEN NULL
              ELSE public._region_label_path(up.region_id) END,
         GREATEST(
           (SELECT MAX(lu.recorded_at) FROM public.location_updates lu WHERE lu.user_id = u.id),
           (SELECT MAX(nt.last_seen_at)   FROM public.notification_tokens nt WHERE nt.user_id = u.id)
         ),
         EXISTS (
           SELECT 1 FROM public.drivers d WHERE d.user_id = u.id AND d.is_online
         ) OR EXISTS (
           SELECT 1 FROM public.service_providers sp WHERE sp.user_id = u.id AND sp.is_available
         ),
         ARRAY(
           SELECT DISTINCT st FROM (
             SELECT UNNEST(d.service_types) AS st
               FROM public.drivers d WHERE d.user_id = u.id
             UNION
             SELECT sp.category_type
               FROM public.service_providers sp WHERE sp.user_id = u.id
           ) s WHERE st IS NOT NULL
         ),
         ARRAY(
           SELECT DISTINCT ct FROM (
             SELECT m.type AS ct FROM public.merchants m WHERE m.owner_user_id = u.id
             UNION
             SELECT sp.category_type FROM public.service_providers sp WHERE sp.user_id = u.id
           ) c WHERE ct IS NOT NULL
         ),
         (SELECT COUNT(*) FROM public.orders o WHERE o.user_id = u.id),
         (SELECT COUNT(*) FROM public.rides r WHERE r.rider_id = u.id),
         (SELECT COUNT(*) FROM public.service_bookings b WHERE b.user_id = u.id),
         (SELECT w.balance FROM public.wallets w WHERE w.user_id = u.id),
         (SELECT w.currency FROM public.wallets w WHERE w.user_id = u.id),
         (SELECT COUNT(*) FROM public.sanctions s
           WHERE s.target_user_id = u.id AND s.is_active),
         u.created_at
    FROM public.users u
    LEFT JOIN LATERAL (
      SELECT up.user_id AS user_id, up.region_id AS region_id
        FROM public.user_region_preferences up
       WHERE up.user_id = u.id
       ORDER BY up.updated_at DESC
       LIMIT 1
    ) up ON true
   WHERE (p_search IS NULL
           OR u.full_name ILIKE '%' || p_search || '%'
           OR u.email ILIKE '%' || p_search || '%'
           OR u.phone ILIKE '%' || p_search || '%'
           OR u.username ILIKE '%' || p_search || '%')
     AND (p_role IS NULL OR u.role = p_role)
     AND (p_user_type IS NULL OR u.user_type = p_user_type)
     AND (p_account_status IS NULL
           OR COALESCE(u.account_status, 'active') = p_account_status)
     AND (p_verification_status IS NULL
           OR COALESCE(u.verification_status, 'unverified') = p_verification_status)
     AND (p_region_id IS NULL OR up.region_id = p_region_id)
     AND (p_sanction_status IS NULL
           OR (p_sanction_status = 'active'
               AND EXISTS (SELECT 1 FROM public.sanctions s
                            WHERE s.target_user_id = u.id AND s.is_active))
           OR (p_sanction_status = 'none'
               AND NOT EXISTS (SELECT 1 FROM public.sanctions s
                                WHERE s.target_user_id = u.id AND s.is_active)))
     AND (p_service_category IS NULL
           OR EXISTS (SELECT 1 FROM public.merchants m
                       WHERE m.owner_user_id = u.id AND m.type = p_service_category)
           OR EXISTS (SELECT 1 FROM public.service_providers sp
                       WHERE sp.user_id = u.id AND sp.category_type = p_service_category)
           OR EXISTS (SELECT 1 FROM public.drivers d
                       WHERE d.user_id = u.id AND p_service_category = ANY(d.service_types)))
     AND (NOT v_admin_scoped OR up.region_id IS NULL
           OR public._region_in_scope(v_uid, up.region_id))
     AND (p_cursor IS NULL
           OR u.created_at < p_cursor
           OR (u.created_at = p_cursor AND u.id < p_cursor_id))
    ORDER BY
      CASE WHEN p_sort = 'oldest' THEN u.created_at END ASC NULLS LAST,
      CASE WHEN COALESCE(p_sort, 'newest') <> 'oldest' THEN u.created_at END
        DESC NULLS LAST,
      CASE p_sort WHEN 'name' THEN u.full_name END ASC NULLS LAST,
      CASE p_sort WHEN 'orders'
            THEN (SELECT COUNT(*)::text FROM public.orders o WHERE o.user_id = u.id)
        END DESC NULLS LAST,
      CASE p_sort WHEN 'wallet'
            THEN (SELECT w.balance::text FROM public.wallets w WHERE w.user_id = u.id)
        END DESC NULLS LAST,
      u.id DESC
    LIMIT v_limit OFFSET v_offset;
END;
$$;

CREATE OR REPLACE FUNCTION public.member_ops_count(
  p_search text DEFAULT NULL,
  p_role text DEFAULT NULL,
  p_user_type text DEFAULT NULL,
  p_account_status text DEFAULT NULL,
  p_verification_status text DEFAULT NULL,
  p_service_category text DEFAULT NULL,
  p_region_id uuid DEFAULT NULL,
  p_sanction_status text DEFAULT NULL
)
RETURNS bigint
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_admin_scoped boolean;
  v_count bigint;
BEGIN
  IF v_uid IS NULL THEN
    RETURN 0;
  END IF;
  IF NOT (public._is_owner_uid(v_uid) OR public.has_permission('MEMBER_VIEW', NULL)) THEN
    RETURN 0;
  END IF;

  SELECT EXISTS (
    SELECT 1 FROM public.admin_region_assignments WHERE admin_id = v_uid
  ) INTO v_admin_scoped;

  SELECT COUNT(*) INTO v_count
    FROM public.users u
    LEFT JOIN LATERAL (
      SELECT region_id FROM public.user_region_preferences up
       WHERE up.user_id = u.id ORDER BY up.updated_at DESC LIMIT 1
    ) up ON true
   WHERE (p_search IS NULL
           OR u.full_name ILIKE '%' || p_search || '%'
           OR u.email ILIKE '%' || p_search || '%'
           OR u.phone ILIKE '%' || p_search || '%'
           OR u.username ILIKE '%' || p_search || '%')
     AND (p_role IS NULL OR u.role = p_role)
     AND (p_user_type IS NULL OR u.user_type = p_user_type)
     AND (p_account_status IS NULL
           OR COALESCE(u.account_status, 'active') = p_account_status)
     AND (p_verification_status IS NULL
           OR COALESCE(u.verification_status, 'unverified') = p_verification_status)
     AND (p_region_id IS NULL OR up.region_id = p_region_id)
     AND (p_sanction_status IS NULL
           OR (p_sanction_status = 'active'
               AND EXISTS (SELECT 1 FROM public.sanctions s
                            WHERE s.target_user_id = u.id AND s.is_active))
           OR (p_sanction_status = 'none'
               AND NOT EXISTS (SELECT 1 FROM public.sanctions s
                                WHERE s.target_user_id = u.id AND s.is_active)))
     AND (NOT v_admin_scoped OR up.region_id IS NULL
           OR public._region_in_scope(v_uid, up.region_id));

  RETURN v_count;
END;
$$;

CREATE OR REPLACE FUNCTION public.get_member_ops_profile(p_member_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_uid          uuid := auth.uid();
  v_member_regid uuid;
  v_can_loc      boolean;
  v_can_chat     boolean;
  v_can_docs     boolean;
  v_can_mod      boolean;
  v_exists       boolean;
BEGIN
  IF v_uid IS NULL THEN
    RETURN NULL;
  END IF;

  SELECT region_id INTO v_member_regid
    FROM public.user_region_preferences
   WHERE user_id = p_member_id
   ORDER BY updated_at DESC LIMIT 1;

  IF NOT public.has_permission('MEMBER_VIEW', v_member_regid) THEN
    RETURN NULL;
  END IF;

  SELECT EXISTS (
    SELECT 1 FROM public.users WHERE id = p_member_id
  ) INTO v_exists;
  IF NOT v_exists THEN
    RETURN NULL;
  END IF;

  v_can_loc  := public.has_permission('MEMBER_VIEW_LOCATION', v_member_regid);
  v_can_chat := public.has_permission('MEMBER_VIEW_CHAT_HISTORY', v_member_regid);
  v_can_docs := public.has_permission('MEMBER_VIEW_DOCUMENTS', v_member_regid);
  v_can_mod  := public.has_permission('MEMBER_MODERATE', v_member_regid);

  RETURN jsonb_build_object(
    'member', (
      SELECT jsonb_build_object(
        'id', u.id, 'full_name', u.full_name, 'email', u.email, 'phone', u.phone,
        'avatar_url', u.avatar_url, 'username', u.username,
        'role', u.role, 'user_type', u.user_type,
        'account_status', COALESCE(u.account_status, 'active'),
        'verification_status', COALESCE(u.verification_status, 'unverified'),
        'language', u.language, 'is_onboarded', u.is_onboarded,
        'date_of_birth', u.date_of_birth,
        'created_at', u.created_at, 'updated_at', u.updated_at)
        FROM public.users u WHERE u.id = p_member_id
    ),
    'region', (
      SELECT jsonb_build_object(
        'region_id', up.region_id,
        'label', public._region_label_path(up.region_id))
        FROM public.user_region_preferences up
       WHERE up.user_id = p_member_id ORDER BY up.updated_at DESC LIMIT 1
    ),
    'location', CASE WHEN v_can_loc THEN (
      SELECT jsonb_build_object(
        'latitude', l.latitude, 'longitude', l.longitude,
        'accuracy', l.accuracy, 'recorded_at', l.recorded_at,
        'is_moving', l.is_moving)
        FROM public.location_updates l
       WHERE l.user_id = p_member_id
       ORDER BY l.recorded_at DESC LIMIT 1)
      ELSE NULL END,
    'last_seen', (
      SELECT GREATEST(
        (SELECT MAX(recorded_at) FROM public.location_updates lu WHERE lu.user_id = p_member_id),
        (SELECT MAX(last_seen_at) FROM public.notification_tokens nt WHERE nt.user_id = p_member_id))
    ),
    'driver', (
      SELECT jsonb_build_object(
        'id', id, 'vehicle_type', vehicle_type, 'vehicle_plate', vehicle_plate,
        'is_online', is_online, 'is_verified', is_verified,
        'verification_status', verification_status,
        'status', status, 'rating', rating, 'total_deliveries', total_deliveries,
        'total_trips', total_trips, 'earnings_balance', earnings_balance,
        'background_check_status', background_check_status,
        'service_types', service_types)
        FROM public.drivers WHERE user_id = p_member_id
    ),
    'merchants', COALESCE((
      SELECT jsonb_agg(jsonb_build_object(
        'id', id, 'name', name, 'type', type, 'status', status,
        'rating', rating, 'total_orders', total_orders,
        'delivery_fee', delivery_fee, 'min_order', min_order,
        'is_featured', is_featured))
        FROM public.merchants WHERE owner_user_id = p_member_id)
    , '[]'::jsonb),
    'providers', COALESCE((
      SELECT jsonb_agg(jsonb_build_object(
        'id', id, 'name', name, 'category_type', category_type,
        'is_verified', is_verified, 'is_available', is_available,
        'rating', rating, 'rating_count', rating_count,
        'hourly_rate', hourly_rate, 'fixed_price_min', fixed_price_min,
        'fixed_price_max', fixed_price_max, 'city', city))
        FROM public.service_providers WHERE user_id = p_member_id)
    , '[]'::jsonb),
    'orders', COALESCE((
      SELECT jsonb_agg(j)
        FROM (
          SELECT jsonb_build_object(
            'id', id, 'merchant_id', merchant_id, 'driver_id', driver_id,
            'status', status, 'payment_status', payment_status,
            'total_amount', total_amount, 'created_at', created_at) AS j
          FROM public.orders WHERE user_id = p_member_id
          ORDER BY created_at DESC LIMIT 10) s)
    , '[]'::jsonb),
    'rides', COALESCE((
      SELECT jsonb_agg(j)
        FROM (
          SELECT jsonb_build_object(
            'id', id, 'service_type', service_type, 'status', status,
            'fare', fare, 'driver_rating', driver_rating, 'created_at', created_at) AS j
          FROM public.rides WHERE rider_id = p_member_id
          ORDER BY created_at DESC LIMIT 10) s)
    , '[]'::jsonb),
    'bookings', COALESCE((
      SELECT jsonb_agg(j)
        FROM (
          SELECT jsonb_build_object(
            'id', id, 'category_type', category_type, 'status', status,
            'provider_name', provider_name, 'final_price', final_price,
            'created_at', created_at) AS j
          FROM public.service_bookings WHERE user_id = p_member_id
          ORDER BY created_at DESC LIMIT 10) s)
    , '[]'::jsonb),
    'wallet', (
      SELECT jsonb_build_object(
        'balance', w.balance, 'currency', w.currency,
        'transactions', COALESCE((
          SELECT jsonb_agg(j)
            FROM (
              SELECT jsonb_build_object(
                'id', t.id, 'type', t.type, 'amount', t.amount,
                'reference_type', t.reference_type, 'balance_after', t.balance_after,
                'created_at', t.created_at) AS j
              FROM public.wallet_transactions t WHERE t.wallet_id = w.id
              ORDER BY t.created_at DESC LIMIT 10) s)
        , '[]'::jsonb))
        FROM public.wallets w WHERE w.user_id = p_member_id
    ),
    'financials', (
      SELECT jsonb_build_object(
        'gross_orders', COALESCE(SUM(o.total_amount), 0),
        'orders_count', COUNT(o.id),
        'commission_rate', public.get_commission_rate(u.user_type, NULL),
        'commission_estimated', ROUND(COALESCE(SUM(o.total_amount), 0)
                                  * COALESCE(public.get_commission_rate(u.user_type, NULL), 0) / 100.0, 2),
        'commissions', COALESCE((
          SELECT jsonb_agg(j)
            FROM (
              SELECT jsonb_build_object(
                'reference_type', c.reference_type, 'gross_amount', c.gross_amount,
                'commission_rate', c.commission_rate, 'commission_amount', c.commission_amount,
                'net_amount', c.net_amount, 'status', c.status, 'created_at', c.created_at) AS j
              FROM public.platform_commissions c WHERE c.member_id = p_member_id
              ORDER BY c.created_at DESC LIMIT 10) s)
        , '[]'::jsonb))
        FROM public.users u
        LEFT JOIN public.orders o ON o.user_id = u.id
       WHERE u.id = p_member_id
       GROUP BY u.user_type
    ),
    'active_sanctions', COALESCE((
      SELECT jsonb_agg(jsonb_build_object(
        'id', id, 'sanction_type', sanction_type, 'reason', reason,
        'amount', amount, 'start_date', start_date, 'end_date', end_date,
        'is_active', is_active, 'issued_by', issued_by, 'created_at', created_at))
        FROM public.sanctions
       WHERE target_user_id = p_member_id AND is_active)
    , '[]'::jsonb),
    'complaints', (
      SELECT jsonb_build_object(
        'filed_count', (SELECT COUNT(*) FROM public.complaints WHERE complainant_id = p_member_id),
        'received_count', (SELECT COUNT(*) FROM public.complaints WHERE respondent_id = p_member_id),
        'related', COALESCE((
          SELECT jsonb_agg(j)
            FROM (
              SELECT jsonb_build_object(
                'id', id, 'complaint_type', complaint_type, 'category', category,
                'status', status, 'priority', priority, 'subject', subject, 'created_at', created_at) AS j
              FROM public.complaints
             WHERE complainant_id = p_member_id OR respondent_id = p_member_id
             ORDER BY created_at DESC LIMIT 10) s)
        , '[]'::jsonb))
    ),
    'support', (
      SELECT jsonb_build_object(
        'rooms_count', (SELECT COUNT(*) FROM public.chat_rooms
                         WHERE p_member_id = ANY(participant_ids)),
        'rooms', COALESCE((
          SELECT jsonb_agg(j)
            FROM (
              SELECT jsonb_build_object(
                'id', id, 'room_type', room_type, 'status', status,
                'priority', priority, 'last_message_at', last_message_at, 'created_at', created_at) AS j
              FROM public.chat_rooms
             WHERE p_member_id = ANY(participant_ids)
             ORDER BY last_message_at DESC NULLS LAST LIMIT 10) s)
        , '[]'::jsonb))
    ),
    'timeline', COALESCE((
      SELECT jsonb_agg(j)
        FROM (
          SELECT jsonb_build_object(
            'id', id, 'event_type', event_type, 'title', title,
            'payload', payload, 'created_at', created_at) AS j
          FROM public.member_events WHERE user_id = p_member_id
          ORDER BY created_at DESC LIMIT 20) s)
    , '[]'::jsonb),
    'permissions', jsonb_build_object(
      'can_view_location',   v_can_loc,
      'can_view_chat',       v_can_chat,
      'can_view_documents',  v_can_docs,
      'can_moderate',        v_can_mod
    )
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.member_financial_summary(p_member_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_member_regid uuid;
BEGIN
  IF v_uid IS NULL THEN
    RETURN NULL;
  END IF;
  SELECT region_id INTO v_member_regid
    FROM public.user_region_preferences
   WHERE user_id = p_member_id ORDER BY updated_at DESC LIMIT 1;
  IF NOT public.has_permission('MEMBER_VIEW', v_member_regid) THEN
    RETURN NULL;
  END IF;

  RETURN jsonb_build_object(
    'wallet', (
      SELECT jsonb_build_object('balance', balance, 'currency', currency)
        FROM public.wallets WHERE user_id = p_member_id
    ),
    'ledger', COALESCE((
      SELECT jsonb_agg(j)
        FROM (
          SELECT jsonb_build_object(
            'id', t.id, 'type', t.type, 'amount', t.amount,
            'reference_type', t.reference_type, 'reference_id', t.reference_id,
            'balance_after', t.balance_after, 'description', t.description, 'created_at', t.created_at) AS j
          FROM public.wallet_transactions t
          JOIN public.wallets w ON w.id = t.wallet_id
         WHERE w.user_id = p_member_id
         ORDER BY t.created_at DESC LIMIT 25) s)
    , '[]'::jsonb),
    'riders_driver', (
      SELECT jsonb_build_object(
        'earnings_balance', earnings_balance,
        'gross_rides', COALESCE(SUM(r.gross), 0),
        'rides_count', COUNT(r.ride_id))
        FROM public.drivers d
        LEFT JOIN LATERAL (
          SELECT r.id AS ride_id, COALESCE(r.fare, r.base_fare, 0) AS gross
            FROM public.rides r
           WHERE r.driver_id = d.user_id AND r.status = 'completed'
        ) r ON true
       WHERE d.user_id = p_member_id
       GROUP BY earnings_balance
    ),
    'commissions', COALESCE((
      SELECT jsonb_agg(j)
        FROM (
          SELECT jsonb_build_object(
            'reference_type', c.reference_type, 'reference_id', c.reference_id,
            'gross_amount', c.gross_amount, 'commission_rate', c.commission_rate,
            'commission_amount', c.commission_amount, 'net_amount', c.net_amount,
            'status', c.status, 'created_at', c.created_at) AS j
          FROM public.platform_commissions c WHERE c.member_id = p_member_id
          ORDER BY c.created_at DESC LIMIT 25) s)
    , '[]'::jsonb)
  );
END;
$$;

COMMENT ON FUNCTION public.member_ops_list(text, text, text, text, text, text, uuid, text, text, timestamptz, uuid, int, int) IS
  'Platform member list for the Operations Center (049). Supersedes '
  'list_members: richer rows (avatar, user_type, region label, online, '
  'last_seen, service arrays, order/ride/booking counts, wallet, sanctions), '
  'server-side search/filter/sort, and keyset pagination. Scope: owner=global, '
  'admins without assignments=global, admins with assignments=their regions + '
  'descendants (up.region_id NULL members remain visible).';
COMMENT ON FUNCTION public.member_ops_count(text, text, text, text, text, text, uuid, text) IS
  'Total matching member count for member_ops_list (049). Same filters/scope.';
COMMENT ON FUNCTION public.get_member_ops_profile(uuid) IS
  'Full sectioned member profile for the Operations Center drawer (049). '
  'Sections are permission-gated (location/chat/documents/moderate).';
COMMENT ON FUNCTION public.member_financial_summary(uuid) IS
  'Wallet + earnings + commission ledger for a member (049). Read-only.';

-- ─────────────────────────────────────────────────────────────
-- C. Performance indexes (Phase 21)
-- ─────────────────────────────────────────────────────────────

CREATE EXTENSION IF NOT EXISTS pg_trgm;

CREATE INDEX IF NOT EXISTS idx_users_full_name_trgm
  ON public.users USING gin (COALESCE(lower(full_name), '') gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_users_email_trgm
  ON public.users USING gin (COALESCE(lower(email), '') gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_users_phone_trgm
  ON public.users USING gin (COALESCE(lower(phone), '') gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_users_username_trgm
  ON public.users USING gin (COALESCE(lower(username), '') gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_users_ops_filters
  ON public.users (role, user_type, account_status, verification_status);
CREATE INDEX IF NOT EXISTS idx_users_created_at
  ON public.users (created_at DESC);
CREATE INDEX IF NOT EXISTS idx_user_region_preferences_user_updated
  ON public.user_region_preferences (user_id, updated_at DESC);
CREATE INDEX IF NOT EXISTS idx_orders_user_created
  ON public.orders (user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_orders_merchant_created
  ON public.orders (merchant_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_rides_rider_created
  ON public.rides (rider_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_rides_driver_created
  ON public.rides (driver_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_bookings_user_created
  ON public.service_bookings (user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_bookings_provider_created
  ON public.service_bookings (provider_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_wallets_user
  ON public.wallets (user_id);
CREATE INDEX IF NOT EXISTS idx_wallet_tx_wallet_created
  ON public.wallet_transactions (wallet_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_sanctions_target_active
  ON public.sanctions (target_user_id, is_active);
CREATE INDEX IF NOT EXISTS idx_drivers_user
  ON public.drivers (user_id);
CREATE INDEX IF NOT EXISTS idx_merchants_owner
  ON public.merchants (owner_user_id);
CREATE INDEX IF NOT EXISTS idx_providers_user
  ON public.service_providers (user_id);
CREATE INDEX IF NOT EXISTS idx_notification_tokens_last_seen
  ON public.notification_tokens (user_id, last_seen_at DESC);
CREATE INDEX IF NOT EXISTS idx_location_updates_user_recorded
  ON public.location_updates (user_id, recorded_at DESC);
CREATE INDEX IF NOT EXISTS idx_member_events_member_created
  ON public.member_events (user_id, created_at DESC);

-- ─────────────────────────────────────────────────────────────
-- D. Grants
-- ─────────────────────────────────────────────────────────────

GRANT EXECUTE ON FUNCTION public.get_commission_rate(text, text)
  TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.calculate_commission(numeric, numeric)
  TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.platform_commission_for_reference(text, uuid)
  TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.platform_revenue_overview(text, text, date, date)
  TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.member_ops_list(text, text, text, text, text, text, uuid, text, text, timestamptz, uuid, int, int)
  TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.member_ops_count(text, text, text, text, text, text, uuid, text)
  TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.get_member_ops_profile(uuid)
  TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.member_financial_summary(uuid)
  TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public._region_label_path(uuid)
  TO authenticated, service_role;

COMMIT;