-- Phase 5b: direct Base Sepolia deposits.
--
-- The backend watches the per-user smart account balance. Any increase is
-- credited to the INR ledger at DEMO_ETH_INR_RATE. This is testnet ETH valued
-- at a demo rate, not a real exchange rate.
--
-- The function locks the wallet row and compares the observed on-chain balance
-- with onchain_seen_wei, so two concurrent polls cannot double-credit.

begin;

alter table public.wallets
  add column if not exists onchain_seen_wei numeric not null default 0;

create or replace function public.credit_onchain_deposit(
  p_owner_id uuid,
  p_observed_wei numeric,
  p_eth_inr_rate numeric
)
returns table (credited_inr numeric, new_balance numeric, delta_wei numeric)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_wallet public.wallets%rowtype;
  v_delta numeric;
  v_inr numeric;
  v_balance numeric;
begin
  if p_observed_wei is null or p_observed_wei < 0 then
    raise exception 'observed wei must be non-negative' using errcode = '22023';
  end if;
  if p_eth_inr_rate is null or p_eth_inr_rate <= 0 then
    raise exception 'ETH to INR rate must be greater than 0'
      using errcode = '22023';
  end if;

  select * into v_wallet
    from public.wallets w
   where w.owner_id = p_owner_id
   for update;

  if not found then
    raise exception 'No wallet exists for this account' using errcode = 'P0002';
  end if;

  -- Funds left the account (or the RPC reported a lower balance). Lower the
  -- watermark so a later deposit can be credited.
  if p_observed_wei < v_wallet.onchain_seen_wei then
    update public.wallets w
       set onchain_seen_wei = p_observed_wei
     where w.owner_id = p_owner_id;
    return query select 0::numeric, v_wallet.balance_inr, 0::numeric;
    return;
  end if;

  if p_observed_wei = v_wallet.onchain_seen_wei then
    return query select 0::numeric, v_wallet.balance_inr, 0::numeric;
    return;
  end if;

  v_delta := p_observed_wei - v_wallet.onchain_seen_wei;
  v_inr := round((v_delta / 1000000000000000000::numeric) * p_eth_inr_rate, 2);

  if v_inr <= 0 then
    update public.wallets w
       set onchain_seen_wei = p_observed_wei
     where w.owner_id = p_owner_id;
    return query select 0::numeric, v_wallet.balance_inr, v_delta;
    return;
  end if;

  update public.wallets w
     set onchain_seen_wei = p_observed_wei,
         balance_inr = w.balance_inr + v_inr
   where w.owner_id = p_owner_id
   returning w.balance_inr into v_balance;

  insert into public.transactions
    (owner_id, wallet_id, merchant_name, amount_inr, status)
  values
    (p_owner_id, v_wallet.id, 'Base Sepolia deposit', v_inr, 'CRYPTO_TOPUP');

  return query select v_inr, v_balance, v_delta;
end;
$$;

revoke all on function public.credit_onchain_deposit(uuid, numeric, numeric)
  from public, anon, authenticated;
grant execute on function public.credit_onchain_deposit(uuid, numeric, numeric)
  to service_role;

commit;
