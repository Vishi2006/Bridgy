# PRODUCT REQUIREMENTS DOCUMENT (PRD): BRIDGY
**Project Name:** Bridgy  
**Tagline:** *The Autonomous ADB-Powered Screen Layer & Guarded ERC-4337 Wallet for Quick-Commerce*  
**IDE & Build Environment:** Android Studio (Flutter + Native Kotlin Bridge)  
**Target Completion:** 3:00 AM Sprint  
**Team Size:** 2 Developers

---

## 1. Executive Summary & End-to-End Workflow
**Bridgy** acts as an intelligent execution and payment layer over any Android application (Chrome, Rapido, Blinkit, Zepto). It uses **Termux + Local ADB (`android-tools` / `Shizuku rish`)** as "virtual fingers" driven by a **DeepSeek AI Agent**, paired with an **ERC-4337 Smart-Contract Wallet** that enforces strict on-chain spending policies.

### Core User Flow
1. **Voice Trigger:** The user opens Google Assistant / Gemini and says: *"Open Bridgy and book a cab to Manipal on Rapido"* (or *"order milk on Blinkit"*).
2. **Redirect & Layer Setup:** Google redirects the intent + voice text into **Bridgy**. Bridgy starts its **commet browser type border animation on current using app** on the screen and initializes the local ADB/Termux command bridge.
3. **ADB Virtual Fingers (DeepSeek Loop):**
    - Bridgy uses **ADB shell commands** (via Termux `RUN_COMMAND` Intent or local Wireless ADB) to launch the target app (`monkey -p com.rapido.passenger 1`).
    - It dumps the live screen XML (`uiautomator dump`), sends the parsed UI elements to the **Express.js + DeepSeek Backend**, and receives the exact terminal command to run next (`input tap X Y` or `input text "Manipal"`).
4. **UPI Intent Interception & ERC-4337 Checkout:**
    - At checkout, DeepSeek taps **"Pay via UPI -> Bridgy"**.
    - Bridgy intercepts the `upi://pay` URI, checks the bill against the user's **ERC-4337 Session Key Policy** (Allowed Contract, Per-Tx Limit, Daily Limit, Expiry), and executes the payment on **Base Sepolia**.
    - If the price exceeds the policy limit, Bridgy pauses and prompts the human owner for **Owner Key Approval**.

---

# PHASE 1: Core Tech Stack, Termux/ADB Virtual Fingers & Floating Layer

## 1.1 Phase 1 Tech Stack
| Component | Technology | Role in Bridgy |
| :--- | :--- | :--- |
| **App Framework** | **Flutter** (Android Studio) | Main wallet UI, Policy configuration sliders, Top-Up dashboard, and Floating Overlay HUD. |
| **Terminal / ADB Execution** | **Termux (`RUN_COMMAND` API) + Local ADB (`adb` / Shizuku `rish`)** | Executes privileged shell commands (`input tap`, `input swipe`, `input text`, `uiautomator dump`, `am start`) on the phone without needing a PC. |
| **Native Bridge** | **Kotlin (`MethodChannel`)** | Sends commands from Flutter to Termux (`com.termux.RUN_COMMAND`) or direct Wireless ADB (`dadblib`) and reads screen XML output. |
| **Backend Server** | **Node.js + Express.js** | Parses the screen XML dump, queries DeepSeek, and returns the exact `adb shell` command to execute next. |
| **AI Agent Model** | **OpenRouter (`deepseek/deepseek-chat`)** | Translates user intent + current screen coordinates into sequential ADB terminal commands. |
| **Database** | **Supabase (PostgreSQL + Realtime)** | Stores user wallet state, policy rules, and streams real-time ADB terminal commands to the floating screen layer. |

---

## 1.2 How the In-App Termux / Open-Source ADB Execution Works

Standard Android apps cannot run `input tap` on other apps due to sandboxing. You have **two free, open-source ways** to run ADB commands directly from Bridgy on the phone without a laptop:

