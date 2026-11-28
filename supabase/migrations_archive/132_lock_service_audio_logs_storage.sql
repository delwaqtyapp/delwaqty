-- 132: service-audio-logs storage was world-readable by path (policy with no
-- auth condition) and the bucket is private. The feature is dormant (no
-- client code, zero objects), so set the convention now: users read/write
-- only their own folder (first path segment = their uid), admins read all.
--
-- Synced with the live staging text (pg_policies, 2026-11-28). The read policy
-- is the hardened form from migration 405: NULL-safe (_storage_uuid_segment
-- returns NULL for a non-UUID path instead of raising, which the old
-- split_part(...)::uuid cast did) and region-scoped (_storage_doc_admin_scope).
-- Note: staging's "audio logs upload" still has the ::uuid cast; it is
-- reproduced as is. Prod dropped both policies in 462 (bucket is empty).
drop policy if exists "audio logs read" on storage.objects;
create policy "audio logs read"
  on storage.objects for select
  to authenticated
  using (
    bucket_id = 'service-audio-logs'
    and (
      public._storage_doc_admin_scope(
        public._storage_uuid_segment(name, 1), 'EMERGENCY_AUDIO')
      or public._storage_uuid_segment(name, 1) = auth.uid()
    )
  );

drop policy if exists "audio logs upload" on storage.objects;
create policy "audio logs upload"
  on storage.objects for insert
  with check (
    bucket_id = 'service-audio-logs'
    and auth.role() = 'authenticated'
    and (split_part(name, '/', 1))::uuid = auth.uid()
  );
