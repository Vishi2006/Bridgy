# projectmem - Bridgy

_Last updated: 2026-10-25_

## Project purpose
A new Flutter project.

## Recent issues
- [OPEN] #0003 Deployed https://bridgy-backend.vercel.app still returns 404 for /api/wallet/balance and /api/wallet/topup. The release app therefore shows the 404 HTML verbatim after sign-in; live balance, top-up, and payments need Backend/ deployed with the new routes and env vars. [Backend/server.js] (open)
- [DONE] #0002 AI Agents hit OpenRouter credit limit because a stale shell-exported OPENROUTER_API_KEY overrode server/.env [server/config.js] -> server/config.js reads the key from server/.env only; model fixed to deepseek/deepseek-v4.1-flash-1017. Stale-env smoke test returned 200, npm test 6/6, flutter test 19/19. [server/config.js] (fixed)
- [DONE] #0001 PolicyController.save inserts agent_session_key, but server/schema.sql omits that column, so Supabase save fails when no wallet row exists. [lib/state/policy_controller.dart] -> Removed agent_session_key from the wallets insert in PolicyController.save and Backend pay-agent upsert. Policy save now reports backend success even when the Supabase mirror fails. flutter test 19/19. [lib/state/policy_controller.dart] (fixed)

## Decisions
- ADB execution goes through Termux RUN_COMMAND with the command allow-list enforced in server/agent.js; dadb is deferred. Termux needs no extra gradle dependency and the allow-list rejects shell metacharacters before anything reaches the phone. [server/agent.js]
- Supabase is optional at runtime: BridgyBackend.enabled gates Supabase.initialize behind --dart-define=SUPABASE_URL/SUPABASE_ANON_KEY, so the policy editor and UPI checkout work offline in local mode. Keeps the demo independent of credentials. [lib/services/backend.dart]
- AppShell wraps the tabs with a nested Navigator so the bottom footer stays visible on detail pages (send money, Termux); system back uses NavigatorPopHandler. [lib/screens/app_shell.dart]
- Bridgy is the public product name for the app and README. The Android launcher label and MaterialApp title now use Bridgy; internal Unipay design-token filenames stay for compatibility. [README.md]
- Bridgy server reads OPENROUTER_API_KEY from server/.env only and hardcodes deepseek/deepseek-v4.1-flash-1017 in server/config.js. Ambient process env and client model fields are ignored; Node --env-file silently loses to exported vars, so no env-file launch is used. [server/config.js]
- The Flutter app ships the Supabase project URL and public anon key as compile-time defaults, gates startup on Google OAuth through supabase_flutter's deep-link flow (bridgy://login-callback), and defaults the agent proxy to https://bridgy-backend.vercel.app. Overrides stay available via --dart-define. [lib/services/backend.dart]
- Wallet top-up is a Supabase ledger credit, not a PSP payment. POST /api/wallet/topup calls the wallet_topup RPC and returns the authoritative balance; the app applies that balance, polls /api/wallet/balance every 5s, and shows backend errors verbatim instead of a local fallback. [Backend/ledger.js]
- Backend/ is the only backend; server/ is deleted. supabase/migrations 0000-0004 own the schema. Wallet routes require a Supabase JWT and write with the service role. Top-up uses Razorpay payment links plus a signed webhook; merchant payouts are gated behind MERCHANT_SETTLEMENT_READY and return 503 SETTLEMENT_NOT_CONFIGURED until a payout rail exists. [Backend/server.js]
- The old Base Sepolia owner key was exposed in chat and is rotated. The new key is in Backend/.env; ZeroDev project b716b19b-2b5f-4791-81e7-2baf1c671981 derives smart account 0x1a4243B7baEF5c16D3D11009Aace6CBF2df498c2 on Base Sepolia. Replace OWNER_PRIVATE_KEY on Vercel with the new value; the old key had 0 ETH. [Backend/.env]

