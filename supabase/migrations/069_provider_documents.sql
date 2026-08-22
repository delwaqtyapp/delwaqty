-- ============================================================================
-- 069_provider_documents.sql
-- Additive provider documents (PHASE 5). Mirrors driver_documents but keyed to
-- public.users.id (providers are users; provider id == auth.uid()). Home-services
-- providers attach license / certification / insurance documents. Owner-only RLS
-- via auth.uid(); no destructive ops. New table + 2 SECURITY DEFINER RPCs.
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.provider_documents (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  provider_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  doc_type TEXT NOT NULL
    CHECK (doc_type IN ('identity', 'license', 'certification', 'insurance')),
  file_url TEXT,
  status TEXT NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'verified', 'rejected')),
  rejection_reason TEXT,
  expires_at DATE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  reviewed_at TIMESTAMPTZ,
  UNIQUE (provider_id, doc_type)
);

ALTER TABLE public.provider_documents ENABLE ROW LEVEL SECURITY;

CREATE INDEX IF NOT EXISTS idx_provider_documents_provider
  ON public.provider_documents(provider_id);

DROP POLICY IF EXISTS "provider docs owner rw" ON public.provider_documents;
CREATE POLICY "provider docs owner rw" ON public.provider_documents
  FOR ALL
  USING (provider_id = auth.uid())
  WITH CHECK (provider_id = auth.uid());

-- ─── UPSERT (owner-only) ───────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.provider_upsert_document(
  p_doc_type text,
  p_file_url text
)
RETURNS public.provider_documents
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_row public.provider_documents;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;
  IF btrim(COALESCE(p_file_url, '')) = '' THEN
    RAISE EXCEPTION 'Document URL is required';
  END IF;
  INSERT INTO public.provider_documents (provider_id, doc_type, file_url, status)
  VALUES (v_uid, p_doc_type, btrim(p_file_url), 'pending')
  ON CONFLICT (provider_id, doc_type) DO UPDATE
    SET file_url = EXCLUDED.file_url,
        status = 'pending',
        rejection_reason = NULL,
        reviewed_at = NULL,
        created_at = now()
  RETURNING * INTO v_row;
  RETURN v_row;
END;
$$;

-- ─── GET (owner-only) ──────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.provider_get_documents()
RETURNS SETOF public.provider_documents
LANGUAGE sql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT * FROM public.provider_documents
  WHERE provider_id = auth.uid()
  ORDER BY created_at DESC;
$$;

-- ─── ACL ───────────────────────────────────────────────────────────────────
REVOKE ALL ON FUNCTION public.provider_upsert_document(text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.provider_upsert_document(text, text) TO authenticated;

REVOKE ALL ON FUNCTION public.provider_get_documents() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.provider_get_documents() TO authenticated;