### Option A: Termux `RUN_COMMAND` Intent + Wireless ADB (Recommended for Termux API)
1. Install **Termux** (from F-Droid/GitHub) and run `pkg install android-tools` inside Termux.
2. Enable **Wireless Debugging** in Android Developer Options and pair Termux once (`adb pair <ip>:<port>` and `adb connect localhost:<port>`).
3. In Termux, enable external app commands by running:
   ```bash
   echo "allow-external-apps = true" >> ~/.termux/termux.properties

```

4. Add permission to Bridgy's `AndroidManifest.xml`:
```xml
<uses-permission android:name="com.termux.permission.RUN_COMMAND" />

```


5. Now, Bridgy's Kotlin code fires background ADB commands silently through Termux!

### Option B: Direct Embedded ADB Library (`dadblib` / `libadb-android`) — Zero Termux App Needed! https://github.com/mobile-dev-inc/dadb

If you don't want to rely on an external Termux installation, add `dev.mobile:dadb:1.2.7` in `android/app/build.gradle`. Bridgy connects directly to `localhost:5555` (Wireless Debugging) from inside your Kotlin code and runs `dadb.shell("input tap 500 800")` natively!

---

## 1.3 Complete ADB Command Cheat Sheet Used by Your DeepSeek Agent

Your Express backend will instruct Bridgy to run these exact commands:

```bash
# 1. Open Target Apps (Chrome, Blinkit, Rapido, Zepto)
adb shell monkey -p com.android.chrome -c android.intent.category.LAUNCHER 1
adb shell monkey -p com.grofers.customerapp -c android.intent.category.LAUNCHER 1  # Blinkit
adb shell monkey -p com.rapido.passenger -c android.intent.category.LAUNCHER 1     # Rapido
adb shell monkey -p com.zeptoconsumerapp -c android.intent.category.LAUNCHER 1     # Zepto

# 2. Read the Current Screen Layout (Dumps clickable buttons & coordinates to XML)
adb shell uiautomator dump /sdcard/window_dump.xml

# 3. Virtual Finger Actions (Generated by DeepSeek)
adb shell input tap 540 380                  # Tap search bar at (X=540, Y=380)
adb shell input text "Manipal"               # Type text (replace spaces with %s: "milk%s1L")
adb shell input keyevent 66                  # Press ENTER / Search key
adb shell input swipe 500 1500 500 400 300   # Scroll down the page

```

---

## 1.4 Kotlin Code: Firing Termux ADB Commands from Flutter (`MainActivity.kt`)

```kotlin
package com.example.bridgy

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.bridgy.app/adb"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "runAdbCommand") {
                val cmd = call.argument<String>("command") ?: ""
                executeViaTermux(cmd)
                result.success("Executed: $cmd")
            }
        }
    }

    private fun executeViaTermux(adbCommand: String) {
        val intent = Intent()
        intent.setClassName("com.termux", "com.termux.app.RunCommandService")
        intent.action = "com.termux.RUN_COMMAND"
        intent.putExtra("com.termux.RUN_COMMAND_PATH", "/data/data/com.termux/files/usr/bin/bash")
        intent.putExtra("com.termux.RUN_COMMAND_ARGUMENTS", arrayOf("-c", adbCommand))
        intent.putExtra("com.termux.RUN_COMMAND_WORKDIR", "/data/data/com.termux/files/home")
        intent.putExtra("com.termux.RUN_COMMAND_BACKGROUND", true)
        startService(intent)
    }
}

```

---

## 1.5 Supabase Database Schema (Phase 1 & 2)

