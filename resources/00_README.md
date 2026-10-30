# LemonTrack: Spec Pack for Multi-Agent Build

**App:** LemonTrack, an AI-driven time-block and schedule tracker (Android, Flutter, Material Design 3)
**Core idea:** A chatbot that can read and control your schedule through tool calls. Time blocks, tracking, and an AI assistant share the same data.
**Theme:** Black and yellow, with crypto-style accents (ticker bars, glowing gradients, mono numerics, candle-style charts).
**Target:** Android competition prototype. Working, demoable, and polished on the happy path.

## How to use this pack

Each file owns one concern. Agents read only the files relevant to their work package, plus `00_README.md` and `01_product_brief.md`.

| File | Owner (agent role) | Purpose |
|---|---|---|
| `01_product_brief.md` | PM / Lead | Vision, users, scope, success criteria |
| `02_design_system.md` | UI Agent | Tokens, colors, type, components, crypto accents |
| `03_architecture.md` | Lead / Core Agent | Layers, state, folders, packages |
| `04_data_models.md` | Data Agent | Entities, DB schema, repositories |
| `05_ai_tools_contract.md` | AI Agent | Tool/function schemas the chatbot can call |
| `06_screens_navigation.md` | UI Agent | Screens, routes, user flows |
| `07_scheduling_engine.md` | Core Agent | Time-block rules, conflicts, tracking logic |
| `08_ai_assistant.md` | AI Agent | Chat loop, prompts, tool execution, safety |
| `09_notifications_background.md` | Core Agent | Reminders, timers, background work |
| `10_work_packages.md` | Lead | Task breakdown, dependencies, sequencing |
| `11_testing_acceptance.md` | QA Agent | Test plan, acceptance criteria, demo script |
| `12_build_and_release.md` | DevOps Agent | Setup, commands, APK build, submission checklist |

## Global rules for every agent

1. **Contracts are law.** Models in `04`, tool schemas in `05`, and tokens in `02` are the single source of truth. If you need a change, note it in `10_work_packages.md` under "Contract change requests" and keep going with the current contract.
2. **No secrets in code.** API keys live in user settings via `flutter_secure_storage`. Never hardcode keys.
3. **Offline first.** The app must work fully without AI. The chatbot is an extra layer over the same repositories.
4. **One source of truth for time.** All scheduling logic goes through the scheduling engine (`07`). UI and AI both call it. Neither reimplements it.
5. **Material 3 everywhere.** Use `Theme`, `ColorScheme`, and `TextTheme` tokens. No hardcoded colors or font sizes in widgets.
6. **Tests with features.** Each work package ships with its unit tests (see `11`).
7. **Keep the demo working.** `main` must always build and run. Feature branches merge only when `flutter analyze` and `flutter test` pass.

## Definition of done (prototype)

- Installable debug/release APK on Android 10+ (API 29+).
- Create, edit, complete, and delete time blocks on a day timeline and a week view.
- Conflict detection with a clear visual warning.
- Chatbot can create, move, query, and summarize blocks by calling tools. Each action is visible and undoable.
- Yellow-on-black theme with the crypto accent system applied consistently.
- Focus timer that tracks actual time against a block.
- Reminders fire for upcoming blocks.
- Demo seed data loads on first run.
