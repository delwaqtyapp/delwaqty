-- 166: Add total_reviews to the merchants sensitive-fields guard (bughunt F15).
-- rating and total_orders were already guarded; total_reviews was the gap.

create or replace function public.merchants_guard_sensitive_fields()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
begin
  if current_user in ('authenticated', 'anon') and not public.is_admin() then
    if NEW.owner_user_id is distinct from OLD.owner_user_id then
      raise exception 'owner_user_id is immutable';
    end if;
    if NEW.status is distinct from OLD.status then
      raise exception 'status is managed by the admin RPCs';
    end if;
    if NEW.rating is distinct from OLD.rating then
      raise exception 'rating is managed by the rating engine';
    end if;
    if NEW.total_reviews is distinct from OLD.total_reviews then
      raise exception 'total_reviews is managed by the rating engine';
    end if;
    if NEW.total_orders is distinct from OLD.total_orders then
      raise exception 'total_orders is managed by the order engine';
    end if;
    if NEW.delivery_fee is distinct from OLD.delivery_fee then
      raise exception 'delivery_fee is managed by the admin RPCs';
    end if;
    if NEW.min_order is distinct from OLD.min_order then
      raise exception 'min_order is managed by the admin RPCs';
    end if;
    if NEW.is_featured is distinct from OLD.is_featured then
      raise exception 'is_featured is managed by the admin RPCs';
    end if;
  end if;
  return NEW;
end;
$$;
