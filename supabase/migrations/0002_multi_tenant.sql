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

-- 2. Drop the single-wallet demo rows.
delete from public.topups;
delete from public.transactions;
delete from public.wallets;

-- 3. Owner columns.
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

-- 4. PSP columns. Razorpay payment links are the default rail.
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

-- 5. Owner-scoped reads.
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

-- 6. New users get a profile and an empty wallet in one trigger.
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

-- 7. Backfill wallets for users created before this migration.
insert into public.wallets (owner_id)
select u.id from auth.users u
on conflict (owner_id) do nothing;

-- 8. Atomic, idempotent credit. Service role only.
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
