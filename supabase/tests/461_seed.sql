-- 461 extra fixtures: applied by harness/461_harness.sh AFTER
-- tests/449_seed.sql, IDENTICALLY to the pre DB (439..451) and the post
-- DB (439..451+461). Synthetic only. DISPOSABLE-DB-ONLY.
--
-- Adds: a regional-admin persona (users.role='admin' + admin_management
-- + admin_region_assignments self-scope on the region containing the
-- seeded cafe's coordinates), coordinates+address on the seeded cafe,
-- and two delivery rides (one assigned to the driver persona, one
-- ordered by the customer persona) for the deliveries-view probes.

BEGIN;

create table public.zz461(
  regional_admin uuid, region uuid, ride_driver uuid, ride_customer uuid,
  order2 uuid, driver2_user uuid, driver2 uuid, order3 uuid, order4 uuid,
  ride_suspended uuid, ride_requested uuid
);
insert into zz461
select gen_random_uuid(), gen_random_uuid(), gen_random_uuid(), gen_random_uuid(),
       gen_random_uuid(), gen_random_uuid(), gen_random_uuid(), gen_random_uuid(),
       gen_random_uuid(), gen_random_uuid(), gen_random_uuid();
-- resolve the region that contains the seeded point (Cairo) AFTER the
-- ids exist so the failure mode is a loud assert, not a NULL row
update zz461 set region = public._point_region_id(30.0444196, 31.2357116);
DO $$
BEGIN
  ASSERT (select region from zz461) IS NOT NULL,
    '461 seed: no region contains the seeded point';
END $$;
grant select on table zz461 to authenticated, anon;

-- the seeded cafe sits inside that region (regional-scope math) and
-- carries an address (deliveries merchant_address probe)
update public.merchants
   set latitude = 30.0444196, longitude = 31.2357116,
       address = 'zz461-cafe-address'
 where id = (select shop from zz449);

-- regional admin persona: active admin, self-scoped to that region
insert into auth.users(id, email)
values ((select regional_admin from zz461),
        'zz461.regadmin.' || (select regional_admin from zz461) || '@example.invalid');
insert into public.users(id, email, role, user_type, verification_status, username, account_status)
values ((select regional_admin from zz461),
        'zz461.regadmin.' || (select regional_admin from zz461) || '@example.invalid',
        'admin', 'customer', 'approved',
        'zz461' || left((select regional_admin from zz461)::text, 8), 'active')
on conflict (id) do update set username = excluded.username,
  account_status = 'active', role = excluded.role;
insert into public.admin_management(admin_id, is_active, supervisor_id)
values ((select regional_admin from zz461), true, (select admin_user from zz449));
insert into public.admin_region_assignments(admin_id, region_id, scope)
values ((select regional_admin from zz461), (select region from zz461), 'self');

-- a second order for the driver's ride (rides_one_active_delivery_
-- per_order forbids sharing the 449-seeded order)
insert into public.orders(id, user_id, merchant_id, status, subtotal, total_amount)
values ((select order2 from zz461), (select customer from zz449),
        (select shop from zz449), 'pending', 100, 125);

-- delivery rides: one assigned to the driver persona (visible to the
-- driver), one ordered by the customer persona against the seeded order
-- (visible to the customer); both on the seeded cafe (labels resolve).
insert into public.rides(id, rider_id, driver_id, merchant_id, ride_type, status,
                         fare, pickup_latitude, pickup_longitude,
                         dropoff_latitude, dropoff_longitude,
                         pickup_address, dropoff_address, recipient_name,
                         recipient_phone, order_id, created_at)
values
  ((select ride_driver from zz461), null, (select driver1 from zz449),
   (select shop from zz449), 'motorcycle', 'matched',
   25, 30.0444196, 31.2357116, 30.05, 31.24,
   '', 'zz461-dropoff-a', 'zz461-recipient-a', '01000000461',
   (select order2 from zz461), now()),
  ((select ride_customer from zz461), (select customer from zz449), null,
   (select shop from zz449), 'motorcycle', 'searching',
   30, 30.0444196, 31.2357116, 30.05, 31.24,
   '', 'zz461-dropoff-b', 'zz461-recipient-b', '01000000451',
   (select order1 from zz449), now());

-- #285 fixtures: a second driver persona (requested-driver NEGATIVE), a
-- delivery ride on the SUSPENDED cafe (label must stay blank, mirroring
-- the old caller-side merchants RLS), and a searching ride REQUESTED to
-- the driver persona via ride_requests (requested-driver POSITIVE).
insert into auth.users(id, email)
values ((select driver2_user from zz461),
        'zz461.driver2.' || (select driver2_user from zz461) || '@example.invalid');
insert into public.users(id, email, role, user_type, verification_status, username, account_status)
values ((select driver2_user from zz461),
        'zz461.driver2.' || (select driver2_user from zz461) || '@example.invalid',
        'customer', 'customer', 'approved',
        'zz461d2' || left((select driver2_user from zz461)::text, 6), 'active')
on conflict (id) do update set username = excluded.username,
  account_status = 'active', role = excluded.role;
insert into public.drivers(id, user_id, full_name, phone, is_online) values
  ((select driver2 from zz461), (select driver2_user from zz461), 'zz461-driver2', '01000000453', true);

insert into public.orders(id, user_id, merchant_id, status, subtotal, total_amount)
values ((select order3 from zz461), (select customer from zz449),
        (select shop_suspended from zz449), 'pending', 100, 125),
       ((select order4 from zz461), (select customer from zz449),
        (select shop from zz449), 'pending', 100, 125);

insert into public.rides(id, rider_id, driver_id, merchant_id, ride_type, status,
                         fare, pickup_latitude, pickup_longitude,
                         dropoff_latitude, dropoff_longitude,
                         pickup_address, dropoff_address, recipient_name,
                         recipient_phone, order_id, created_at)
values
  -- assigned to the driver persona, on the SUSPENDED cafe: the delivery
  -- row is visible to the driver but merchant_name/address must be blank
  ((select ride_suspended from zz461), null, (select driver1 from zz449),
   (select shop_suspended from zz449), 'motorcycle', 'matched',
   25, 30.0444196, 31.2357116, 30.05, 31.24,
   '', 'zz461-dropoff-c', 'zz461-recipient-c', '01000000454',
   (select order3 from zz461), now()),
  -- searching, unassigned, REQUESTED to the driver persona: visible via
  -- the requested-driver branch of the rides policy
  ((select ride_requested from zz461), null, null,
   (select shop from zz449), 'motorcycle', 'searching',
   30, 30.0444196, 31.2357116, 30.05, 31.24,
   '', 'zz461-dropoff-d', 'zz461-recipient-d', '01000000455',
   (select order4 from zz461), now());
insert into public.ride_requests(id, ride_id, driver_id, status)
values (gen_random_uuid(), (select ride_requested from zz461),
        (select driver1 from zz449), 'offered');

COMMIT;
