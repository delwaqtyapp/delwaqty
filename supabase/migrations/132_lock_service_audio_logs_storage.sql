-- 132: service-audio-logs storage was world-readable by path (policy with no
-- auth condition) and the bucket is private. The feature is dormant (no
-- client code, zero objects), so set the convention now: users read/write
-- only their own folder (first path segment = their uid), admins read all.
drop policy if exists "audio logs read" on storage.objects;
create policy "audio logs read"
  on storage.objects for select
  using (
    bucket_id = 'service-audio-logs'
    and (
      is_admin()
      or _is_owner_uid(auth.uid())
      or (split_part(name, '/', 1))::uuid = auth.uid()
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
