# projectmem - Bridgy

_Last updated: 2026-10-24_

## Project purpose
A new Flutter project.

## Recent issues
- No issues logged yet.

## Decisions
- ADB execution goes through Termux RUN_COMMAND with the command allow-list enforced in server/agent.js; dadb is deferred. Termux needs no extra gradle dependency and the allow-list rejects shell metacharacters before anything reaches the phone. [server/agent.js]
- Supabase is optional at runtime: BridgyBackend.enabled gates Supabase.initialize behind --dart-define=SUPABASE_URL/SUPABASE_ANON_KEY, so the policy editor and UPI checkout work offline in local mode. Keeps the demo independent of credentials. [lib/services/backend.dart]

## Notes
- first commit
- gotcha: Android build needs a full JDK, not a JRE. Flutter picks Android Studio JBR 25 by default, which Gradle 8.14 rejects; `flutter config --jdk-dir /opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home` fixes both the Java version and missing javac. [android/gradle/wrapper/gradle-wrapper.properties]
- gotcha: Pesse design system is matte gold #C9A961 with Fraunces/Manrope/Playfair Display italic + JetBrains Mono bundled in assets/fonts. Widget tests must load those fonts via FontLoader, otherwise Ahem metrics cause RenderFlex overflows. Use `flutter build web -t tool/preview.dart` and `?screen=send|cards` for visual previews. [lib/theme.dart]
- New feature: feat: add Pesse design system with home, select card, and send money screens [design-reference/gold/home.html]
- gotcha: Bridgy shell bridge needs Termux RUN_COMMAND with allow-external-apps=true and a pre-paired `adb connect localhost:<port>`; `readScreenDump` only works after granting All files access. Overlay entry point must be a top-level `overlayMain` in lib/main.dart because the plugin resolves it by name in the default app bundle. [android/app/src/main/kotlin/com/bridgy/bridgy/MainActivity.kt]
- Bridgy agent stack: Agent screen (fast mode replays lib/services/macro.dart calibrated fractions; live mode posts uiautomator XML to /api/agent/next-adb), floating HUD via flutter_overlay_window, policy/UPI logic in lib/services/policy.dart + upi.dart with tests. Owner keys stay server-side; never store owner_private_key in Supabase as prd.md suggests.
- Wallet schema lives in server/schema.sql and intentionally omits owner_private_key/agent_session_key from prd.md. RLS policies are demo-permissive (true) because there is no auth yet; tighten before real use. [server/schema.sql]
- gotcha: Bridgy's on-device agent needs three pieces together — AgentAccessibilityService declared in AndroidManifest with BIND_ACCESSIBILITY_SERVICE, AccessibilityBridge.attach() called from MainActivity.configureFlutterEngine, and ScreenAutomationService using channel com.bridgy.bridgy/accessibility. Missing any one leaves live mode returning SERVICE_NOT_RUNNING. [android/app/src/main/AndroidManifest.xml]
- gotcha: Android 13+ clears accessibility for adb-installed apps under restricted settings. Run `adb shell appops set com.bridgy.bridgy ACCESS_RESTRICTED_SETTINGS allow` before enabling Bridgy Screen Control, or the toggle silently disappears. [android/app/src/main/AndroidManifest.xml]

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