```sql
-- 1. Wallet & ERC-4337 Policy State
CREATE TABLE wallets (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  smart_wallet_address TEXT NOT NULL,
  owner_private_key TEXT NOT NULL,
  agent_session_key TEXT NOT NULL,
  balance_inr NUMERIC DEFAULT 500,
  per_tx_limit_inr NUMERIC DEFAULT 200,
  daily_limit_inr NUMERIC DEFAULT 500,
  spent_today_inr NUMERIC DEFAULT 0,
  policy_expiry TIMESTAMPTZ DEFAULT (NOW() + INTERVAL '24 hours')
);

-- 2. Live ADB Terminal Stream (Displayed in Bridgy's Floating Overlay)
CREATE TABLE terminal_logs (
  id BIGSERIAL PRIMARY KEY,
  command TEXT NOT NULL,
  agent_thought TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 3. Payment & Escalation Queue
CREATE TABLE transactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  merchant_name TEXT,
  merchant_vpa TEXT,
  amount_inr NUMERIC,
  status TEXT, -- 'AGENT_PAID', 'PENDING_OWNER_APPROVAL', 'OWNER_PAID'
  tx_hash TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

```

---

# PHASE 2: ERC-4337 Smart-Contract Policy Wallet & UPI Bridge

## 2.1 Phase 2 Tech Stack

| Component | Technology | Implementation Details |
| --- | --- | --- |
| **EVM Network** | **Base Sepolia Testnet** | Fast 1.5s confirmations, free Testnet ETH. |
| **Account Abstraction** | **ZeroDev SDK (`@zerodev/sdk` + `@zerodev/permissions`)** | Implements ERC-4337 EntryPoint v0.7 with modular Session Keys (`regular` plugin) and Owner Key (`sudo` plugin). |
| **UPI Interceptor** | **Android `<intent-filter>` (`upi://pay`)** | Registers Bridgy as a UPI handler on the device so Blinkit, Rapido, and Zepto show **"Bridgy Wallet"** at checkout. |

---

## 2.2 Enforcing the Problem Statement Policies in Express.js

Every policy required by the problem statement is enforced cryptographically on the agent's session key:

1. **Allowed Contracts & Functions:** `toCallPolicy` locks the session key to standard value transfers on the EntryPoint.
2. **Allowed Recipients:** `target: BRIDGY_SETTLEMENT_VAULT`. Even if a malicious webpage in Chrome injects prompts into DeepSeek, the smart contract rejects sending ETH to any external attacker address.
3. **Per-Transaction Limits:** `valueLimit: parseEther("0.002")` (Mapped at `0.001 ETH = ₹100 INR`, so `0.002 ETH = ₹200` max per order).
4. **Daily Limits:** Enforced via cumulative gas/spend policy + Supabase `spent_today_inr` check before bundler submission.
5. **Permission Expiry:** `toTimestampPolicy({ validAfter, validUntil })` enforced natively by the ERC-4337 EntryPoint.
6. **Owner Approval Outside Policy:** When `amount_inr > per_tx_limit_inr` (e.g., a ₹380 Blinkit cart on a ₹200 limit), the `agent_session_key` reverts. Bridgy surfaces a **Biometric Owner Approval Modal** on screen and signs with the `sudo` (`owner_private_key`) validator upon user confirmation.

---

## 2.3 UPI Interception Setup (`AndroidManifest.xml`)

Add this inside `android/app/src/main/AndroidManifest.xml` so Bridgy appears in the UPI chooser of Blinkit, Rapido, and Zepto:

```xml
<!-- Allow Termux ADB Command Execution -->
<uses-permission android:name="com.termux.permission.RUN_COMMAND" />
<!-- Allow Floating Terminal Overlay -->
<uses-permission android:name="android.permission.SYSTEM_ALERT_WINDOW" />
<!-- Allow reading /sdcard/window_dump.xml -->
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.MANAGE_EXTERNAL_STORAGE" />

<application ...>
    <activity
        android:name=".MainActivity"
        android:exported="true"
        android:launchMode="singleTask">
        
        <!-- Standard Launcher -->
        <intent-filter>
            <action android:name="android.intent.action.MAIN"/>
            <category android:name="android.intent.category.LAUNCHER"/>
        </intent-filter>

        <!-- Register Bridgy as a UPI Payment App -->
        <intent-filter>
            <action android:name="android.intent.action.VIEW" />
            <category android:name="android.intent.category.DEFAULT" />
            <category android:name="android.intent.category.BROWSABLE" />
            <data android:scheme="upi" android:host="pay" />
        </intent-filter>
    </activity>
</application>

```

