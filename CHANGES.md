# Summary of Changes

This document outlines all features, native bridges, backend integrations, and deep-link setups implemented for **Bridgy**.

---

## 1. Zero Termux — Option B (`dadb`) Implementation
* **Native Android Gradle (`android/app/build.gradle.kts`)**:
  - Embedded `dev.mobile:dadb:1.2.7` to connect directly to `localhost:5555` (Wireless Debugging).
* **Native Bridge (`MainActivity.kt`)**:
  - Implemented ADB execution routines over `MethodChannel("com.bridgy.app/adb")`.
  - Added native intent handlers: `openOverlaySettings` and `openDeveloperSettings`.
  - Ensured `onNewIntent` calls `setIntent(intent)` so incoming deep links route to Flutter even when the app is already in the background (`singleTask`).

---

## 2. Google Auth & Keystore Configuration
Extracted package name and debug keystore certificate fingerprints for Google Cloud / Firebase authentication:
- **Package Name**: `com.bridgy.bridgy`
- **SHA-1 Fingerprint**: `B7:AE:28:C0:AB:01:86:31:5B:F6:C9:41:BB:76:C4:93:0D:75:2C:14`
- **SHA-256 Fingerprint**: `7C:79:72:02:A9:F6:04:2B:F7:73:6A:4F:EC:46:20:E1:8B:21:24:63:8D:F6:6C:AA:1B:FB:23:78:BE:CD:09:8F`

---

## 3. Email Verification & Auth Deep Links
* **Android Manifest (`android/app/src/main/AndroidManifest.xml`)**:
  - Added `<intent-filter>` for custom scheme `bridgy://` (`bridgy://login-callback`, `bridgy://verify`, `bridgy://auth-callback`).
  - Added `<intent-filter>` for package scheme `com.bridgy.bridgy://`.
* **Flutter Deep Link Dispatcher (`lib/main.dart`)**:
  - Unified deep link listener handling both `upi://pay` checkout intents and `bridgy://` / `com.bridgy.bridgy://` auth callbacks.
  - Automatically recovers Supabase session from URL tokens/code via `getSessionFromUrl(uri)`.
  - Displays a branded "Email Verified!" dialog welcoming the user back into the app.

---

## 4. Unified Backend (`Backend/`)
Created a centralized Express server connecting Supabase with the DeepSeek/OpenRouter AI Agent engine.

### Files Created:
1. **`Backend/package.json`**:
   - Dependencies: `express`, `@supabase/supabase-js`, `cors`, `dotenv`, `xml2js`.
2. **`Backend/.env`**:
   - `PORT=8787` (matches `agent_screen.dart` and `AiService` defaults).
   - Supabase project credentials: Project Ref `zgkxfxehrjnncqgoqdog`, URL, and Anon Key.
   - `APP_REDIRECT_URL=bridgy://login-callback`.
   - Server-side AI configuration: `AGENT_API_KEY`, `AGENT_BASE_URL`, and `AGENT_MODEL`.
3. **`Backend/agent.js`**:
   - `parseScreen(xml)`: extracts clickable nodes and center coordinates using `xml2js`.
   - `validateCommand(command)`: security regex validator against shell metacharacters.
   - `askModel({ userGoal, nodes })`: calls AI provider using the server's `AGENT_API_KEY`.
4. **`Backend/server.js`**:
   - `GET /health`: reports server status, Supabase connection, and agent key status.
   - `POST /api/agent/next-adb`: PRD ADB virtual finger loop; parses screen XML, queries DeepSeek, validates command, and syncs to Supabase `terminal_logs`.
   - `POST /v1/chat/completions`: OpenAI-compatible proxy for `AiService`, injecting the server-side API key so the phone does not need to store it.
   - `GET /auth/callback`: Supabase email verification intermediary that exchanges tokens and redirects HTTP 302 to `bridgy://login-callback`.
   - `POST /api/auth/signup` & `POST /api/auth/login`: Direct Supabase auth endpoints.
   - `POST /api/terminal-logs`: Syncs logs to Supabase table.

---

## 5. Frontend AI Service Optimization (`lib/services/ai_service.dart`)
- Updated `_defaultBaseUrl` to point to the backend proxy (`http://10.0.2.2:8787`).
- Added `isBackendProxy` detection: when pointed at the backend, `isConfigured` is automatically `true` without the user having to type an API key on their phone.
- Conditional header handling: omits the client `Authorization` header when empty so the backend securely injects the server-side `AGENT_API_KEY`.
- Updated `lib/screens/agent_chat_screen.dart` to display backend connection status.

