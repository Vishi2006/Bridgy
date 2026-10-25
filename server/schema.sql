-- Bridgy schema for Supabase (run once in the SQL editor).
--
-- Security: no private keys are stored here. The PRD's `owner_private_key` and
-- `agent_session_key` columns are deliberately omitted; those keys stay in the
-- backend `.env`. A leaked database must never leak a signing key.
--
-- DEMO LEDGER: this single-wallet schema is open to the anon key so the demo
-- works without a login. Wallet top-ups are ledger credits, not real money.
-- Before production: add `owner_id uuid references auth.users`, scope every row
-- to `auth.uid()`, revoke `wallet_topup` from anon, and route credits through
-- the service role only.

create table if not exists wallets (
  id uuid primary key default gen_random_uuid(),
  smart_wallet_address text not null default 'pending',
  balance_inr numeric not null default 500,
  per_tx_limit_inr numeric not null default 200,
  daily_limit_inr numeric not null default 500,
  spent_today_inr numeric not null default 0,
  policy_expiry timestamptz default (now() + interval '24 hours'),
  created_at timestamptz default now()
);

create table if not exists terminal_logs (
  id bigserial primary key,
  command text not null,
  agent_thought text,
  created_at timestamptz default now()
);

create table if not exists transactions (
  id uuid primary key default gen_random_uuid(),
  wallet_id uuid references wallets(id) on delete cascade,
  merchant_name text,
  merchant_vpa text,
  amount_inr numeric not null,
  status text not null, -- AGENT_PAID | PENDING_OWNER_APPROVAL | OWNER_PAID | TOPUP
  tx_hash text,
  created_at timestamptz default now()
);

create table if not exists topups (
  id uuid primary key default gen_random_uuid(),
  wallet_id uuid not null references wallets(id) on delete cascade,
  amount_inr numeric not null check (amount_inr > 0),
  status text not null default 'PAID' check (status in ('PAID', 'FAILED')),
  rail text not null default 'ledger',
  created_at timestamptz default now()
);

create index if not exists transactions_wallet_created_idx
  on transactions (wallet_id, created_at desc);

-- Atomic credit: balance update, top-up row, and ledger row land together.
drop function if exists wallet_topup(numeric);

create function wallet_topup(p_amount numeric)
returns table (new_balance numeric, transaction_id uuid, topup_id uuid)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_wallet_id uuid;
  v_tx_id uuid;
  v_topup_id uuid;
  v_balance numeric;
  v_amount numeric;
begin
  v_amount := round(p_amount, 2);
  if v_amount is null or v_amount <= 0 or v_amount > 1000000 then
    raise exception 'amount must be greater than 0 and at most 1000000'
      using errcode = '22023';
  end if;

  select w.id into v_wallet_id from wallets w order by w.created_at nulls first limit 1;
  if v_wallet_id is null then
    insert into wallets default values returning id into v_wallet_id;
  end if;

  update wallets w
     set balance_inr = coalesce(w.balance_inr, 0) + v_amount
   where w.id = v_wallet_id
   returning w.balance_inr into v_balance;

  insert into topups (wallet_id, amount_inr, status, rail)
  values (v_wallet_id, v_amount, 'PAID', 'ledger')
  returning id into v_topup_id;

  insert into transactions (wallet_id, merchant_name, amount_inr, status)
  values (v_wallet_id, 'Wallet top-up', v_amount, 'TOPUP')
  returning id into v_tx_id;

  return query select v_balance, v_tx_id, v_topup_id;
end;
$$;

grant execute on function wallet_topup(numeric) to anon, authenticated;

-- Demo-only access: tighten to auth.uid() = owner_id before any real use.
alter table wallets enable row level security;
alter table terminal_logs enable row level security;
alter table transactions enable row level security;
alter table topups enable row level security;

drop policy if exists wallets_demo_all on wallets;
create policy wallets_demo_all on wallets for all using (true) with check (true);

drop policy if exists terminal_logs_demo_all on terminal_logs;
create policy terminal_logs_demo_all on terminal_logs for all using (true) with check (true);

drop policy if exists transactions_demo_all on transactions;
create policy transactions_demo_all on transactions for all using (true) with check (true);

drop policy if exists topups_demo_all on topups;
create policy topups_demo_all on topups for all using (true) with check (true);

insert into wallets (smart_wallet_address)
select 'pending'
where not exists (select 1 from wallets);
