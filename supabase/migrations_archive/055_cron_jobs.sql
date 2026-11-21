-- Migration 055: Scheduled function cron jobs
-- These functions exist in the DB but need pg_cron to be scheduled

-- 1. deactivate_stale_tokens: Deactivates FCM tokens older than 30 days
-- Runs daily at midnight
SELECT cron.schedule(
  'deactivate-stale-tokens',
  '0 0 * * *',
  $$
  SELECT public.deactivate_stale_tokens()
  $$
);

-- 2. apply_retention_policies: Applies retention/archive policies for old data
-- Runs weekly on Sunday at 2 AM
SELECT cron.schedule(
  'apply-retention-policies',
  '0 2 * * 0',
  $$
  SELECT public.apply_retention_policies()
  $$
);

-- 3. run_member_engines: Runs member reward/loyalty engines
-- Runs hourly
SELECT cron.schedule(
  'run-member-engines',
  '0 * * * *',
  $$
  SELECT public.run_member_engines()
  $$
);

-- Verification: List all scheduled jobs
SELECT * FROM cron.job ORDER BY schedule;