---

## 6. Testing & Quality Verification
- `flutter analyze` completed with 0 compilation errors.
- `flutter test` passed all 19 test suites across `macro_test.dart`, `policy_test.dart`, `upi_checkout_test.dart`, and `widget_test.dart`.
- Verified `Backend/server.js` health check at `http://localhost:8787/health`, confirming `supabase: connected` and `agentKeyConfigured: true`.

---

## 7. Vercel Deployment Configuration
- Added root [`vercel.json`](file:///d:/coding/Bridgy/vercel.json) rewrite rule routing `/(.*)` to `/api/index.js`.
- Added root [`package.json`](file:///d:/coding/Bridgy/package.json) so Vercel installs dependencies when building from repository root.
- Created root [`api/index.js`](file:///d:/coding/Bridgy/api/index.js) and [`Backend/api/index.js`](file:///d:/coding/Bridgy/Backend/api/index.js) serverless function entry points.
- Created [`Backend/vercel.json`](file:///d:/coding/Bridgy/Backend/vercel.json) in case Vercel's Root Directory setting is set to `Backend`.
- Added `GET /` endpoint in `Backend/server.js` so accessing the root URL returns a 200 OK status page instead of a 404 "page doesn't exist".
- Updated `Backend/server.js` to guard `app.listen` when running in Vercel's serverless environment (`if (!process.env.VERCEL)`).

---

## 8. ZeroDev ERC-4337 Smart Account & Session Key Policy Engine (Base Sepolia)
Implemented the MetaMask-style dual-key security architecture using pure JavaScript (ESM) without needing to write Solidity from scratch during the hackathon.

### Architecture & Security Rules:
1. **Master Key (Human Owner)**: Sudo validator with 100% authority. Can override policy limits via biometric/fingerprint auth and renew or revoke session permissions.
2. **Session Key (AI Agent)**: Restricted cryptographic key provided to the Express backend and DeepSeek agent, bound by strict on-chain policies:
   - **Timestamp Expiry**: Automatically self-destructs after 24 hours (`toTimestampPolicy`).
   - **Spending Limit**: Hard cap of ₹200 / 0.002 ETH per transaction (`toCallPolicy`).
   - **Allowed Recipient Whitelist**: Restricted strictly to the settlement vault contract (`BRIDGY_UPI_VAULT`).
3. **Resilient Dual-Mode Fallback**: Runs out of the box with simulated in-memory keys and UserOps so frontend demos never block on missing developer credentials. Automatically switches to live Base Sepolia on-chain execution when `ZERODEV_PROJECT_ID` is provided.

### Files Created & Updated:
1. **`Backend/wallet.js`**: Core smart wallet module written in ESM JavaScript using `@zerodev/sdk`, `@zerodev/ecdsa-validator`, `@zerodev/permissions`, and `viem`. Implements `initSmartAccount()`, `executeAgentPayment()`, `executeOwnerPayment()`, `renewSessionKey()`, and `updatePolicyLimits()`.
2. **`Backend/server.js`**:
   - `GET /api/wallet/status`: returns smart account address, agent key, network, and policy details.
   - `POST /api/wallet/pay-agent`: verifies policy and executes autonomous agent transaction.
   - `POST /api/wallet/pay-owner`: executes owner-authorized transaction when limit is exceeded.
   - `POST /api/wallet/renew-session`: refreshes session key for another 24 hours.
   - `GET /dashboard`: Judge-facing live status dashboard with key badges, policy checklist, interactive test buttons, and real-time transaction ledger.
3. **`lib/services/wallet_service.dart`**: Flutter HTTP service bridge connecting the mobile app to backend wallet endpoints with automatic error and fallback handling.
4. **`lib/state/policy_controller.dart`**: Synchronizes live smart wallet address and session key limits from the backend into the application state.
5. **`lib/screens/policy_screen.dart`**: Displays Base Sepolia smart account address with copy action, session key active badge, interactive limit sliders, and "Renew 24h" button.
6. **`lib/screens/upi_checkout_screen.dart`**: Fully wired payment flow: in-policy checkouts dispatch autonomously via `payWithAgent`, while amounts > ₹200 trigger the `OwnerApprovalSheet` for biometric authorization via `payWithOwner`.

