# projectmem - Bridgy

_Last updated: 2026-10-25_

## Project purpose
A new Flutter project.

## Recent issues
- [OPEN] #0001 PolicyController.save inserts agent_session_key, but server/schema.sql omits that column, so Supabase save fails when no wallet row exists. [lib/state/policy_controller.dart] (open)
- [DONE] #0002 AI Agents hit OpenRouter credit limit because a stale shell-exported OPENROUTER_API_KEY overrode server/.env [server/config.js] -> server/config.js reads the key from server/.env only; model fixed to deepseek/deepseek-v4.1-flash-1017. Stale-env smoke test returned 200, npm test 6/6, flutter test 19/19. [server/config.js] (fixed)

## Decisions
- ADB execution goes through Termux RUN_COMMAND with the command allow-list enforced in server/agent.js; dadb is deferred. Termux needs no extra gradle dependency and the allow-list rejects shell metacharacters before anything reaches the phone. [server/agent.js]
- Supabase is optional at runtime: BridgyBackend.enabled gates Supabase.initialize behind --dart-define=SUPABASE_URL/SUPABASE_ANON_KEY, so the policy editor and UPI checkout work offline in local mode. Keeps the demo independent of credentials. [lib/services/backend.dart]
- AppShell wraps the tabs with a nested Navigator so the bottom footer stays visible on detail pages (send money, Termux); system back uses NavigatorPopHandler. [lib/screens/app_shell.dart]
- Bridgy is the public product name for the app and README. The Android launcher label and MaterialApp title now use Bridgy; internal Unipay design-token filenames stay for compatibility. [README.md]
- Bridgy server reads OPENROUTER_API_KEY from server/.env only and hardcodes deepseek/deepseek-v4.1-flash-1017 in server/config.js. Ambient process env and client model fields are ignored; Node --env-file silently loses to exported vars, so no env-file launch is used. [server/config.js]

## Notes
- New feature: feat: add on-device agent and policy wallet flow [android/app/src/main/kotlin/com/bridgy/bridgy/AccessibilityBridge.kt]
- gotcha: AppShell builds all IndexedStack tabs eagerly, so AgentChatScreen._init starts a 3s accessibility MethodChannel timeout in widget tests. Mock channel com.bridgy.bridgy/accessibility and call SharedPreferences.setMockInitialValues in setUp. [test/widget_test.dart]
- gotcha: adb-kt 1.0.0/1.0.13 on JitPack is compiled with Kotlin 2.4 metadata; this app uses Kotlin 2.2.20, so the dependency fails with 'incompatible version of Kotlin'. Upgrade Kotlin/KSP together before adding it. AccessibilityService remains the working on-device agent transport. [android/app/build.gradle.kts]
- Unipay AI path: Flutter calls the Express proxy at /api/chat/completions; the proxy streams OpenRouter model deepseek/deepseek-v4.1-flash-1017 and keeps the key in gitignored server/.env. Start with npm start (node --env-file=.env). [server/index.js]
- gotcha: README art is rendered from real demo-phone screenshots using the replicate-this palette and fonts. The fonts are used only to render PNG/GIF assets and are not committed or redistributed. README media lives in docs/media and is not bundled into the APK. [docs/media/]
- New feature: feat: add Breezy landing page [landing/_nuxt/AppFooter.CjLOEwFS.css]
- gotcha: Node --env-file does not override an already-exported variable, so ~/.zshrc export OPENROUTER_API_KEY silently shadowed server/.env. Bridgy now parses server/.env itself; any other tool still inherits the exhausted zshrc key. [server/config.js]
- gotcha: physical-phone builds need a reachable BRIDGY_AGENT_URL. New phone on 192.168.137.x could not reach Mac at 10.58.x, so the agent looped on network errors. Rebuilt with http://127.0.0.1:8787 plus `adb reverse tcp:8787 tcp:8787`. [android/app/build.gradle.kts]
- New feature: feat: add Breezy 3D logo icon set [landing/index.html]
- New feature: feat: finish Bridgy app shell, wallet store, and server config [android/app/src/main/kotlin/com/bridgy/bridgy/AgentAccessibilityService.kt]

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
