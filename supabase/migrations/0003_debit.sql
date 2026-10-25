-- Phase 3: atomic wallet debit for agent and owner payments.
--
-- The balance, daily spend, and transaction row move together. Insufficient
-- balance raises SQLSTATE 22003, which the backend maps to HTTP 409.

begin;

alter table public.wallets alter column balance_inr set default 0;
alter table public.wallets
  add column if not exists spent_on date not null default current_date;

create or replace function public.debit_wallet(
  p_owner_id uuid,
  p_amount numeric,
  p_merchant text,
  p_vpa text,
  p_status text
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

  if v_wallet.balance_inr < p_amount then
    raise exception 'Insufficient balance' using errcode = '22003';
  end if;

  v_spent := case
    when v_wallet.spent_on = current_date then v_wallet.spent_today_inr
    else 0
  end + p_amount;

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

revoke all on function public.debit_wallet(uuid, numeric, text, text, text)
  from public, anon, authenticated;
grant execute on function public.debit_wallet(uuid, numeric, text, text, text)
  to service_role;

commit;
