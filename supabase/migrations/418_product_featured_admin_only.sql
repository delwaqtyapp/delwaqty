-- 418: products.is_featured is admin-only.
-- Direct client writes (anon/authenticated, admins included) are rejected by
-- the invoker trigger; the only client path is the scoped SECURITY DEFINER
-- RPC admin_set_product_featured (region write scope + MERCHANT_EDIT, rows
-- locked FOR UPDATE before the region is evaluated). Service/postgres
-- definer paths are unaffected. Existing featured rows preserved; live prod
-- preflight found zero.
BEGIN;
CREATE OR REPLACE FUNCTION public.products_guard_featured()
RETURNS trigger LANGUAGE plpgsql SECURITY INVOKER SET search_path TO public,pg_temp AS $$
BEGIN
 IF current_user IN ('anon','authenticated') THEN
  IF (TG_OP='INSERT' AND coalesce(NEW.is_featured,false)) OR (TG_OP='UPDATE' AND NEW.is_featured IS DISTINCT FROM OLD.is_featured) THEN
   RAISE EXCEPTION 'is_featured is managed by admins' USING ERRCODE='42501';
  END IF;
 END IF;
 RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION public.products_guard_featured() FROM PUBLIC,anon,authenticated;
DROP TRIGGER IF EXISTS products_featured_admin_only ON public.products;
CREATE TRIGGER products_featured_admin_only BEFORE INSERT OR UPDATE OF is_featured ON public.products FOR EACH ROW EXECUTE FUNCTION public.products_guard_featured();
CREATE OR REPLACE FUNCTION public.admin_set_product_featured(p_product_id uuid,p_featured boolean)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO public,pg_temp AS $$
DECLARE v_region uuid; BEGIN
 SELECT public._point_region_id(m.latitude,m.longitude) INTO v_region FROM public.products p JOIN public.merchants m ON m.id=p.merchant_id WHERE p.id=p_product_id FOR UPDATE OF p,m;
 IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'code','NOT_FOUND'); END IF;
 IF auth.uid() IS NULL OR NOT public._admin_write_scope(v_region) OR NOT public.has_permission('MERCHANT_EDIT',public._ops_scope_region(v_region)) THEN
  RETURN jsonb_build_object('ok',false,'code','FORBIDDEN'); END IF;
 IF p_featured IS NULL THEN RETURN jsonb_build_object('ok',false,'code','INVALID_VALUE'); END IF;
 UPDATE public.products SET is_featured=p_featured WHERE id=p_product_id;
 RETURN jsonb_build_object('ok',true);
END $$;
REVOKE ALL ON FUNCTION public.admin_set_product_featured(uuid,boolean) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.admin_set_product_featured(uuid,boolean) TO authenticated;
COMMIT;
