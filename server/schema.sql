-- Bridgy schema for Supabase (run once in the SQL editor).
--
-- Security: no private keys are stored here. The PRD's `owner_private_key` and
-- `agent_session_key` columns are deliberately omitted; those keys stay in the
-- backend `.env`. A leaked database must never leak a signing key.

create table if not exists wallets (
  id uuid primary key default gen_random_uuid(),
  smart_wallet_address text not null default 'pending',
  balance_inr numeric default 500,
  per_tx_limit_inr numeric default 200,
  daily_limit_inr numeric default 500,
  spent_today_inr numeric default 0,
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
  merchant_name text,
  merchant_vpa text,
  amount_inr numeric,
  status text, -- AGENT_PAID | PENDING_OWNER_APPROVAL | OWNER_PAID
  tx_hash text,
  created_at timestamptz default now()
);

-- Demo-only policies: the app holds no user session yet, so the anon key needs
-- read/write on these rows. Tighten to auth.uid() = owner_id before any real use.
alter table wallets enable row level security;
alter table terminal_logs enable row level security;
alter table transactions enable row level security;

drop policy if exists wallets_demo_all on wallets;
create policy wallets_demo_all on wallets for all using (true) with check (true);

drop policy if exists terminal_logs_demo_all on terminal_logs;
create policy terminal_logs_demo_all on terminal_logs for all using (true) with check (true);

drop policy if exists transactions_demo_all on transactions;
create policy transactions_demo_all on transactions for all using (true) with check (true);

insert into wallets (smart_wallet_address)
select 'pending'
where not exists (select 1 from wallets);
