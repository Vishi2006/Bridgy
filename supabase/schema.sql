-- Bridgy full schema. Paste this whole file into the Supabase SQL editor
-- (or run: supabase db push). It is idempotent: every table, index,
-- policy, trigger, and function uses IF NOT EXISTS / OR REPLACE / DROP IF EXISTS.

-- Baseline wallet tables. Run this before 0001/0002/0003.
--
-- 0002 adds owner_id, removes the demo rows, and turns on per-user RLS. On a
-- fresh project this file must run first, otherwise 0002 has no tables to
-- alter. Balances start at zero: no free demo credit.

create table if not exists public.wallets (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid references auth.users(id) on delete cascade,
  smart_wallet_address text not null default 'pending',
  balance_inr numeric not null default 0,
  per_tx_limit_inr numeric not null default 200,
  daily_limit_inr numeric not null default 500,
  spent_today_inr numeric not null default 0,
  spent_on date not null default current_date,
  policy_expiry timestamptz default (now() + interval '24 hours'),
  created_at timestamptz default now()
);

create table if not exists public.terminal_logs (
  id bigserial primary key,
  command text not null,
  agent_thought text,
  created_at timestamptz default now()
);

create table if not exists public.transactions (
  id uuid primary key default gen_random_uuid(),
  wallet_id uuid references public.wallets(id) on delete cascade,
  owner_id uuid references auth.users(id) on delete cascade,
  merchant_name text,
  merchant_vpa text,
  amount_inr numeric not null,
  status text not null,
  tx_hash text,
  created_at timestamptz default now()
);

create table if not exists public.topups (
  id uuid primary key default gen_random_uuid(),
  wallet_id uuid not null references public.wallets(id) on delete cascade,
  owner_id uuid references auth.users(id) on delete cascade,
  amount_inr numeric not null check (amount_inr > 0),
  status text not null default 'PENDING'
    check (status in ('PENDING', 'PAID', 'FAILED', 'EXPIRED')),
  provider text not null default 'razorpay',
  provider_order_id text,
  provider_payment_id text,
  checkout_url text,
  transaction_id uuid references public.transactions(id),
  created_at timestamptz default now()
);

create index if not exists transactions_wallet_created_idx
  on public.transactions (wallet_id, created_at desc);
create index if not exists transactions_owner_created_idx
  on public.transactions (owner_id, created_at desc);
create index if not exists topups_owner_created_idx
  on public.topups (owner_id, created_at desc);
create unique index if not exists topups_provider_order_unique
  on public.topups (provider_order_id) where provider_order_id is not null;
create unique index if not exists topups_provider_payment_unique
  on public.topups (provider_payment_id) where provider_payment_id is not null;

-- Phase 1: one profile per auth user.
--
-- The trigger runs as the function owner because auth.users is not writable by
-- the app. Reads are limited to the signed-in user; updates may only touch
-- their own row.

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text,
  onboarding_completed boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.profiles enable row level security;

drop policy if exists profiles_select_own on public.profiles;
create policy profiles_select_own on public.profiles
  for select using (auth.uid() = id);

drop policy if exists profiles_update_own on public.profiles;
create policy profiles_update_own on public.profiles
  for update using (auth.uid() = id) with check (auth.uid() = id);

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, email)
  values (new.id, new.email)
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

grant select, update on public.profiles to authenticated;
grant all on public.profiles to service_role;

-- Phase 2: multi-tenant wallet, transactions, and PSP top-ups.
--
-- Every row belongs to an auth user. Reads are limited to the owner; all
-- writes go through the backend using the service role, so authenticated
-- clients get no insert/update policy.
--
-- The demo rows from the single-wallet build are discarded here. They were
-- test credits, not user money.

begin;

-- 1. Remove the demo-only policies and public grants.
drop policy if exists wallets_demo_all on public.wallets;
drop policy if exists transactions_demo_all on public.transactions;
drop policy if exists topups_demo_all on public.topups;
drop policy if exists terminal_logs_demo_all on public.terminal_logs;

revoke all on public.wallets from anon;
revoke all on public.transactions from anon;
revoke all on public.topups from anon;
revoke all on public.terminal_logs from anon;
revoke insert, update, delete on public.wallets from authenticated;
revoke insert, update, delete on public.transactions from authenticated;
revoke insert, update, delete on public.topups from authenticated;

-- 2. Ensure the wallet foreign keys exist on databases created before 0000.
alter table public.transactions
  add column if not exists wallet_id uuid references public.wallets(id) on delete cascade;
alter table public.topups
  add column if not exists wallet_id uuid references public.wallets(id) on delete cascade;

-- 3. Drop the single-wallet demo rows.
delete from public.topups;
delete from public.transactions;
delete from public.wallets;

-- 4. Owner columns.
alter table public.wallets
  add column if not exists owner_id uuid references auth.users(id) on delete cascade;
