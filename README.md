# Liteflow

Lightweight Flutter (Material 2) app: **notes**, **tasks with reminders**, **alarms** and a **pomodoro timer**.
Android 7.0+ (minSdk 24). Only 4 dependencies, no state-management package, no database (one JSON blob in SharedPreferences).

## Get the APK (GitHub Actions)
1. Push this folder to a GitHub repo (`main` branch).
2. Open **Actions → Build Android APK**; when it finishes, download the `liteflow-apks` artifact.
   - `liteflow-arm64-v8a-release.apk` - most phones (smallest)
   - `liteflow-armeabi-v7a-release.apk` - older 32-bit phones
   - `liteflow-universal-release.apk` - works everywhere (largest)
3. Push a tag like `v1.0.0` to also publish the APKs on the Releases page.

Optional own signing key: add repo secrets `KEYSTORE_BASE64`, `KEYSTORE_PASSWORD`, `KEY_ALIAS`, `KEY_PASSWORD`.

## Build locally
```
flutter create --platforms=android --org com.lite --project-name liteflow .
flutter pub get
flutter build apk --release --split-per-abi
```

## Notes
- Alarms use exact notifications on the alarm audio stream, the system alarm tone, looping until dismissed, and a full-screen intent on the lock screen.
- Android 12/12L asks for "Alarms & reminders" access; Android 13+ asks for notification permission.
- On aggressive OEM ROMs set battery usage to "Unrestricted" so alarms are not killed.
- The pomodoro timer stores an end timestamp and schedules a notification, so it is accurate in the background.
