-- 168: Lock down order_tracking (bughunt F2).
-- Was: public read + public insert with qual/with_check true, no FK.
-- Now: participants only (order customer, owning merchant, assigned driver,
-- admin) for read; writes only from those roles server-side. RPC-driven
-- inserts (SECURITY DEFINER, table owner) bypass RLS and keep working.

drop policy if exists ot_insert on public.order_tracking;
drop policy if exists ot_view on public.order_tracking;

create policy ot_view_participants on public.order_tracking
  for select to authenticated
  using (
    public.is_admin()
    or exists (
      select 1 from public.orders o
      where o.id = order_tracking.order_id
        and (
          o.user_id = auth.uid()
          or o.merchant_id in (select m.id from public.merchants m where m.owner_user_id = auth.uid())
          or o.driver_id in (select d.id from public.drivers d where d.user_id = auth.uid())
        )
    )
  );

create policy ot_insert_participants on public.order_tracking
  for insert to authenticated
  with check (
    public.is_admin()
    or exists (
      select 1 from public.orders o
      where o.id = order_tracking.order_id
        and (
          o.merchant_id in (select m.id from public.merchants m where m.owner_user_id = auth.uid())
          or o.driver_id in (select d.id from public.drivers d where d.user_id = auth.uid())
        )
    )
  );
