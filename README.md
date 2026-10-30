# LemonTrack

**Plan in blocks. Talk to your time.**

An AI-driven time-block and schedule tracker for Android (Flutter, Material Design 3). Chat-controlled scheduling meets a black-and-yellow crypto-accented timeline. Offline-first, local-only, demo-ready.

---

## What it does

- **Day timeline view** — vertical time-block grid for today, with a now-line, conflict warnings, and per-block category colors.
- **Week view** — compact 7-day grid of blocks.
- **Time blocks** — create, edit, move, complete, soft-delete, and restore blocks. Categories (deep work, meetings, study, health, admin, personal) with color coding.
- **AI chat assistant** — natural language commands ("create gym at 18:00 for 45 min", "move standup to 11:30", "summarize my day") run as typed tool calls. Every change shows a diff card with an **Undo** button.
- **Conflict detection** — overlapping blocks are flagged visually; free-slot suggestions included.
- **Focus timer** — track actual time against a block; keep screen awake while focusing.
- **Daily summary** — planned vs tracked time, streak, category breakdown.
- **Reminders** — local notifications for upcoming blocks.
- **Offline-first** — all data lives in local storage (`shared_preferences` / `flutter_secure_storage`). Works fully without an AI provider; the rule-based chat fallback keeps the demo running offline.
- **Demo seed data** — preloaded on first run so the app is demoable immediately.

---

## Screenshots / demo

Open the app → onboarding → Today. Tap `+ Add block` or open **Chat** and type:

> create gym at 18:00 for 45 min

Watch the block appear on the timeline with a diff card and an Undo option.

---

## Tech stack

| Layer | Choice |
|---|---|
| Framework | Flutter 3.x (stable), Dart 3 |
| UI | Material 3 |
| State | Riverpod 2 (`flutter_riverpod`) |
| Routing | `go_router` |
| Local storage | `shared_preferences`, `flutter_secure_storage` |
| HTTP | `dio` |
| Wake lock | `wakelock_plus` |
| Dates | `intl` |
| IDs | `uuid` |
| Tests | `flutter_test` |

---

## Getting started

### Prerequisites

- Flutter SDK (3.9+)
- Android device or emulator (API 29+)

### Run

```bash
cd lemontrack_
flutter pub get
flutter run
```

### Analyze & test

```bash
flutter analyze
flutter test
```

### Build APK

```bash
flutter build apk --release
```

Output: `build/app/outputs/flutter-apk/app-release.apk`

---

## Project structure

```
lib/
  app/            app.dart, router.dart, state (Riverpod providers)
  data/           repositories, settings, db
  domain/         models, scheduling engine, use cases, AI layer
  screens/        today, week, block_editor, chat, focus, summary, settings, onboarding, splash
  theme/          color tokens, text styles, theme
  widgets/        crypto kit (TickerStrip, DayTimeline), common kit
  util/           time helpers
test/             unit + widget tests
resources/        design spec pack (00-12)
```

---

## AI & API keys

AI providers (OpenAI, Gemini) are optional. API keys are stored per-user in `flutter_secure_storage` — never hardcoded. If no provider is configured, the app falls back to a local rule-based parser so chat commands still work offline.

---

## License

MIT. See [LICENSE](LICENSE).

---

## Roadmap

- Cloud sync / accounts
- Calendar integrations (Google / Outlook)
- iOS and web builds
- Voice input
- Team / shared schedules

---

Built as an Android competition prototype. Working, demoable, and polished on the happy path.
