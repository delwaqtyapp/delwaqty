-- 219: prod cron jobs, captured for repo-alone rebuilds (pg_cron's cron.job
-- is not schema, so the baseline cannot carry it). cron.schedule with an
-- existing job name updates the schedule in place, so this is idempotent.
SELECT cron.schedule('deactivate-stale-tokens', '0 0 * * *', $cmd$SELECT public.deactivate_stale_tokens()$cmd$);
SELECT cron.schedule('apply-retention-policies', '0 2 * * 0', $cmd$SELECT public.apply_retention_policies()$cmd$);
SELECT cron.schedule('run-member-engines', '0 * * * *', $cmd$SELECT public.run_member_engines()$cmd$);
SELECT cron.schedule('lift-expired-member-sanctions', '*/15 * * * *', $cmd$SELECT public._lift_expired_member_sanctions()$cmd$);
