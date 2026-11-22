-- Publish-time OTA announcement. Run per flavor right after creating the
-- GitHub release (replace <VERSION>, <BUILD>, <FLAVOR>).
-- Inserts one push notification per active device-token owner of the flavor.
-- Client: type 'ota_update' opens the update dialog on tap (v1.0.5+).
INSERT INTO public.notifications
  (user_id, title, body, type, data, deep_link, audience, send_push, idempotency_key)
SELECT DISTINCT t.user_id,
  'تحديث جديد متاح',
  'تحسينات جديدة جاهزة. اضغط لتحديث التطبيق.',
  'ota_update',
  jsonb_build_object('version', '<VERSION>+<BUILD>'),
  '/settings/about',
  '<FLAVOR>',
  true,
  'ota-<BUILD>-<FLAVOR>-' || t.user_id::text
FROM public.notification_tokens t
WHERE t.app = '<FLAVOR>' AND t.is_active
ON CONFLICT (idempotency_key) WHERE idempotency_key IS NOT NULL DO NOTHING;
