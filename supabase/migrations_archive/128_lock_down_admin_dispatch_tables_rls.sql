-- 128: Lock down tables that were created without RLS.
-- admin_roles (072), dispatch_config and order_dispatch (073) were reachable
-- through PostgREST with the public anon key. The apps never query these
-- tables directly (all access is via SECURITY DEFINER RPCs, which bypass RLS),
-- so enabling RLS with no policies denies anon/authenticated access while
-- leaving every existing backend path intact.
alter table public.admin_roles enable row level security;
alter table public.dispatch_config enable row level security;
alter table public.order_dispatch enable row level security;
