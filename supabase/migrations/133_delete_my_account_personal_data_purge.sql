-- 133_delete_my_account_personal_data_purge.sql
-- Harden self-service account deletion (customer app "Delete Account").
--
-- Background: 079's delete_my_account only anonymized public.users and then
-- deleted the auth row. In practice it always rolled back, because
-- _member_exec_delete writes an audit_log row with actor = the member and
-- audit_log.actor references auth.users(id) with NO ACTION, so the final
-- DELETE FROM auth.users violated the FK. It also left personal content
-- behind: addresses, trusted contacts, chat rooms/messages, audio
-- recordings, verification documents and captain/merchant profiles.
--
-- Storage objects cannot be purged from SQL: Supabase blocks direct
-- deletes on storage.objects ("Use the Storage API instead"). So the work
-- splits in two:
--   * The delete-user Edge Function (service role) purges the member's
--     objects through the Storage API, then calls delete_user_data below.
--   * public.delete_user_data(p_uid, p_reason) purges the personal rows in
--     ONE transaction, anonymizes the account row via the existing
--     moderation engine and removes the auth row. Service-role only.
--   * public.delete_my_account(p_reason) remains the client-callable
--     fallback: same transactional row purge for the caller, no storage
--     purge (the edge-function path is the sanctioned one).
--
-- Financial/order records (orders, rides, wallets, wallet/payment
-- transactions, funding requests) stay, keyed to the anonymized account id,
-- matching the retention exceptions in the public privacy/data-deletion
-- pages. Any failure raises and rolls the whole deletion back, so a
-- partial delete is impossible and the client always sees a real error.

