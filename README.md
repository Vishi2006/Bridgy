# Bridgy

Autonomous ADB screen layer plus a guarded wallet. Flutter app drives other
Android apps through Termux `RUN_COMMAND`, and an Express backend turns the
`uiautomator dump` of the current screen into the next tap.

## What runs today

- Home screen (`lib/screens/home_screen.dart`) with an **Agent** entry in the header
  and **Finances** opening the policy editor.
- Agent chat (`lib/screens/agent_chat_screen.dart`): the on-device AI agent ported
  from private-agent. Chat mode talks to the model; Agent mode reads the
  accessibility tree, asks the model for the next step, and taps/types/scrolls
  through any installed app. No Termux or laptop needed. The gear stores the API
  key (defaults to DeepSeek) and the `Termux` pill opens the ADB console.
- ADB console (`lib/screens/agent_screen.dart`): goal input, live terminal log,
  floating HUD toggle, and two modes:
  - **Fast mode** — replays calibrated taps from `lib/services/macro.dart`, no network.
  - **Live mode** — dumps the screen, posts it to the backend, executes the returned command.
- Policy screen (`lib/screens/policy_screen.dart`): per-tx and daily sliders,
  expiry presets, remaining-budget readout, optional Supabase sync.
- UPI checkout (`lib/screens/upi_checkout_screen.dart`): `upi://pay` links open a
  policy decision (allow / owner approval / blocked) with an owner-key sheet.
  The ERC-4337 settlement call is not connected yet, so nothing is charged.
- Native bridge (`android/app/src/main/kotlin/com/bridgy/bridgy/MainActivity.kt`)
  over `MethodChannel("com.bridgy.app/adb")`: `runCommand`, `readScreenDump`,
  `screenSize`, `isTermuxInstalled`, `launchText`.
- Floating overlay HUD (`lib/overlay/bridgy_hud.dart`) rendered from the
  `overlayMain` entry point in `lib/main.dart`.
- Backend (`server/`): `POST /api/agent/next-adb` with XML parsing, an
  allow-listed command validator, and the OpenRouter DeepSeek call.

## Phone setup

For the on-device agent:

1. Install the APK, then open Bridgy → Agent → gear and save an API key
   (DeepSeek by default; base URL and model are editable).
2. Settings → Accessibility → **Bridgy Screen Control** → enable.
3. Run a goal such as "open YouTube" in Agent mode. The agent presses Home,
   reads the screen and drives the app. Notifications need the runtime
   permission on Android 13+.

For the Termux/ADB console:

1. Install Termux (F-Droid), then `pkg install android-tools`.
2. Enable Developer Options → Wireless debugging, then inside Termux:
   `adb pair <ip>:<port>` and `adb connect localhost:<port>`.
3. `echo "allow-external-apps = true" >> ~/.termux/termux.properties` and restart Termux.
4. Grant Bridgy "Display over other apps" and "All files access" (for `window_dump.xml`).
5. Calibrate `lib/services/macro.dart` on the demo phone using Developer
   Options → Pointer location.

## Backend

```sh
cd server
cp .env.example .env   # add OPENROUTER_API_KEY
npm install
npm start              # http://0.0.0.0:8787
npm test               # parser + command validator checks
```

Point the app at the server with
`--dart-define=BRIDGY_AGENT_URL=http://<laptop-lan-ip>:8787`
(defaults to `http://10.0.2.2:8787` for the emulator).

Supabase is optional. Run `server/schema.sql` in the SQL editor, then:

```sh
flutter run \
  --dart-define=SUPABASE_URL=https://<project>.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<publishable key>
```

Without those defines the policy editor and checkout run fully local.

## Security notes

- `OPENROUTER_API_KEY` stays in `server/.env`; it is never shipped in the APK.
- Every model reply is re-validated against an allow-list; shell metacharacters
  are rejected before the command reaches the device.
- The PRD's `owner_private_key` column must not be stored in Supabase. Keep owner
  keys server-side only when the ERC-4337 leg lands.

## Tests

```sh
flutter analyze && flutter test
cd server && npm test
```
