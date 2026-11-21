-- 198: close the live-driver-GPS leak. The "Active drivers viewable by all"
-- policy exposed current_latitude/current_longitude (live GPS) and phone to
-- ANY authenticated user via the drivers table (reproduced live with a
-- customer JWT: fresh coordinates returned). driver_locations was already
-- tight; the drivers table columns were the leak.
--
-- Fix (owner-approved under blanket authority 2026-11-21):
--   1. Drop the blanket read policy. Row access: the driver's own row,
--      admins, and ride parties (customer sees drivers linked to their
--      rides) via a SECURITY DEFINER helper - a direct rides subquery in the
--      policy recurses through the rides policies back into drivers.
--   2. Public discovery moves to a safe-column view (no GPS, no phone, no
--      national id, no earnings): online+verified drivers only.
-- Column privileges are NOT revoked (admins share the authenticated role);
-- the row policy is the boundary.

drop policy if exists "Active drivers viewable by all" on public.drivers;

create or replace function public._driver_visible_to_ride_party(p_driver_id uuid)
returns boolean
language sql stable security definer set search_path = public, pg_temp
as $func$
  select exists (select 1 from public.rides r
                  where r.driver_id = p_driver_id
                    and r.rider_id = auth.uid());
$func$;
revoke all on function public._driver_visible_to_ride_party(uuid) from public, anon;
grant execute on function public._driver_visible_to_ride_party(uuid) to authenticated;

drop policy if exists "drivers ride party read" on public.drivers;
create policy "drivers ride party read" on public.drivers for select to authenticated
  using (public._driver_visible_to_ride_party(drivers.id));

create or replace view public.driver_directory
with (security_barrier = true) as
select d.id,
       d.full_name,
       d.profile_photo_url,
       d.vehicle_type,
       d.vehicle_model,
       d.vehicle_color,
       d.vehicle_plate,
       d.rating,
       d.total_deliveries,
       d.service_types,
       d.accepts_deliveries,
       d.max_delivery_distance_km,
       d.max_weight_kg,
       d.is_online
  from public.drivers d
 where d.is_online = true
   and d.is_verified = true;

grant select on public.driver_directory to authenticated;
