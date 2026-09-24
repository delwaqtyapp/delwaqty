-- 084_service_reviews.sql
-- Service-level reviews & ratings (customer-facing on EVERY service category),
-- so a customer can rate (1-5 stars) and review any service in the app.
--
-- Design:
--   * service_reviews  : one row per customer review, keyed by category_type
--                        (doctor / nurse / teacher / barber / plumbing / ... )
--                        with an OPTIONAL provider_id link + denormalized
--                        user_name for the listing (users RLS is own-profile only).
--   * get_service_rating_summary(text) : per-category average + star breakdown.
--   * AFTER trigger keeps service_providers.rating / rating_count in sync when a
--     review targets a provider (provider cards show live ratings).

CREATE TABLE IF NOT EXISTS service_reviews (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  category_type TEXT NOT NULL,
  provider_id UUID REFERENCES service_providers(id) ON DELETE CASCADE,
  booking_id UUID,
  user_name TEXT NOT NULL DEFAULT '',
  rating INTEGER NOT NULL CHECK (rating >= 1 AND rating <= 5),
  comment TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_service_reviews_category_type ON service_reviews (category_type);
CREATE INDEX IF NOT EXISTS idx_service_reviews_user_id ON service_reviews (user_id);
CREATE INDEX IF NOT EXISTS idx_service_reviews_provider_id ON service_reviews (provider_id);

ALTER TABLE service_reviews ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS service_reviews_select_public ON service_reviews;
CREATE POLICY service_reviews_select_public ON service_reviews
  FOR SELECT USING (true);

DROP POLICY IF EXISTS service_reviews_insert_own ON service_reviews;
CREATE POLICY service_reviews_insert_own ON service_reviews
  FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS service_reviews_update_own ON service_reviews;
CREATE POLICY service_reviews_update_own ON service_reviews
  FOR UPDATE USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS service_reviews_delete_own ON service_reviews;
CREATE POLICY service_reviews_delete_own ON service_reviews
  FOR DELETE USING (auth.uid() = user_id);

DROP POLICY IF EXISTS service_reviews_admin_all ON service_reviews;
CREATE POLICY service_reviews_admin_all ON service_reviews
  FOR ALL USING (public.is_admin());

-- Per-category summary: average + star breakdown counts.
CREATE OR REPLACE FUNCTION get_service_rating_summary(p_category_type text)
RETURNS TABLE(
  avg_rating numeric,
  total_reviews bigint,
  five_star bigint,
  four_star bigint,
  three_star bigint,
  two_star bigint,
  one_star bigint
)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
  SELECT ROUND(AVG(rating)::numeric, 1),
         COUNT(*)::bigint,
         COUNT(*) FILTER (WHERE rating = 5)::bigint,
         COUNT(*) FILTER (WHERE rating = 4)::bigint,
         COUNT(*) FILTER (WHERE rating = 3)::bigint,
         COUNT(*) FILTER (WHERE rating = 2)::bigint,
         COUNT(*) FILTER (WHERE rating = 1)::bigint
  FROM service_reviews
  WHERE category_type = p_category_type;
$$;

REVOKE ALL ON FUNCTION public.get_service_rating_summary(text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.get_service_rating_summary(text) FROM anon;
GRANT EXECUTE ON FUNCTION public.get_service_rating_summary(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_service_rating_summary(text) TO anon;

-- Keep a provider's rating/rating_count live when reviews carry provider_id.
CREATE OR REPLACE FUNCTION sync_service_provider_rating()
RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  UPDATE service_providers sp
  SET rating = COALESCE((
        SELECT ROUND(AVG(r.rating)::numeric, 1)
        FROM service_reviews r
        WHERE r.provider_id IN (OLD.provider_id, NEW.provider_id)
      ), sp.rating),
      rating_count = (
        SELECT COUNT(*)
        FROM service_reviews r
        WHERE r.provider_id IN (OLD.provider_id, NEW.provider_id)
      )
  WHERE sp.id IN (OLD.provider_id, NEW.provider_id);
  RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS trg_service_reviews_sync_provider ON service_reviews;
CREATE TRIGGER trg_service_reviews_sync_provider
  AFTER INSERT OR UPDATE OR DELETE ON service_reviews
  FOR EACH ROW EXECUTE FUNCTION sync_service_provider_rating();

-- Small demo ratings so the pages render alive (user_id NULL = anonymous seeds
-- inserted by the migration runner with elevated privileges).
INSERT INTO service_reviews (user_id, category_type, user_name, rating, comment)
VALUES
  (NULL, 'doctor', 'أحمد سامي', 5, 'خدمة ممتازة والمواعيد في وقتها'),
  (NULL, 'doctor', 'منى عادل', 4, 'دكتور محترم جداً'),
  (NULL, 'nurse', 'حسن إبراهيم', 5, 'تمريض بيتي ممتاز وبسرعة'),
  (NULL, 'plumbing', 'سعيد عثمان', 4, 'سباك محترف ونظيف'),
  (NULL, 'cleaning', 'نورا خالد', 5, 'التنظيف كان رائع جداً'),
  (NULL, 'deliveryCar', 'عادل مرسي', 5, 'السيارة وصلت بسرعة وسعر ممتاز')
ON CONFLICT (id) DO NOTHING;