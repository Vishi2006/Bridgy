# projectmem - Bridgy

_Last updated: 2026-10-24_

## Project purpose
A new Flutter project.

## Recent issues
- No issues logged yet.

## Decisions
- No decisions logged yet.

## Notes
- first commit
- gotcha: Android build needs a full JDK, not a JRE. Flutter picks Android Studio JBR 25 by default, which Gradle 8.14 rejects; `flutter config --jdk-dir /opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home` fixes both the Java version and missing javac. [android/gradle/wrapper/gradle-wrapper.properties]
- gotcha: Pesse design system is matte gold #C9A961 with Fraunces/Manrope/Playfair Display italic + JetBrains Mono bundled in assets/fonts. Widget tests must load those fonts via FontLoader, otherwise Ahem metrics cause RenderFlex overflows. Use `flutter build web -t tool/preview.dart` and `?screen=send|cards` for visual previews. [lib/theme.dart]

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
