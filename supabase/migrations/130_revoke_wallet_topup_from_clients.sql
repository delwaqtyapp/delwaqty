-- 130: wallet_topup credits any authenticated caller's own wallet with an
-- arbitrary amount - anyone signed in could mint balance. The customer
-- top-up UI now submits a request via create_topup_request (Owner approves);
-- nothing legitimate calls wallet_topup from clients anymore. Revoke it from
-- client roles; service_role (admin tooling / future server flows) keeps it.
revoke execute on function public.wallet_topup(numeric, text, text, text) from anon, authenticated;
revoke execute on function public.wallet_topup(uuid, numeric, text, text, uuid) from anon, authenticated;
