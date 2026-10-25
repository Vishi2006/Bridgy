-- Phase 3 fix: enforce per-transaction and daily caps inside the same row
-- lock as the balance update. The old read-then-debit split let concurrent
-- requests each pass the cap check and over-spend.

begin;

drop function if exists public.debit_wallet(uuid, numeric, text, text, text);

create function public.debit_wallet(
  p_owner_id uuid,
  p_amount numeric,
  p_merchant text,
  p_vpa text,
  p_status text,
  p_per_tx_limit numeric default null,
  p_daily_limit numeric default null
)
returns table (new_balance numeric, transaction_id uuid, spent_today numeric)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_wallet public.wallets%rowtype;
  v_balance numeric;
  v_spent numeric;
  v_tx uuid;
begin
  if p_amount is null or p_amount <= 0 then
    raise exception 'amount must be greater than 0' using errcode = '22023';
  end if;
  if p_status not in ('AGENT_PAID', 'OWNER_PAID') then
    raise exception 'unsupported payment status %', p_status using errcode = '22023';
  end if;

  select * into v_wallet
    from public.wallets w
   where w.owner_id = p_owner_id
   for update;

  if not found then
    raise exception 'No wallet exists for this account' using errcode = 'P0002';
  end if;

  v_spent := case
    when v_wallet.spent_on = current_date then v_wallet.spent_today_inr
    else 0
  end + p_amount;

  if p_status = 'AGENT_PAID' then
    if p_per_tx_limit is not null and p_amount > p_per_tx_limit then
      raise exception 'per-transaction limit exceeded' using errcode = 'P0001';
    end if;
    if p_daily_limit is not null and v_spent > p_daily_limit then
      raise exception 'daily limit exceeded' using errcode = 'P0001';
    end if;
  end if;

  if v_wallet.balance_inr < p_amount then
    raise exception 'Insufficient balance' using errcode = '22003';
  end if;

  update public.wallets w
     set balance_inr = w.balance_inr - p_amount,
         spent_today_inr = v_spent,
         spent_on = current_date
   where w.owner_id = p_owner_id
   returning w.balance_inr into v_balance;

  insert into public.transactions
    (owner_id, wallet_id, merchant_name, merchant_vpa, amount_inr, status)
  values
    (p_owner_id, v_wallet.id, p_merchant, p_vpa, p_amount, p_status)
  returning id into v_tx;

  return query select v_balance, v_tx, v_spent;
end;
$$;

revoke all on function public.debit_wallet(
  uuid, numeric, text, text, text, numeric, numeric
) from public, anon, authenticated;
grant execute on function public.debit_wallet(
  uuid, numeric, text, text, text, numeric, numeric
) to service_role;

commit;
