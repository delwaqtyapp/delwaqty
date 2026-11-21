-- ============================================================================
-- 065_provider_financial_subsystem.sql
-- Additive financial subsystem: Grace, Top-Up, Regional Collection,
-- Platform Settlement, Platform/Admin Receiving Accounts.
--
-- PHASE 1 audit findings (reuse, do NOT duplicate):
--   wallets, wallet_transactions, driver_earnings, withdrawal_requests,
--   platform_commissions (7%/3% authoritative), commission_rules,
--   platform_* financial-intelligence RPCs (owner center),
--   user_region_preferences (account -> region linkage),
--   authz helpers: is_admin(), has_permission(), _is_owner_uid(),
--   is_admin_for_region(), _region_in_scope(), write_audit().
--
-- No new region columns on drivers/service_providers/merchants.
-- Every balance is derived from the ledger. No destructive ops.
-- All RPCs SECURITY DEFINER, search_path = public, pg_temp.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 1. GRACE
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.grace_accounts (
  user_id     uuid PRIMARY KEY REFERENCES public.users(id) ON DELETE CASCADE,
  grace_limit integer NOT NULL DEFAULT 0 CHECK (grace_limit >= 0),
  grace_used  integer NOT NULL DEFAULT 0 CHECK (grace_used >= 0),
  updated_at  timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.grace_audit_log (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  account_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  order_id   uuid,
  before     integer,
  after      integer,
  actor      uuid,
  reason     text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_grace_audit_account ON public.grace_audit_log (account_id);
CREATE INDEX IF NOT EXISTS idx_grace_audit_order   ON public.grace_audit_log (order_id);

ALTER TABLE public.grace_accounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.grace_audit_log  ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "grace_owner_select" ON public.grace_accounts;
CREATE POLICY "grace_owner_select" ON public.grace_accounts
  FOR SELECT USING (user_id = auth.uid() OR public.is_admin());

DROP POLICY IF EXISTS "grace_admin_select" ON public.grace_audit_log;
CREATE POLICY "grace_admin_select" ON public.grace_audit_log
  FOR SELECT USING (account_id = auth.uid() OR public.is_admin());

-- ---------------------------------------------------------------------------
-- 2. TOP-UP REQUESTS
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.topup_requests (
  id                      uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  account_id              uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  region_id               uuid REFERENCES public.regions(id) ON DELETE SET NULL,
  amount                  numeric(12,2) NOT NULL CHECK (amount > 0),
  currency                text NOT NULL DEFAULT 'SAR',
  receiver_admin_id       uuid REFERENCES public.users(id) ON DELETE SET NULL,
  receiver_wallet_snapshot jsonb,
  payment_method          text NOT NULL DEFAULT 'bank_transfer',
  transfer_reference      text,
  proof_path              text,
  message                 text,
  status                  text NOT NULL DEFAULT 'pending'
                            CHECK (status IN ('pending','under_review','approved','rejected','cancelled')),
  created_at              timestamptz NOT NULL DEFAULT now(),
  reviewed_at             timestamptz,
  reviewed_by             uuid REFERENCES public.users(id) ON DELETE SET NULL,
  rejection_reason        text
);

CREATE INDEX IF NOT EXISTS idx_topup_account ON public.topup_requests (account_id);
CREATE INDEX IF NOT EXISTS idx_topup_region  ON public.topup_requests (region_id);
CREATE INDEX IF NOT EXISTS idx_topup_status  ON public.topup_requests (status);

ALTER TABLE public.topup_requests ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "topup_owner_all" ON public.topup_requests;
CREATE POLICY "topup_owner_all" ON public.topup_requests
  FOR ALL USING (account_id = auth.uid())
  WITH CHECK (account_id = auth.uid());

DROP POLICY IF EXISTS "topup_admin_region_select" ON public.topup_requests;
CREATE POLICY "topup_admin_region_select" ON public.topup_requests
  FOR SELECT USING (
    public.is_admin() AND (region_id IS NULL OR public.is_admin_for_region(region_id))
  );

-- ---------------------------------------------------------------------------
-- 3. REGIONAL COLLECTIONS (immutable ledger of received top-ups)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.regional_collections (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  admin_id          uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  region_id         uuid REFERENCES public.regions(id) ON DELETE SET NULL,
  account_id        uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  topup_request_id  uuid NOT NULL REFERENCES public.topup_requests(id) ON DELETE CASCADE,
  amount            numeric(12,2) NOT NULL CHECK (amount > 0),
  currency          text NOT NULL DEFAULT 'SAR',
  reference         text,
  received_at       timestamptz NOT NULL DEFAULT now(),
  status            text NOT NULL DEFAULT 'collected'
                        CHECK (status IN ('collected','settled')),
  settlement_id     uuid REFERENCES public.platform_settlements(id) ON DELETE SET NULL,
  created_at        timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT regional_collections_request_unique UNIQUE (topup_request_id)
);

CREATE INDEX IF NOT EXISTS idx_regional_collections_admin   ON public.regional_collections (admin_id);
CREATE INDEX IF NOT EXISTS idx_regional_collections_region  ON public.regional_collections (region_id);
CREATE INDEX IF NOT EXISTS idx_regional_collections_settle  ON public.regional_collections (settlement_id);

ALTER TABLE public.regional_collections ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "regional_collections_admin_region" ON public.regional_collections;
CREATE POLICY "regional_collections_admin_region" ON public.regional_collections
  FOR SELECT USING (
    public.is_admin() AND (region_id IS NULL OR public.is_admin_for_region(region_id))
  );

-- ---------------------------------------------------------------------------
-- 4. PLATFORM SETTLEMENTS (Regional Admin -> Platform)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.platform_settlements (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  admin_id       uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  region_id      uuid REFERENCES public.regions(id) ON DELETE SET NULL,
  amount         numeric(12,2) NOT NULL CHECK (amount > 0),
  currency       text NOT NULL DEFAULT 'SAR',
  payment_method text NOT NULL DEFAULT 'bank_transfer',
  reference      text,
  proof_path     text,
  message        text,
  status         text NOT NULL DEFAULT 'pending'
                     CHECK (status IN ('pending','under_review','approved','rejected')),
  created_at     timestamptz NOT NULL DEFAULT now(),
  reviewed_at    timestamptz,
  reviewed_by    uuid REFERENCES public.users(id) ON DELETE SET NULL,
  rejection_reason text
);

CREATE INDEX IF NOT EXISTS idx_settlements_admin   ON public.platform_settlements (admin_id);
CREATE INDEX IF NOT EXISTS idx_settlements_region  ON public.platform_settlements (region_id);
CREATE INDEX IF NOT EXISTS idx_settlements_status  ON public.platform_settlements (status);

ALTER TABLE public.platform_settlements ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "settlements_admin_region" ON public.platform_settlements;
CREATE POLICY "settlements_admin_region" ON public.platform_settlements
  FOR SELECT USING (
    public.is_admin() AND (region_id IS NULL OR public.is_admin_for_region(region_id))
  );
DROP POLICY IF EXISTS "settlements_owner_insert" ON public.platform_settlements;
CREATE POLICY "settlements_owner_insert" ON public.platform_settlements
  FOR INSERT WITH CHECK (admin_id = auth.uid());

-- ---------------------------------------------------------------------------
-- 5. PLATFORM RECEIVING ACCOUNTS (Owner-only configuration)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.platform_receiving_accounts (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  method_type    text NOT NULL CHECK (method_type IN ('cash','instapay','vodafone_cash','bank_transfer','other')),
  display_name   text NOT NULL,
  account_name   text,
  account_number text,
  wallet_number  text,
  instructions   text,
  is_active      boolean NOT NULL DEFAULT true,
  created_at     timestamptz NOT NULL DEFAULT now(),
  updated_at     timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.platform_receiving_accounts ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "receiving_accounts_admin_select" ON public.platform_receiving_accounts;
CREATE POLICY "receiving_accounts_admin_select" ON public.platform_receiving_accounts
  FOR SELECT USING (public.is_admin());
DROP POLICY IF EXISTS "receiving_accounts_owner_write" ON public.platform_receiving_accounts;
CREATE POLICY "receiving_accounts_owner_write" ON public.platform_receiving_accounts
  FOR ALL USING (public._is_owner_uid(auth.uid()))
  WITH CHECK (public._is_owner_uid(auth.uid()));

-- ---------------------------------------------------------------------------
-- 6. ADMIN RECEIVING WALLETS (per Regional Admin receiving config)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.admin_receiving_wallets (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  admin_id      uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  region_id     uuid NOT NULL REFERENCES public.regions(id) ON DELETE CASCADE,
  method_type   text NOT NULL CHECK (method_type IN ('cash','instapay','vodafone_cash','bank_transfer','other')),
  wallet_number text,
  account_name  text,
  provider      text,
  is_active     boolean NOT NULL DEFAULT true,
  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT admin_receiving_wallets_one_active UNIQUE (admin_id, region_id, method_type)
    WHERE is_active = true
);

ALTER TABLE public.admin_receiving_wallets ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "admin_receiving_wallets_self_region" ON public.admin_receiving_wallets;
CREATE POLICY "admin_receiving_wallets_self_region" ON public.admin_receiving_wallets
  FOR ALL USING (
    public.is_admin() AND public.is_admin_for_region(region_id)
  )
  WITH CHECK (
    public.is_admin() AND public.is_admin_for_region(region_id)
  );

-- ---------------------------------------------------------------------------
-- 7. INTERNAL HELPER: ensure wallet exists
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public._ensure_wallet(p_user_id uuid)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  SELECT id INTO v_id FROM public.wallets WHERE user_id = p_user_id;
  IF v_id IS NULL THEN
    INSERT INTO public.wallets (user_id, balance, currency)
    VALUES (p_user_id, 0, 'SAR')
    RETURNING id INTO v_id;
  END IF;
  RETURN v_id;
END;
$$;

-- ---------------------------------------------------------------------------
-- 8. GRACE RPCs
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_or_create_grace(p_user_id uuid)
RETURNS public.grace_accounts
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_row public.grace_accounts;
BEGIN
  IF auth.uid() IS NULL THEN
    RETURN NULL;
  END IF;
  IF auth.uid() <> p_user_id AND NOT public.is_admin() THEN
    RETURN NULL;
  END IF;
  SELECT * INTO v_row FROM public.grace_accounts WHERE user_id = p_user_id;
  IF v_row IS NULL THEN
    INSERT INTO public.grace_accounts (user_id) VALUES (p_user_id)
    ON CONFLICT (user_id) DO NOTHING;
    SELECT * INTO v_row FROM public.grace_accounts WHERE user_id = p_user_id;
  END IF;
  RETURN v_row;
END;
$$;

CREATE OR REPLACE FUNCTION public.get_my_grace()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_row public.grace_accounts;
  v_remaining integer;
BEGIN
  IF auth.uid() IS NULL THEN
    RETURN NULL;
  END IF;
  v_row := public.get_or_create_grace(auth.uid());
  v_remaining := GREATEST(0, v_row.grace_limit - v_row.grace_used);
  RETURN jsonb_build_object(
    'user_id', v_row.user_id,
    'grace_limit', v_row.grace_limit,
    'grace_used', v_row.grace_used,
    'grace_remaining', v_remaining
  );
END;
$$;

-- Structured eligibility check used by the order flow.
-- Returns { allowed, code, balance, grace_remaining }
--   code IN ('OK','INSUFFICIENT_BALANCE','GRACE_EXHAUSTED')
CREATE OR REPLACE FUNCTION public.evaluate_order_eligibility(p_amount numeric)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_balance numeric;
  v_grace   public.grace_accounts;
  v_remaining integer;
BEGIN
  IF auth.uid() IS NULL THEN
    RETURN jsonb_build_object('allowed', false, 'code', 'UNAUTHENTICATED');
  END IF;
  SELECT balance INTO v_balance FROM public.wallets WHERE user_id = auth.uid();
  v_balance := COALESCE(v_balance, 0);
  v_grace := public.get_or_create_grace(auth.uid());
  v_remaining := GREATEST(0, v_grace.grace_limit - v_grace.grace_used);

  IF v_balance >= p_amount THEN
    RETURN jsonb_build_object('allowed', true, 'code', 'OK',
      'balance', v_balance, 'grace_remaining', v_remaining);
  END IF;
  IF v_remaining > 0 THEN
    RETURN jsonb_build_object('allowed', true, 'code', 'GRACE_OK',
      'balance', v_balance, 'grace_remaining', v_remaining);
  END IF;
  RETURN jsonb_build_object('allowed', false, 'code', 'INSUFFICIENT_BALANCE',
    'balance', v_balance, 'grace_remaining', 0);
END;
$$;

-- Consume one grace slot atomically for an order. Returns structured result.
-- code IN ('OK','GRACE_EXHAUSTED')
CREATE OR REPLACE FUNCTION public.consume_grace(p_order_id uuid, p_amount numeric)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_grace   public.grace_accounts;
  v_before  integer;
  v_after   integer;
BEGIN
  SELECT * INTO v_grace FROM public.grace_accounts
   WHERE user_id = auth.uid() FOR UPDATE;
  IF v_grace IS NULL THEN
    v_grace := public.get_or_create_grace(auth.uid());
    SELECT * INTO v_grace FROM public.grace_accounts
     WHERE user_id = auth.uid() FOR UPDATE;
  END IF;
  v_before := v_grace.grace_used;
  IF (v_grace.grace_limit - v_grace.grace_used) <= 0 THEN
    RETURN jsonb_build_object('ok', false, 'code', 'GRACE_EXHAUSTED',
      'grace_remaining', 0);
  END IF;
  v_after := v_grace.grace_used + 1;
  UPDATE public.grace_accounts
     SET grace_used = v_after, updated_at = now()
   WHERE user_id = auth.uid();
  INSERT INTO public.grace_audit_log
    (account_id, order_id, before, after, actor, reason, created_at)
  VALUES
    (auth.uid(), p_order_id, v_before, v_after, auth.uid(),
     'grace_consumed', now());
  RETURN jsonb_build_object('ok', true, 'code', 'OK',
    'grace_used', v_after,
    'grace_remaining', GREATEST(0, v_grace.grace_limit - v_after),
    'amount', p_amount);
END;
$$;

-- Release a previously consumed grace slot (order cancelled / refunded).
CREATE OR REPLACE FUNCTION public.release_grace(p_order_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_log public.grace_audit_log;
  v_after integer;
BEGIN
  SELECT * INTO v_log FROM public.grace_audit_log
   WHERE order_id = p_order_id AND account_id = auth.uid()
   ORDER BY created_at DESC LIMIT 1;
  IF v_log IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'code', 'NO_SLOT');
  END IF;
  IF (v_log.after - v_log.before) <= 0 THEN
    RETURN jsonb_build_object('ok', false, 'code', 'ALREADY_RELEASED');
  END IF;
  UPDATE public.grace_accounts
     SET grace_used = GREATEST(0, grace_used - 1), updated_at = now()
   WHERE user_id = auth.uid();
  INSERT INTO public.grace_audit_log
    (account_id, order_id, before, after, actor, reason, created_at)
  VALUES
    (auth.uid(), p_order_id, v_log.after, v_log.before, auth.uid(),
     'grace_released', now());
  SELECT grace_used INTO v_after FROM public.grace_accounts WHERE user_id = auth.uid();
  RETURN jsonb_build_object('ok', true, 'code', 'OK', 'grace_used', v_after);
END;
$$;

-- Admin/Owner set grace limit (region-scoped for admin).
CREATE OR REPLACE FUNCTION public.admin_set_grace(
  p_user_id uuid,
  p_new_limit integer,
  p_reason text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_region uuid;
  v_before integer;
  v_row    public.grace_accounts;
BEGIN
  IF auth.uid() IS NULL OR NOT public.is_admin() THEN
    RETURN jsonb_build_object('ok', false, 'code', 'FORBIDDEN');
  END IF;
  IF p_new_limit < 0 THEN
    RETURN jsonb_build_object('ok', false, 'code', 'INVALID_LIMIT');
  END IF;
  SELECT region_id INTO v_region FROM public.user_region_preferences
   WHERE user_id = p_user_id LIMIT 1;
  IF v_region IS NOT NULL AND NOT public._region_in_scope(auth.uid(), v_region)
     AND NOT public._is_owner_uid(auth.uid()) THEN
    RETURN jsonb_build_object('ok', false, 'code', 'REGION_FORBIDDEN');
  END IF;

  SELECT grace_limit INTO v_before FROM public.grace_accounts WHERE user_id = p_user_id;
  v_row := public.get_or_create_grace(p_user_id);
  v_before := COALESCE(v_before, 0);
  UPDATE public.grace_accounts SET grace_limit = p_new_limit, updated_at = now()
   WHERE user_id = p_user_id;

  INSERT INTO public.grace_audit_log
    (account_id, before, after, actor, reason, created_at)
  VALUES
    (p_user_id, v_before, p_new_limit, auth.uid(),
     COALESCE(p_reason, 'admin_adjustment'), now());

  PERFORM public.write_audit('GRACE_LIMIT_CHANGED', 'grace_accounts', p_user_id::text,
    jsonb_build_object('old', v_before, 'new', p_new_limit,
      'actor', auth.uid(), 'region', v_region, 'reason', p_reason));

  RETURN jsonb_build_object('ok', true, 'code', 'OK',
    'grace_limit', p_new_limit);
END;
$$;

-- ---------------------------------------------------------------------------
-- 9. RECEIVING ACCOUNT RPCs
-- ---------------------------------------------------------------------------
-- Resolve the receiving wallet for the current account's region.
-- Fallback to owner platform receiving accounts when no regional admin wallet.
CREATE OR REPLACE FUNCTION public.resolve_receiver_for_account()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_region uuid;
  v_wallet jsonb;
  v_platform jsonb;
BEGIN
  IF auth.uid() IS NULL THEN
    RETURN NULL;
  END IF;
  SELECT region_id INTO v_region FROM public.user_region_preferences
   WHERE user_id = auth.uid() LIMIT 1;

  SELECT jsonb_build_object(
    'admin_id', w.admin_id, 'region_id', w.region_id,
    'method_type', w.method_type, 'wallet_number', w.wallet_number,
    'account_name', w.account_name, 'provider', w.provider
  ) INTO v_wallet
  FROM public.admin_receiving_wallets w
  WHERE w.is_active
    AND (v_region IS NULL OR w.region_id = v_region)
  ORDER BY w.region_id NULLS LAST
  LIMIT 1;

  IF v_wallet IS NOT NULL THEN
    RETURN jsonb_build_object('source', 'regional_admin', 'receiver', v_wallet,
      'region_id', v_region);
  END IF;

  SELECT jsonb_agg(jsonb_build_object(
    'id', a.id, 'method_type', a.method_type, 'display_name', a.display_name,
    'account_name', a.account_name, 'account_number', a.account_number,
    'wallet_number', a.wallet_number, 'instructions', a.instructions
  )) INTO v_platform
  FROM public.platform_receiving_accounts a
  WHERE a.is_active;

  RETURN jsonb_build_object('source', 'platform', 'receivers', COALESCE(v_platform, '[]'::jsonb),
    'region_id', v_region);
END;
$$;

CREATE OR REPLACE FUNCTION public.owner_create_receiving_account(
  p_method_type text,
  p_display_name text,
  p_account_name text DEFAULT NULL,
  p_account_number text DEFAULT NULL,
  p_wallet_number text DEFAULT NULL,
  p_instructions text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public._is_owner_uid(auth.uid()) THEN
    RAISE EXCEPTION 'Forbidden';
  END IF;
  INSERT INTO public.platform_receiving_accounts
    (method_type, display_name, account_name, account_number, wallet_number, instructions)
  VALUES
    (p_method_type, p_display_name, p_account_name, p_account_number, p_wallet_number, p_instructions)
  RETURNING id INTO v_id;
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.owner_update_receiving_account(
  p_id uuid,
  p_is_active boolean DEFAULT NULL,
  p_display_name text DEFAULT NULL,
  p_account_name text DEFAULT NULL,
  p_account_number text DEFAULT NULL,
  p_wallet_number text DEFAULT NULL,
  p_instructions text DEFAULT NULL
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public._is_owner_uid(auth.uid()) THEN
    RAISE EXCEPTION 'Forbidden';
  END IF;
  UPDATE public.platform_receiving_accounts
     SET is_active = COALESCE(p_is_active, is_active),
         display_name = COALESCE(p_display_name, display_name),
         account_name = COALESCE(p_account_name, account_name),
         account_number = COALESCE(p_account_number, account_number),
         wallet_number = COALESCE(p_wallet_number, wallet_number),
         instructions = COALESCE(p_instructions, instructions),
         updated_at = now()
   WHERE id = p_id;
  RETURN found;
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_create_receiving_wallet(
  p_region_id uuid,
  p_method_type text,
  p_wallet_number text DEFAULT NULL,
  p_account_name text DEFAULT NULL,
  p_provider text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF auth.uid() IS NULL OR NOT public.is_admin() THEN
    RAISE EXCEPTION 'Forbidden';
  END IF;
  IF NOT public.is_admin_for_region(p_region_id) THEN
    RAISE EXCEPTION 'Region forbidden';
  END IF;
  INSERT INTO public.admin_receiving_wallets
    (admin_id, region_id, method_type, wallet_number, account_name, provider)
  VALUES
    (auth.uid(), p_region_id, p_method_type, p_wallet_number, p_account_name, p_provider)
  RETURNING id INTO v_id;
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.list_platform_receiving_accounts()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_admin() THEN
    RETURN NULL;
  END IF;
  RETURN jsonb_build_object('accounts', COALESCE((
    SELECT jsonb_agg(jsonb_build_object(
      'id', id, 'method_type', method_type, 'display_name', display_name,
      'account_name', account_name, 'account_number', account_number,
      'wallet_number', wallet_number, 'instructions', instructions,
      'is_active', is_active))
    FROM public.platform_receiving_accounts
    ORDER BY created_at
  ), '[]'::jsonb));
END;
$$;

-- ---------------------------------------------------------------------------
-- 10. TOP-UP RPCs
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.create_topup_request(
  p_amount numeric,
  p_payment_method text DEFAULT 'bank_transfer',
  p_transfer_reference text DEFAULT NULL,
  p_proof_path text DEFAULT NULL,
  p_message text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_uid    uuid := auth.uid();
  v_region uuid;
  v_wallet jsonb;
  v_rec    jsonb;
  v_admin  uuid;
  v_snap   jsonb;
  v_id     uuid;
BEGIN
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'code', 'UNAUTHENTICATED');
  END IF;
  IF p_amount IS NULL OR p_amount <= 0 THEN
    RETURN jsonb_build_object('ok', false, 'code', 'INVALID_AMOUNT');
  END IF;

  SELECT region_id INTO v_region FROM public.user_region_preferences
   WHERE user_id = v_uid LIMIT 1;

  v_rec := public.resolve_receiver_for_account();
  IF v_rec IS NULL OR v_rec ->> 'source' IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'code', 'NO_RECEIVER');
  END IF;
  IF v_rec ->> 'source' = 'regional_admin' THEN
    v_wallet := v_rec -> 'receiver';
    v_admin := (v_wallet ->> 'admin_id')::uuid;
    v_snap := v_wallet;
  ELSE
    v_snap := jsonb_build_object('platform_receivers', v_rec -> 'receivers');
  END IF;

  INSERT INTO public.topup_requests
    (account_id, region_id, amount, currency, receiver_admin_id,
     receiver_wallet_snapshot, payment_method, transfer_reference, proof_path, message)
  VALUES
    (v_uid, v_region, p_amount, 'SAR', v_admin, v_snap,
     p_payment_method, p_transfer_reference, p_proof_path, p_message)
  RETURNING id INTO v_id;

  RETURN jsonb_build_object('ok', true, 'code', 'OK', 'id', v_id,
    'status', 'pending', 'receiver_source', v_rec ->> 'source');
END;
$$;

CREATE OR REPLACE FUNCTION public.approve_topup_request(p_request_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  r          public.topup_requests;
  v_wallet_id uuid;
  v_balance  numeric;
  v_after    numeric;
  v_region   uuid;
  v_admin    uuid;
  v_coll_id  uuid;
BEGIN
  IF auth.uid() IS NULL OR NOT public.is_admin() THEN
    RETURN jsonb_build_object('ok', false, 'code', 'FORBIDDEN');
  END IF;

  SELECT * INTO r FROM public.topup_requests
   WHERE id = p_request_id FOR UPDATE;
  IF r IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'code', 'NOT_FOUND');
  END IF;
  IF r.status <> 'pending' THEN
    RETURN jsonb_build_object('ok', false, 'code', 'ALREADY_PROCESSED', 'status', r.status);
  END IF;
  -- Self-approval protection: reviewer cannot be the requesting account.
  IF r.account_id = auth.uid() THEN
    RETURN jsonb_build_object('ok', false, 'code', 'SELF_APPROVAL');
  END IF;
  -- Region scoping for the reviewing admin.
  IF r.region_id IS NOT NULL AND NOT public.is_admin_for_region(r.region_id)
     AND NOT public._is_owner_uid(auth.uid()) THEN
    RETURN jsonb_build_object('ok', false, 'code', 'REGION_FORBIDDEN');
  END IF;

  -- Idempotency: a collection already exists for this request.
  IF EXISTS (SELECT 1 FROM public.regional_collections WHERE topup_request_id = r.id) THEN
    RETURN jsonb_build_object('ok', false, 'code', 'ALREADY_CREDITED');
  END IF;

  v_wallet_id := public._ensure_wallet(r.account_id);
  SELECT balance INTO v_balance FROM public.wallets WHERE id = v_wallet_id FOR UPDATE;
  v_after := COALESCE(v_balance, 0) + r.amount;
  UPDATE public.wallets SET balance = v_after, updated_at = now()
   WHERE id = v_wallet_id;
  INSERT INTO public.wallet_transactions
    (wallet_id, type, amount, reference_type, reference_id, description, balance_after)
  VALUES
    (v_wallet_id, 'credit', r.amount, 'topup', r.id,
     'Wallet top-up approved', v_after);

  v_region := r.region_id;
  v_admin := auth.uid();
  INSERT INTO public.regional_collections
    (admin_id, region_id, account_id, topup_request_id, amount, currency, reference)
  VALUES
    (v_admin, v_region, r.account_id, r.id, r.amount, r.currency, r.transfer_reference)
  RETURNING id INTO v_coll_id;

  UPDATE public.topup_requests
     SET status = 'approved', reviewed_at = now(), reviewed_by = auth.uid()
   WHERE id = r.id;

  PERFORM public.write_audit('TOPUP_APPROVED', 'topup_requests', r.id::text,
    jsonb_build_object('account', r.account_id, 'amount', r.amount,
      'admin', v_admin, 'collection', v_coll_id));

  INSERT INTO public.notifications (user_id, title, body, type, data)
  VALUES
    (r.account_id, 'Top-up approved', 'Your wallet was credited with ' ||
       r.amount::text || ' ' || r.currency, 'topup_approved',
     jsonb_build_object('topup_request_id', r.id, 'amount', r.amount));

  RETURN jsonb_build_object('ok', true, 'code', 'OK',
    'wallet_balance', v_after, 'collection_id', v_coll_id);
END;
$$;

CREATE OR REPLACE FUNCTION public.reject_topup_request(
  p_request_id uuid,
  p_reason text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  r public.topup_requests;
BEGIN
  IF auth.uid() IS NULL OR NOT public.is_admin() THEN
    RETURN jsonb_build_object('ok', false, 'code', 'FORBIDDEN');
  END IF;
  SELECT * INTO r FROM public.topup_requests WHERE id = p_request_id FOR UPDATE;
  IF r IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'code', 'NOT_FOUND');
  END IF;
  IF r.status <> 'pending' THEN
    RETURN jsonb_build_object('ok', false, 'code', 'ALREADY_PROCESSED', 'status', r.status);
  END IF;
  UPDATE public.topup_requests
     SET status = 'rejected', reviewed_at = now(), reviewed_by = auth.uid(),
         rejection_reason = p_reason
   WHERE id = r.id;
  PERFORM public.write_audit('TOPUP_REJECTED', 'topup_requests', r.id::text,
    jsonb_build_object('account', r.account_id, 'reason', p_reason));
  RETURN jsonb_build_object('ok', true, 'code', 'OK');
END;
$$;

CREATE OR REPLACE FUNCTION public.get_my_topup_requests()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_uid uuid := auth.uid();
BEGIN
  IF v_uid IS NULL THEN
    RETURN NULL;
  END IF;
  RETURN jsonb_build_object('requests', COALESCE((
    SELECT jsonb_agg(jsonb_build_object(
      'id', id, 'amount', amount, 'currency', currency, 'status', status,
      'payment_method', payment_method, 'transfer_reference', transfer_reference,
      'created_at', created_at, 'reviewed_at', reviewed_at,
      'rejection_reason', rejection_reason))
    FROM public.topup_requests
    WHERE account_id = v_uid
    ORDER BY created_at DESC
  ), '[]'::jsonb));
END;
$$;

CREATE OR REPLACE FUNCTION public.list_region_topup_requests(p_status text DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_uid uuid := auth.uid();
BEGIN
  IF v_uid IS NULL OR NOT public.is_admin() THEN
    RETURN NULL;
  END IF;
  RETURN jsonb_build_object('requests', COALESCE((
    SELECT jsonb_agg(jsonb_build_object(
      'id', t.id, 'account_id', t.account_id, 'region_id', t.region_id,
      'amount', t.amount, 'currency', t.currency, 'status', t.status,
      'payment_method', t.payment_method, 'transfer_reference', t.transfer_reference,
      'proof_path', t.proof_path, 'message', t.message,
      'created_at', t.created_at, 'reviewed_by', t.reviewed_by,
      'rejection_reason', t.rejection_reason))
    FROM public.topup_requests t
    WHERE (p_status IS NULL OR t.status = p_status)
      AND (t.region_id IS NULL OR public.is_admin_for_region(t.region_id))
    ORDER BY t.created_at DESC
  ), '[]'::jsonb));
END;
$$;

-- ---------------------------------------------------------------------------
-- 11. REGIONAL COLLECTION + SETTLEMENT RPCs
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_region_collection_summary()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_region uuid;
  v_today numeric := 0;
  v_week  numeric := 0;
  v_month numeric := 0;
  v_total numeric := 0;
  v_pending numeric := 0;
  v_approved numeric := 0;
  v_rejected numeric := 0;
  v_settled numeric := 0;
  v_outstanding numeric := 0;
BEGIN
  IF v_uid IS NULL OR NOT public.is_admin() THEN
    RETURN NULL;
  END IF;
  -- Primary assigned region (admins may serve several; summarize the first).
  SELECT region_id INTO v_region FROM public.admin_region_assignments
   WHERE admin_id = v_uid LIMIT 1;

  SELECT
    COALESCE(SUM(amount) FILTER (WHERE received_at >= date_trunc('day', now())), 0),
    COALESCE(SUM(amount) FILTER (WHERE received_at >= date_trunc('week', now())), 0),
    COALESCE(SUM(amount) FILTER (WHERE received_at >= date_trunc('month', now())), 0),
    COALESCE(SUM(amount), 0)
  INTO v_today, v_week, v_month, v_total
  FROM public.regional_collections c
  WHERE (v_region IS NULL OR c.region_id = v_region)
    AND (c.region_id IS NULL OR public.is_admin_for_region(c.region_id));

  SELECT
    COALESCE(SUM(amount) FILTER (WHERE t.status = 'pending'), 0),
    COALESCE(SUM(amount) FILTER (WHERE t.status = 'approved'), 0),
    COALESCE(SUM(amount) FILTER (WHERE t.status = 'rejected'), 0),
    COALESCE(SUM(amount) FILTER (WHERE t.status = 'approved'), 0)
  INTO v_pending, v_approved, v_rejected, v_settled
  FROM public.topup_requests t
  WHERE (v_region IS NULL OR t.region_id = v_region)
    AND (t.region_id IS NULL OR public.is_admin_for_region(t.region_id));

  -- Outstanding = collected - approved settlements (immutable ledger math).
  v_outstanding := v_total - COALESCE((
    SELECT SUM(s.amount) FROM public.platform_settlements s
     WHERE s.status = 'approved'
       AND (v_region IS NULL OR s.region_id = v_region)
       AND (s.region_id IS NULL OR public.is_admin_for_region(s.region_id))
  ), 0);

  RETURN jsonb_build_object(
    'region_id', v_region,
    'today', v_today, 'week', v_week, 'month', v_month, 'total', v_total,
    'pending', v_pending, 'approved', v_approved, 'rejected', v_rejected,
    'settled', v_settled, 'outstanding', GREATEST(0, v_outstanding)
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.submit_settlement_request(
  p_amount numeric,
  p_payment_method text DEFAULT 'bank_transfer',
  p_reference text DEFAULT NULL,
  p_proof_path text DEFAULT NULL,
  p_message text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_region uuid;
  v_id uuid;
BEGIN
  IF v_uid IS NULL OR NOT public.is_admin() THEN
    RETURN jsonb_build_object('ok', false, 'code', 'FORBIDDEN');
  END IF;
  IF p_amount IS NULL OR p_amount <= 0 THEN
    RETURN jsonb_build_object('ok', false, 'code', 'INVALID_AMOUNT');
  END IF;
  SELECT region_id INTO v_region FROM public.admin_region_assignments
   WHERE admin_id = v_uid LIMIT 1;

  INSERT INTO public.platform_settlements
    (admin_id, region_id, amount, currency, payment_method, reference, proof_path, message)
  VALUES
    (v_uid, v_region, p_amount, 'SAR', p_payment_method, p_reference, p_proof_path, p_message)
  RETURNING id INTO v_id;
  -- (reference column uses p_reference; fix below)
  UPDATE public.platform_settlements
     SET reference = p_reference, message = p_message
   WHERE id = v_id;

  RETURN jsonb_build_object('ok', true, 'code', 'OK', 'id', v_id, 'status', 'pending');
END;
$$;

CREATE OR REPLACE FUNCTION public.approve_settlement_request(p_settlement_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  s public.platform_settlements;
BEGIN
  IF auth.uid() IS NULL OR NOT public._is_owner_uid(auth.uid()) THEN
    RETURN jsonb_build_object('ok', false, 'code', 'FORBIDDEN');
  END IF;
  SELECT * INTO s FROM public.platform_settlements
   WHERE id = p_settlement_id FOR UPDATE;
  IF s IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'code', 'NOT_FOUND');
  END IF;
  IF s.status <> 'pending' THEN
    RETURN jsonb_build_object('ok', false, 'code', 'ALREADY_PROCESSED', 'status', s.status);
  END IF;
  IF s.admin_id = auth.uid() THEN
    RETURN jsonb_build_object('ok', false, 'code', 'SELF_APPROVAL');
  END IF;
  UPDATE public.platform_settlements
     SET status = 'approved', reviewed_at = now(), reviewed_by = auth.uid()
   WHERE id = s.id;
  UPDATE public.regional_collections
     SET status = 'settled', settlement_id = s.id
   WHERE admin_id = s.admin_id AND status = 'collected'
     AND (s.region_id IS NULL OR region_id = s.region_id);
  PERFORM public.write_audit('SETTLEMENT_APPROVED', 'platform_settlements', s.id::text,
    jsonb_build_object('admin', s.admin_id, 'amount', s.amount, 'region', s.region_id));
  RETURN jsonb_build_object('ok', true, 'code', 'OK');
END;
$$;

CREATE OR REPLACE FUNCTION public.reject_settlement_request(
  p_settlement_id uuid,
  p_reason text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  s public.platform_settlements;
BEGIN
  IF auth.uid() IS NULL OR NOT public._is_owner_uid(auth.uid()) THEN
    RETURN jsonb_build_object('ok', false, 'code', 'FORBIDDEN');
  END IF;
  SELECT * INTO s FROM public.platform_settlements
   WHERE id = p_settlement_id FOR UPDATE;
  IF s IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'code', 'NOT_FOUND');
  END IF;
  IF s.status <> 'pending' THEN
    RETURN jsonb_build_object('ok', false, 'code', 'ALREADY_PROCESSED', 'status', s.status);
  END IF;
  UPDATE public.platform_settlements
     SET status = 'rejected', reviewed_at = now(), reviewed_by = auth.uid(),
         rejection_reason = p_reason
   WHERE id = s.id;
  RETURN jsonb_build_object('ok', true, 'code', 'OK');
END;
$$;

-- ---------------------------------------------------------------------------
-- 12. FINANCIAL SUMMARY RPCs (compose existing ledger with new subsystem)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_my_financial_summary()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_balance numeric;
  v_grace jsonb;
  v_rate numeric;
  v_ut text;
  v_pending int;
  v_txns jsonb;
BEGIN
  IF v_uid IS NULL THEN
    RETURN NULL;
  END IF;
  SELECT balance INTO v_balance FROM public.wallets WHERE user_id = v_uid;
  v_balance := COALESCE(v_balance, 0);
  v_grace := public.get_my_grace();
  SELECT user_type INTO v_ut FROM public.users WHERE id = v_uid;
  v_rate := public.get_commission_rate(v_ut, NULL);

  SELECT count(*) INTO v_pending FROM public.topup_requests
   WHERE account_id = v_uid AND status = 'pending';

  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'id', id, 'type', type, 'amount', amount, 'description', description,
    'balance_after', balance_after, 'created_at', created_at)), '[]'::jsonb) INTO v_txns
  FROM (
    SELECT * FROM public.wallet_transactions wt
     WHERE wallet_id = (SELECT id FROM public.wallets WHERE user_id = v_uid)
    ORDER BY created_at DESC LIMIT 10
  ) sub;

  RETURN jsonb_build_object(
    'balance', v_balance,
    'grace_limit', (v_grace ->> 'grace_limit')::int,
    'grace_used', (v_grace ->> 'grace_used')::int,
    'grace_remaining', (v_grace ->> 'grace_remaining')::int,
    'commission_rate', v_rate,
    'pending_topups', v_pending,
    'recent_transactions', COALESCE(v_txns, '[]'::jsonb)
  );
END;
$$;

-- ---------------------------------------------------------------------------
-- 13. GRANTS (client-facing RPCs; authz enforced inside each function)
-- ---------------------------------------------------------------------------
DO $$
DECLARE
  fn RECORD;
BEGIN
  FOR fn IN
    SELECT p.proname as name, pg_get_function_identity_arguments(p.oid) as args
    FROM pg_proc p
    JOIN pg_namespace n ON p.pronamespace = n.oid
    WHERE n.nspname = 'public'
      AND p.proname IN (
        'get_or_create_grace','get_my_grace','evaluate_order_eligibility',
        'consume_grace','release_grace','admin_set_grace',
        'resolve_receiver_for_account','owner_create_receiving_account',
        'owner_update_receiving_account','admin_create_receiving_wallet',
        'list_platform_receiving_accounts','create_topup_request',
        'approve_topup_request','reject_topup_request','get_my_topup_requests',
        'list_region_topup_requests','get_region_collection_summary',
        'submit_settlement_request','approve_settlement_request',
        'reject_settlement_request','get_my_financial_summary'
      )
      AND p.prokind = 'f'
  LOOP
    EXECUTE format('GRANT EXECUTE ON FUNCTION public.%I(%s) TO authenticated', fn.name, fn.args);
    EXECUTE format('GRANT EXECUTE ON FUNCTION public.%I(%s) TO anon', fn.name, fn.args);
    EXECUTE format('GRANT EXECUTE ON FUNCTION public.%I(%s) TO service_role', fn.name, fn.args);
  END LOOP;
END $$;
