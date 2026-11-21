-- 163: Revoke create_order_idempotent from API roles (bughunt F1).
-- It trusts client-supplied prices; the shipped app uses create_order
-- (server-side pricing, migration 157) and nothing else calls it.
-- Kept for service_role (internal tooling) - dropped from the API surface.

revoke execute on function public.create_order_idempotent(text, uuid, text, jsonb, numeric, numeric, numeric, numeric, text, text, text, text, text) from anon, authenticated;
