-- Read-only checks for the Supabase SQL editor.

select count(*) as auth_users from auth.users;
select id, email, onboarding_completed, created_at from public.profiles;
select owner_id, balance_inr, per_tx_limit_inr, daily_limit_inr, spent_today_inr, spent_on, policy_expiry from public.wallets;
select owner_id, merchant_name, amount_inr, status, created_at from public.transactions order by created_at desc limit 20;
select owner_id, amount_inr, status, provider, provider_order_id, provider_payment_id, created_at from public.topups order by created_at desc limit 20;

-- RLS is on and authenticated has no write policy.
select tablename, policyname, cmd from pg_policies where schemaname = 'public' order by tablename;
