-- 131: owner-only wallet adjustment (credit or debit) with full audit trail.
-- Needed for test-data cleanup and manual corrections. Mirrors
-- admin_direct_topup's pattern but allows negative amounts down to a zero
-- floor (never negative balances).
create or replace function public.wallet_adjust(
  p_account_id uuid,
  p_amount numeric,           -- signed; negative debits
  p_note text default null
)
returns jsonb
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $$
declare
  v_caller    uuid := auth.uid();
  v_wallet_id uuid;
  v_before    numeric;
  v_after     numeric;
  v_txn_id    uuid;
begin
  if v_caller is null then
    return jsonb_build_object('ok', false, 'code', 'UNAUTHENTICATED');
  end if;
  if not public._is_owner_uid(v_caller) then
    return jsonb_build_object('ok', false, 'code', 'FORBIDDEN_OWNER_ONLY');
  end if;
  if not exists (select 1 from public.users where id = p_account_id) then
    return jsonb_build_object('ok', false, 'code', 'ACCOUNT_NOT_FOUND');
  end if;
  if p_amount is null or p_amount = 0 then
    return jsonb_build_object('ok', false, 'code', 'INVALID_AMOUNT');
  end if;

  v_wallet_id := public._ensure_wallet(p_account_id);
  select balance into v_before from public.wallets where id = v_wallet_id for update;
  v_after := coalesce(v_before, 0) + p_amount;
  if v_after < 0 then
    return jsonb_build_object('ok', false, 'code', 'INSUFFICIENT_BALANCE',
      'balance', v_before, 'requested', p_amount);
  end if;

  update public.wallets set balance = v_after, updated_at = now() where id = v_wallet_id;

  insert into public.wallet_transactions
    (wallet_id, type, amount, reference_type, reference_id, description, balance_after)
  values
    (v_wallet_id, case when p_amount > 0 then 'credit' else 'debit' end,
     abs(p_amount), 'admin_adjustment', v_caller,
     'Owner adjustment' || coalesce(' - ' || p_note, ''), v_after)
  returning id into v_txn_id;

  perform public.write_audit('WALLET_ADJUST', 'wallets', v_wallet_id::text,
    jsonb_build_object('actor', v_caller, 'account_id', p_account_id,
      'amount', p_amount, 'balance_before', v_before, 'balance_after', v_after,
      'transaction_id', v_txn_id, 'note', p_note));

  return jsonb_build_object('ok', true, 'code', 'OK', 'wallet_id', v_wallet_id,
    'balance_before', v_before, 'balance_after', v_after, 'transaction_id', v_txn_id);
end;
$$;

revoke all on function public.wallet_adjust(uuid, numeric, text) from public, anon;
grant execute on function public.wallet_adjust(uuid, numeric, text) to authenticated, service_role;
