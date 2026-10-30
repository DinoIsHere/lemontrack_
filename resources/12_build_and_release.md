# 12 Build and Release

Owner: DevOps Agent. Covers local setup, CI, the APK, and the submission checklist.

## Prerequisites

- Flutter stable (3.24 or later), Dart 3.x. Pin the version in `.fvmrc` if FVM is used.
- Android Studio with Android SDK 34 and build-tools. Accept licenses with `flutter doctor --android-licenses`.
- JDK 17.
- A physical Android 10+ device, or an emulator (API 34, Pixel 6 profile).

## Project setup (WP-01)

```bash
flutter create --org com.lemontrack --platforms android lemontrack
cd lemontrack
```

Add dependencies (versions pinned in `pubspec.yaml` at WP-01 time; use latest stable at that point):

```yaml
dependencies:
  flutter:
    sdk: flutter
  flutter_riverpod:
  riverpod_annotation:
  go_router:
  drift:
  sqlite3_flutter_libs:
  path_provider:
  path:
  flutter_secure_storage:
  dio:
  flutter_local_notifications:
  timezone:
  flutter_timezone:
  intl:
  uuid:
  google_fonts:
  wakelock_plus:

dev_dependencies:
  flutter_test:
    sdk: flutter
  integration_test:
    sdk: flutter
  mocktail:
  build_runner:
  drift_dev:
  riverpod_generator:
  custom_lint:
  riverpod_lint:
```

Lints: `analysis_options.yaml` includes `flutter_lints` and enables `prefer_const_constructors`, `avoid_print`, `use_build_context_synchronously`, `always_declare_return_types`.

Code generation: `dart run build_runner build --delete-conflicting-outputs`. Commit generated files.

## Folder check

Run `scripts/check_structure.sh` (created in WP-01). It fails when:

- A file exists in `lib/domain/` that imports `package:flutter/`.
- A raw `Color(0x` literal appears in `lib/screens/` or `lib/widgets/` outside `lib/widgets/crypto/`.
- A file exceeds 400 lines (split it).

## Commands

| Task | Command |
|---|---|
| Run debug | `flutter run` |
| Analyze | `flutter analyze` |
| Unit and widget tests | `flutter test` |
| Goldens update (only when the design changes on purpose) | `flutter test --update-goldens test/golden` |
| Integration demo | `flutter test integration_test/demo_flow_test.dart` |
| Codegen | `dart run build_runner build --delete-conflicting-outputs` |
| Debug APK | `flutter build apk --debug` |
| Release APK | `flutter build apk --release` |
| Split per ABI (smaller) | `flutter build apk --release --split-per-abi` |

## Signing

- Create a keystore once with `keytool`. Store it outside the repo.
- `android/key.properties` (git-ignored) points to it.
- `android/app/build.gradle` reads `key.properties` for the release signing config.
- Never commit keystore or passwords. Use env vars in CI.

## Android configuration

- `applicationId`: `com.lemontrack.app`
- `minSdk`: 29
- `targetSdk`: latest stable
- `versionCode` and `versionName` from `pubspec.yaml`
- Portrait lock in `AndroidManifest.xml`: `android:screenOrientation="portrait"`
- App label: `LemonTrack`
- Adaptive icon: yellow background `#FFD60A`, black `resources/logo.png` mark rendered via `Image.asset`. Monochrome layer for themed icons on Android 13+.

Permissions: only those in `09` "Permissions summary".

## Icons and splash

- Generate with `flutter_launcher_icons` and `flutter_native_splash`.
- Splash: `#0B0B0C` background, centered lemon mark. No animation needed for the prototype.

## CI (GitHub Actions, optional but recommended)

`.github/workflows/ci.yml`:

1. Checkout.
2. Setup Flutter (stable).
3. `flutter pub get`
4. `dart run build_runner build --delete-conflicting-outputs`
5. `flutter analyze`
6. `flutter test --coverage`
7. `scripts/check_structure.sh`
8. `flutter build apk --debug`
9. Upload the debug APK as an artifact.

Emulator integration tests run on a nightly schedule or manually, not on every push.

## Release checklist (submission)

- [ ] `flutter analyze` clean
- [ ] `flutter test` green, domain coverage at 90% or higher
- [ ] Demo flow integration test green on API 34 emulator
- [ ] Manual device checklist from `11` complete
- [ ] Release APK built, signed, installed on a clean device
- [ ] App label, icon, and splash correct
- [ ] Permissions list matches `09`
- [ ] No API keys or secrets in the repo (`git grep -i "api_key\|secret"` review)
- [ ] `README.md` contains: one-paragraph pitch, screenshots (Today, Chat with diff card, Focus, Summary), setup steps, how to enable an AI provider, architecture diagram from `03`
- [ ] Privacy note: what is sent to AI providers, and the rule-based option
- [ ] Demo video (under 3 minutes) following the script in `11`
- [ ] Backup APK and source zip saved

## README outline

1. Name, tagline, screenshot strip
2. What it does (3 bullets)
3. How the chat controls the schedule (the tool list from `05`, short)
4. Architecture (layers from `03`)
5. Run it: `flutter pub get`, `flutter run`
6. Enable AI: Settings → AI, choose a provider, paste a key (or use rule-based)
7. Design: black and yellow Material 3, crypto accents (link to `02`)
8. Roadmap: calendar sync, voice input, recurrence, iOS

## Versioning

- `0.1.0+1` at WP-24 start. Bump build number for each internal APK. Bump the minor version for the competition submission.
