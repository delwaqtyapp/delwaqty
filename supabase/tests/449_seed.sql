-- Shared fixtures for the 449 harness: applied IDENTICALLY to the pre DB
-- (439..448) and the post DB (439..449) before the equal-behavior battery,
-- and used by the 449 suite. Synthetic only. DISPOSABLE-DB-ONLY.
--
-- Personas: owner (merchant owner), cashier (active staff), customer,
-- customer2, provider_user (service_providers.id = users.id convention),
-- admin_user (users.role = 'owner', satisfies _is_active_admin_uid).
-- Data: one active merchant + branch + product (+ modifier group/option),
-- one suspended merchant + product, orders/tracking/pos_sale/review/offer,
-- service provider + booking + document, driver + location, campaign
-- (draft, created_by owner), staff row, staff settings row.

BEGIN;

-- Permanent (not TEMP) so the seed, the battery and the suite can run in
-- separate psql sessions on the same disposable DB. Harness drops the DB.
create table public.zz449(
  owner uuid, cashier uuid, customer uuid, customer2 uuid, provider_user uuid,
  admin_user uuid,
  shop uuid, shop_suspended uuid, branch1 uuid, product1 uuid, product2 uuid,
  mgroup1 uuid, moption1 uuid, order1 uuid, provider uuid, booking1 uuid,
  driver1 uuid, campaign1 uuid
);
insert into zz449 select gen_random_uuid(), gen_random_uuid(),
  gen_random_uuid(), gen_random_uuid(), gen_random_uuid(), gen_random_uuid(),
  gen_random_uuid(), gen_random_uuid(), gen_random_uuid(), gen_random_uuid(),
  gen_random_uuid(), gen_random_uuid(), gen_random_uuid(), gen_random_uuid(),
  gen_random_uuid(), gen_random_uuid(), gen_random_uuid(), gen_random_uuid();
grant select on table zz449 to authenticated, anon;

insert into auth.users(id, email)
select u, 'zz449.' || n || '@example.invalid'
from (values ((select owner from zz449), 'owner'),
             ((select cashier from zz449), 'cashier'),
             ((select customer from zz449), 'customer'),
             ((select customer2 from zz449), 'customer2'),
             ((select provider_user from zz449), 'provider'),
             ((select admin_user from zz449), 'admin')) as x(u, n);
insert into public.users(id, email, role, user_type, verification_status, username, account_status)
select u, 'zz449.' || n || '@example.invalid', r, 'customer', 'approved',
       'zz449' || n, 'active'
from (values ((select owner from zz449), 'owner', 'customer'),
             ((select cashier from zz449), 'cashier', 'customer'),
             ((select customer from zz449), 'customer', 'customer'),
             ((select customer2 from zz449), 'customer2', 'customer'),
             ((select provider_user from zz449), 'provider', 'customer'),
             ((select admin_user from zz449), 'admin', 'owner')) as x(u, n, r)
on conflict (id) do update set username = excluded.username, account_status = 'active', role = excluded.role;

insert into public.merchants(id, name, owner_user_id, type, status, delivery_fee, min_order, delivery_time_min, email, phone) values
  ((select shop from zz449), 'zz449-cafe', (select owner from zz449), 'cafe', 'active', 15, 50, 30, 'zz449-shop@example.invalid', '01000000449'),
  ((select shop_suspended from zz449), 'zz449-closed', (select owner from zz449), 'cafe', 'suspended', 15, 50, 30, NULL, NULL);
insert into public.branches(id, merchant_id, name, is_primary) values
  ((select branch1 from zz449), (select shop from zz449), 'zz449-b1', true);
insert into public.products(id, merchant_id, name, name_ar, price, stock_quantity, barcode, sku) values
  ((select product1 from zz449), (select shop from zz449), 'zz449-item', 'صنف', 100, 7, '6224490001', 'ZZ449SKU'),
  ((select product2 from zz449), (select shop_suspended from zz449), 'zz449-item2', 'صنف', 200, 3, '6224490002', 'ZZ449SKB');
insert into public.product_modifier_groups(id, product_id, name) values
  ((select mgroup1 from zz449), (select product1 from zz449), 'zz449-size');
insert into public.product_modifier_options(id, group_id, name, price_adjustment) values
  ((select moption1 from zz449), (select mgroup1 from zz449), 'zz449-large', 10);
insert into public.orders(id, user_id, merchant_id, status, subtotal, total_amount) values
  ((select order1 from zz449), (select customer from zz449), (select shop from zz449), 'pending', 235, 250);
insert into public.order_tracking(id, order_id, status) values
  (gen_random_uuid(), (select order1 from zz449), 'pending');
insert into public.reviews(id, user_id, merchant_id, product_id, rating) values
  (gen_random_uuid(), (select customer from zz449), (select shop from zz449), (select product1 from zz449), 5);
insert into public.offers(id, merchant_id, title, discount_type, discount_value, is_active) values
  (gen_random_uuid(), (select shop from zz449), 'zz449-offer', 'percentage', 10, true);
insert into public.pos_sales(id, merchant_id, branch_id, cashier_user_id, total_amount, items, subtotal, status) values
  (gen_random_uuid(), (select shop from zz449), (select branch1 from zz449), (select cashier from zz449),
   115, '[{"product_id":"x","name":"zz449-item","qty":1,"unit_price":100}]'::jsonb, 115, 'completed');
insert into public.service_providers(id, user_id, name, category_type, is_available, latitude, longitude) values
  ((select provider_user from zz449), (select provider_user from zz449), 'zz449-plumber', 'plumbing',
   true, 30.0444196, 31.2357116);
insert into public.service_bookings(id, user_id, provider_id, provider_name, category_type, scheduled_date, scheduled_time, status) values
  ((select booking1 from zz449), (select customer from zz449), (select provider_user from zz449),
   'zz449-plumber', 'plumbing', current_date + 1, '10:00', 'pending');
insert into public.provider_documents(id, provider_id, doc_type) values
  (gen_random_uuid(), (select provider_user from zz449), 'license');
insert into public.drivers(id, user_id, full_name, phone, is_online) values
  ((select driver1 from zz449), (select customer2 from zz449), 'zz449-driver', '01000000449', true);
insert into public.driver_locations(driver_id, latitude, longitude) values
  ((select driver1 from zz449), 30.05, 31.24);
insert into public.campaigns(id, code, name_en, name_ar, campaign_type, status, created_by, benefit) values
  ((select campaign1 from zz449), 'ZZ449C', 'zz449-campaign', 'حملة', 'offer', 'draft', (select owner from zz449), '{}'::jsonb);
insert into public.merchant_staff(merchant_id, user_id, username, full_name, role, branch_id, is_active, must_change_password) values
  ((select shop from zz449), (select cashier from zz449), 'zz449cashier', 'Cashier', 'cashier', (select branch1 from zz449), true, false);
insert into public.merchant_staff_settings(merchant_id, settings) values
  ((select shop from zz449), '{"cashier_custom_lines": true}'::jsonb);

COMMIT;
