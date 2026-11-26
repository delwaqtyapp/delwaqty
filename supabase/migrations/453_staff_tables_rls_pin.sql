-- Migration 453: pin RLS ON for staff_provisioning and staff_admin_refusals
-- (builder, Nov 26 2026)
--
-- 444 created both tables without an explicit ENABLE ROW LEVEL SECURITY,
-- relying on the hosted platform's ensure_rls event trigger to enable it at
-- CREATE TABLE time. Prod has relrowsecurity=true on both (verified
-- 2026-11-26 via the management API). Chains built outside the hosted
-- platform (CI `supabase db start`, local labs) have no such trigger, so the
-- tables are created with RLS OFF there - environment-dependent security
-- posture, which the pgTAP redteam gate now pins and caught (CI job
-- 139763173027: "have: staff_admin_refusals, staff_provisioning").
--
-- This migration makes the prod posture explicit and deterministic
-- everywhere. ALTER TABLE ... ENABLE ROW LEVEL SECURITY is idempotent, so
-- applying to prod is a no-op. Both tables intentionally have NO policies:
-- direct access is deny-all by design (all access flows through the
-- definer RPCs in 444); enabling RLS changes no client behavior, matching
-- the state prod has run since 444 shipped.
--
-- Rollback (dev/CI only - on prod this migration is a no-op, so do not run
-- the rollback there): ALTER TABLE public.staff_provisioning DISABLE ROW
-- LEVEL SECURITY; ALTER TABLE public.staff_admin_refusals DISABLE ROW LEVEL
-- SECURITY;

begin;

-- A0: both tables must exist (created by 444).
do $$
begin
  if to_regclass('public.staff_provisioning') is null
     or to_regclass('public.staff_admin_refusals') is null then
    raise exception '453 precondition failed: staff_provisioning / staff_admin_refusals missing';
  end if;
end $$;

alter table public.staff_provisioning enable row level security;
alter table public.staff_admin_refusals enable row level security;

-- Post-condition: RLS is on for both.
do $$
begin
  if exists (
    select 1 from pg_class
     where oid in ('public.staff_provisioning'::regclass,
                   'public.staff_admin_refusals'::regclass)
       and not relrowsecurity
  ) then
    raise exception '453 postcondition failed: RLS still off';
  end if;
end $$;

commit;
