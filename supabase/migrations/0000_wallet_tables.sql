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