alter table public.wallets alter column owner_id set not null;
create unique index if not exists wallets_owner_unique on public.wallets (owner_id);

alter table public.transactions
  add column if not exists owner_id uuid references auth.users(id) on delete cascade;
alter table public.transactions alter column owner_id set not null;
create index if not exists transactions_owner_created_idx
  on public.transactions (owner_id, created_at desc);

alter table public.topups
  add column if not exists owner_id uuid references auth.users(id) on delete cascade;
alter table public.topups alter column owner_id set not null;
create index if not exists topups_owner_created_idx
  on public.topups (owner_id, created_at desc);

-- 5. PSP columns. Razorpay payment links are the default rail.
alter table public.topups
  add column if not exists provider text not null default 'razorpay';
alter table public.topups
  add column if not exists provider_order_id text;
alter table public.topups
  add column if not exists provider_payment_id text;
alter table public.topups
  add column if not exists checkout_url text;
alter table public.topups
  add column if not exists transaction_id uuid references public.transactions(id);
alter table public.topups
  alter column status set default 'PENDING';

alter table public.topups drop constraint if exists topups_status_check;
alter table public.topups add constraint topups_status_check
  check (status in ('PENDING', 'PAID', 'FAILED', 'EXPIRED'));

create unique index if not exists topups_provider_order_unique
  on public.topups (provider_order_id)
  where provider_order_id is not null;
create unique index if not exists topups_provider_payment_unique
  on public.topups (provider_payment_id)
  where provider_payment_id is not null;

-- 6. Owner-scoped reads.
alter table public.wallets enable row level security;
alter table public.transactions enable row level security;
alter table public.topups enable row level security;

drop policy if exists wallets_select_own on public.wallets;
create policy wallets_select_own on public.wallets
  for select using (auth.uid() = owner_id);

drop policy if exists transactions_select_own on public.transactions;
create policy transactions_select_own on public.transactions
  for select using (auth.uid() = owner_id);

drop policy if exists topups_select_own on public.topups;
create policy topups_select_own on public.topups
  for select using (auth.uid() = owner_id);

grant select on public.wallets to authenticated;
grant select on public.transactions to authenticated;
grant select on public.topups to authenticated;
grant all on public.wallets to service_role;
grant all on public.transactions to service_role;
grant all on public.topups to service_role;

-- 7. New users get a profile and an empty wallet in one trigger.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, email)
  values (new.id, new.email)
  on conflict (id) do nothing;

  insert into public.wallets (owner_id)
  values (new.id)
  on conflict (owner_id) do nothing;

  return new;
end;
$$;

-- 8. Backfill wallets for users created before this migration.
insert into public.wallets (owner_id)
select u.id from auth.users u
on conflict (owner_id) do nothing;

-- 9. Atomic, idempotent credit. Service role only.
drop function if exists public.wallet_topup(numeric);

create or replace function public.credit_topup(
  p_topup_id uuid,
  p_payment_id text
)
returns table (new_balance numeric, transaction_id uuid, topup_status text)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_topup public.topups%rowtype;
  v_balance numeric;
  v_tx uuid;
begin
  select * into v_topup
    from public.topups t
   where t.id = p_topup_id
   for update;

  if not found then
    raise exception 'topup % not found', p_topup_id using errcode = 'P0002';
  end if;

  if v_topup.status = 'PAID' then
    select w.balance_inr into v_balance
      from public.wallets w
     where w.owner_id = v_topup.owner_id;
    return query select v_balance, v_topup.transaction_id, 'PAID'::text;
    return;
  end if;

  if v_topup.status <> 'PENDING' then
    raise exception 'topup % is %', p_topup_id, v_topup.status
      using errcode = '22023';
  end if;

  update public.wallets w
     set balance_inr = w.balance_inr + v_topup.amount_inr
   where w.owner_id = v_topup.owner_id
   returning w.balance_inr into v_balance;

  if v_balance is null then
    raise exception 'wallet missing for owner %', v_topup.owner_id
      using errcode = 'P0002';
  end if;

  insert into public.transactions
    (owner_id, wallet_id, merchant_name, amount_inr, status, tx_hash)
  values
    (v_topup.owner_id, v_topup.wallet_id, 'Wallet top-up',
     v_topup.amount_inr, 'TOPUP', p_payment_id)
  returning id into v_tx;

  update public.topups t
     set status = 'PAID',
         provider_payment_id = coalesce(p_payment_id, t.provider_payment_id),
         transaction_id = v_tx
   where t.id = p_topup_id;

  return query select v_balance, v_tx, 'PAID'::text;
end;
$$;

revoke all on function public.credit_topup(uuid, text) from public, anon, authenticated;
grant execute on function public.credit_topup(uuid, text) to service_role;

commit;

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