---

# 2-DEVELOPER TASK SPLIT & TIMELINE (UNTIL 3:00 AM)

### Developer 1: Android Studio, Flutter UI & Termux/ADB Bridge

* **9:15 PM – 10:30 PM (Termux + ADB Setup):**
* Install Termux + `android-tools` on the demo phone and connect Wireless ADB (`adb connect localhost:<port>`).
* Implement `MethodChannel("com.bridgy.app/adb")` in `MainActivity.kt` to trigger Termux `RUN_COMMAND` intents (`adb shell monkey`, `adb shell input tap`, `adb shell uiautomator dump`).


* **10:30 PM – 12:00 AM (Floating Overlay & Voice Input):**
* Build the Bridgy home screen with voice/text prompt input (receiving Google Assistant intent) and a **Floating Terminal Overlay** (`flutter_overlay_window`) that displays live ADB commands from Supabase `terminal_logs`.


* **12:00 AM – 1:30 AM (Wallet UI & UPI Interceptor):**
* Build the **Policy Configuration UI** (sliders for Per-Tx Limit ₹200, Daily Limit ₹500, Expiry timer, Top-Up button).
* Add the `upi://pay` listener (via `app_links` package in Flutter) to parse `pa` (merchant VPA) and `am` (INR amount) when DeepSeek clicks Bridgy at checkout.


* **1:30 AM – 3:00 AM (Owner Approval Modal & Live Demo Tuning):**
* Build the **"Out-of-Policy Owner Approval" bottom sheet** (Fingerprint / Approve button) and connect to Developer 2's `/api/wallet/pay-owner` endpoint.



### Developer 2: Express.js, Supabase, DeepSeek XML Parser & ERC-4337

* **9:15 PM – 10:30 PM (Supabase & XML-to-Coordinate Parser):**
* Create the 3 Supabase tables.
* Write a clean regex/XML parser in Express (`xml2js`) that reads `/sdcard/window_dump.xml`, strips useless layout nodes, and extracts only clickable elements with `[xCenter, yCenter]` coordinates so DeepSeek responds in under 1.5 seconds.


* **10:30 PM – 12:00 AM (DeepSeek ADB Agent Endpoint):**
* Build `POST /api/agent/next-adb`: receives `{ userGoal, simplifiedNodes }`, prompts `deepseek/deepseek-chat` via OpenRouter, logs the thought to Supabase `terminal_logs`, and returns the exact ADB command string (e.g., `adb shell input tap 540 1820`).


* **12:00 AM – 1:30 AM (ERC-4337 Smart Wallet with ZeroDev):**
* Implement `wallet.js` on **Base Sepolia** using `@zerodev/sdk` and `@zerodev/permissions`.
* Expose `POST /api/wallet/pay-agent` (uses `agent_session_key` with `toCallPolicy` & `toTimestampPolicy`) and `POST /api/wallet/pay-owner` (uses `owner_private_key` when transaction exceeds policy).


* **1:30 AM – 3:00 AM (End-to-End Integration & Macro Fallback):**
* Test the full loop on Chrome, Rapido, and Blinkit.
* **Crucial Backup Trick:** Add a `"fastMode": true` flag in Express with pre-calibrated `(x, y)` coordinates for your specific demo phone's screen resolution so that even if hotel/college Wi-Fi lags during `uiautomator dump`, the ADB taps execute flawlessly on stage!



```

### Quick Tip for Your Termux Setup Tonight
When `uiautomator dump` runs via ADB, it takes ~1.5 seconds to dump the screen XML. To make your demo blazingly fast on stage, have Developer 1 run `adb shell wm size` on your test phone right now to see your phone's exact resolution (e.g., `1080x2400`), and turns on **"Pointer Location"** in Android Developer Options for 5 minutes—that shows the exact `(X, Y)` coordinates of the Rapido/Blinkit search bar and buttons right at the top of your phone screen so you can verify DeepSeek's coordinates immediately!

```