CREATE OR REPLACE FUNCTION public.delete_user_data(
  p_uid uuid,
  p_reason text DEFAULT 'user_requested'
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_room_ids uuid[];
  v_driver_ids uuid[];
  v_merchant_ids uuid[];
BEGIN
  IF p_uid IS NULL THEN
    RAISE EXCEPTION 'User id is required';
  END IF;
  IF public._is_active_admin_uid(p_uid) THEN
    RAISE EXCEPTION 'Admins are managed through the admin lifecycle';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.users WHERE id = p_uid) THEN
    RAISE EXCEPTION 'Member not found';
  END IF;

  -- 1. Conversations: every room the user participates in goes (messages,
  --    typing and escalations cascade from the room). Attachments are
  --    purged by the edge function through the Storage API first. Any
  --    message the user sent in another room goes too.
  SELECT array_agg(id) INTO v_room_ids
  FROM public.chat_rooms
  WHERE participant_ids @> ARRAY[p_uid]::uuid[];
  IF v_room_ids IS NOT NULL THEN
    DELETE FROM public.chat_rooms WHERE id = ANY (v_room_ids);
  END IF;
  DELETE FROM public.chat_messages WHERE sender_id = p_uid;

  -- 2. Audio recording rows (objects purged via Storage API first).
  DELETE FROM public.service_audio_logs WHERE user_id = p_uid;

  -- 3. Personal document rows (objects purged via Storage API first; the
  --    users-row URL columns are nulled by the engine below).
  DELETE FROM public.provider_documents WHERE provider_id = p_uid;
  DELETE FROM public.verification_attempts WHERE user_id = p_uid;

  -- 4. Wallet top-up proof references (the financial rows stay; the
  --    personal transfer receipts go).
  UPDATE public.wallet_funding_requests SET proof_url = NULL WHERE user_id = p_uid;
  UPDATE public.topup_requests SET proof_path = NULL WHERE account_id = p_uid;

  -- 5. Captain profile, if any: detach historical deliveries (driver_id is
  --    nullable on orders/rides), then delete the driver row; its documents,
  --    earnings, locations, vehicles and withdrawal requests cascade.
  SELECT array_agg(id) INTO v_driver_ids FROM public.drivers WHERE user_id = p_uid;
  IF v_driver_ids IS NOT NULL THEN
    UPDATE public.drivers SET current_delivery_id = NULL WHERE id = ANY (v_driver_ids);
    UPDATE public.orders SET driver_id = NULL WHERE driver_id = ANY (v_driver_ids);
    UPDATE public.rides SET driver_id = NULL WHERE driver_id = ANY (v_driver_ids);
    DELETE FROM public.order_dispatch WHERE candidate_driver_id = ANY (v_driver_ids);
    DELETE FROM public.drivers WHERE id = ANY (v_driver_ids);
  END IF;

  -- 6. Merchant profile, if any: detach historical orders/rides, then delete
  --    the store; its products, branches, favorites and profile rows cascade.
  SELECT array_agg(id) INTO v_merchant_ids FROM public.merchants WHERE owner_user_id = p_uid;
  IF v_merchant_ids IS NOT NULL THEN
    UPDATE public.orders SET merchant_id = NULL WHERE merchant_id = ANY (v_merchant_ids);
    UPDATE public.rides SET merchant_id = NULL WHERE merchant_id = ANY (v_merchant_ids);
    UPDATE public.coupons SET merchant_id = NULL WHERE merchant_id = ANY (v_merchant_ids);
    UPDATE public.reviews SET merchant_id = NULL WHERE merchant_id = ANY (v_merchant_ids);
    DELETE FROM public.merchants WHERE id = ANY (v_merchant_ids);
  END IF;
  DELETE FROM public.merchant_profiles WHERE user_id = p_uid;

  -- 7. Personal content rows.
  DELETE FROM public.user_addresses WHERE user_id = p_uid;
  DELETE FROM public.trusted_contacts WHERE user_id = p_uid;
  DELETE FROM public.saved_places WHERE user_id = p_uid;
  DELETE FROM public.favorites WHERE user_id = p_uid;
  DELETE FROM public.favorite_drivers WHERE user_id = p_uid;
  DELETE FROM public.notification_tokens WHERE user_id = p_uid;
  DELETE FROM public.notifications WHERE user_id = p_uid;
  DELETE FROM public.live_share_sessions WHERE user_id = p_uid;
  DELETE FROM public.location_updates WHERE user_id = p_uid;
  DELETE FROM public.user_region_preferences WHERE user_id = p_uid;
  DELETE FROM public.campaign_seen WHERE user_id = p_uid;
  DELETE FROM public.promo_redemptions WHERE user_id = p_uid;
  DELETE FROM public.sos_alerts WHERE user_id = p_uid;
  DELETE FROM public.reviews WHERE user_id = p_uid;
  DELETE FROM public.ride_ratings WHERE rater_id = p_uid;
  DELETE FROM public.service_reviews WHERE user_id = p_uid;
  DELETE FROM public.member_rewards WHERE user_id = p_uid;
  DELETE FROM public.grace_accounts WHERE user_id = p_uid;
  DELETE FROM public.chat_typing WHERE user_id = p_uid;
  DELETE FROM public.provider_business_profiles WHERE user_id = p_uid;

  -- 8. The engine's audit row references auth.users(actor) with NO ACTION;
  --    detach the member's actor rows so the auth delete below cannot fail.
  UPDATE public.audit_log SET actor = NULL WHERE actor = p_uid;

  -- 9. Anonymize the account row (D4 semantics, FK-safe) via the existing
  --    moderation engine, then revoke the login by removing the auth row.
  PERFORM public._member_exec_delete(
    p_uid, p_uid, COALESCE(NULLIF(btrim(p_reason), ''), 'user_requested'));

  DELETE FROM auth.users WHERE id = p_uid;
END;
$$;

REVOKE ALL ON FUNCTION public.delete_user_data(uuid, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.delete_user_data(uuid, text) FROM anon;
REVOKE ALL ON FUNCTION public.delete_user_data(uuid, text) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.delete_user_data(uuid, text) TO service_role;

-- Client-callable fallback: same transactional row purge for the caller.
-- The delete-user Edge Function is the sanctioned path because it also
-- purges storage objects through the Storage API.
CREATE OR REPLACE FUNCTION public.delete_my_account(
  p_reason text DEFAULT 'user_requested'
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_uid uuid;
BEGIN
  v_uid := auth.uid();
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;
  PERFORM public.delete_user_data(v_uid, p_reason);
END;
$$;

REVOKE ALL ON FUNCTION public.delete_my_account(text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.delete_my_account(text) FROM anon;
GRANT EXECUTE ON FUNCTION public.delete_my_account(text) TO authenticated;