## Notes
- gotcha: wallet_topup cannot return a column named balance_inr; PL/pgSQL resolves it as ambiguous against wallets.balance_inr. Return it as new_balance. The live Supabase schema was applied through the Management API with the CLI keychain token, not the dashboard. [server/schema.sql]
- New feature: feat: add email auth, profiles, and wallet ledger top-up [Backend/ledger.js]
- New feature: feat: per-user auth, RLS, Razorpay top-up, and atomic wallet ledger [Backend/auth.js]
- New feature: feat: base sepolia receive screen and signed release build [Backend/server.js]
- gotcha: release signing uses android/key.properties and android/app/bridgy-release.jks, both gitignored. Back them up; losing them blocks Play updates. SHA-1 0B:1F:DB:22:7D:BA:92:BE:35:86:D5:5E:B4:7C:3E:D6:C1:B3:EC:30, SHA-256 61:1A:F8:B2:B9:0B:BC:CD:48:6B:2D:F1:95:BC:91:26:0A:64:E6:B5:D8:7A:BB:FD:29:21:0A:4E:AF:27:F2:B0. Backend/.env holds the Base Sepolia owner key (0xA00B4c7954F40B896037B884BDCCc8d6565C960b); back it up too. [android/app/build.gradle.kts]
- gotcha: Supabase migrations must run in order 0000_wallet_tables, 0001_profiles, 0002_multi_tenant, 0003_debit, 0004_debit_caps. 0001 alone is not a full schema. The full set was verified by applying a rewritten copy to a throwaway schema inside begin/rollback. auth.users is empty until someone signs up in the app; an empty SQL editor result is expected before the first account. [supabase/migrations/0000_wallet_tables.sql]
- New feature: feat: forward auth callbacks, Google logo, and testnet top-up path [Backend/server.js]
- gotcha: the live Vercel env has no SUPABASE_SERVICE_ROLE_KEY. The current Backend/server.js throws at boot without it, so the deploy would 500. Copy the value from Backend/.env. AGENT_API_KEY is still the placeholder sk-or-v1-your-key-here; replace it with a real OpenRouter key or remove it and set OPENROUTER_API_KEY. [Backend/server.js]
- gotcha: the Supabase project Site URL is still http://localhost:3000 and the CLI token gets HTTP 403 when patching auth config. Set Site URL to an https URL and keep bridgy://login-callback in Redirect URLs in the dashboard. Backend /auth/callback now forwards query+fragment to bridgy://login-callback and shows an Open Bridgy button; the app also verifies token_hash links itself. [Backend/server.js]
- Google OAuth setup: Supabase uses a Web application client with redirect https://zgkxfxehrjnncqgoqdog.supabase.co/auth/v1/callback. Android client (optional, native sign-in only) needs package com.bridgy.bridgy and SHA-1 release 0B:1F:DB:22:7D:BA:92:BE:35:86:D5:5E:B4:7C:3E:D6:C1:B3:EC:30 or debug 4A:99:54:29:B7:2B:6F:A6:DE:3B:10:58:4D:B6:D6:3A:8E:43:26:C5. The consent-screen logo is Google Cloud branding, not app code. [android/app/bridgy-release.jks]

## Key files
- `.gitignore`
- `.metadata`
- `README.md`
- `analysis_options.yaml`
- `android/.gitignore`
- `android/app/build.gradle.kts`
- `android/app/src/debug/AndroidManifest.xml`
- `android/app/src/main/AndroidManifest.xml`
- `android/app/src/main/kotlin/com/bridgy/bridgy/MainActivity.kt`
- `android/app/src/main/res/drawable-v21/launch_background.xml`
- `android/app/src/main/res/drawable/launch_background.xml`
- `android/app/src/main/res/mipmap-hdpi/ic_launcher.png`
- `android/app/src/main/res/mipmap-mdpi/ic_launcher.png`
- `android/app/src/main/res/mipmap-xhdpi/ic_launcher.png`
- `android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png`
- `android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png`
- `android/app/src/main/res/values-night/styles.xml`
- `android/app/src/main/res/values/styles.xml`
- `android/app/src/profile/AndroidManifest.xml`
- `android/build.gradle.kts`

## Open questions
- None logged yet.
