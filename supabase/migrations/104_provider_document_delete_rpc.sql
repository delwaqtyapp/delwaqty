-- ============================================================
-- 104_provider_document_delete_rpc.sql
-- The provider document manager calls `provider_delete_document`
-- but the function was never created in any migration, so the
-- delete action raised `function does not exist` on every attempt.
-- Its sibling RPCs (`provider_get_documents`, `provider_upsert_document`)
-- did exist, which is why only removal was broken.
--
-- The function mirrors the ownership rule of the other two: a provider
-- may only delete their OWN document row.
-- ============================================================

CREATE OR REPLACE FUNCTION public.provider_delete_document(p_doc_type text)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_deleted integer;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  IF p_doc_type IS NULL OR btrim(p_doc_type) = '' THEN
    RAISE EXCEPTION 'Document type is required';
  END IF;

  -- The ownership column is `provider_id` (069_provider_documents.sql:11),
  -- not `user_id`: provider_documents has no user_id column at all.
  DELETE FROM public.provider_documents
   WHERE provider_id = v_uid
     AND doc_type = p_doc_type;

  GET DIAGNOSTICS v_deleted = ROW_COUNT;

  IF v_deleted = 0 THEN
    -- Nothing owned by this caller with that type: either it never
    -- existed or it belongs to somebody else. Report it honestly
    -- instead of pretending the delete succeeded.
    RETURN false;
  END IF;

  RETURN true;
END;
$$;

REVOKE ALL ON FUNCTION public.provider_delete_document(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.provider_delete_document(text) TO authenticated;