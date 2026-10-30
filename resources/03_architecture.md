# 03 Architecture

## Stack

| Concern | Choice | Why |
|---|---|---|
| Framework | Flutter 3.x (stable), Dart 3 | Requested |
| UI | Material 3 (`useMaterial3: true`) | Requested |
| State | Riverpod 2 (`flutter_riverpod`, `riverpod_annotation`) | Testable, compile-safe |
| Routing | `go_router` | Declarative, deep links for notifications |
| Local DB | Drift (SQLite) | Typed queries, reactive streams |
| Secrets | `flutter_secure_storage` | Stores the user's AI API key |
| HTTP | `dio` | Streaming responses for chat |
| Notifications | `flutter_local_notifications` + `timezone` | Block reminders |
| Background | `workmanager` (optional) | Re-schedule reminders after reboot |
| Dates | `intl`, `timezone` | Locale and DST handling |
| IDs | `uuid` | Stable IDs for blocks and tool calls |
| Fonts | `google_fonts` | Inter and JetBrains Mono |
| Charts | Custom painters (`CustomPainter`) | Crypto-style visuals without heavy deps |
| Tests | `flutter_test`, `mocktail`, `drift` in-memory | Unit and widget tests |

Min SDK: Android API 29. Target SDK: latest stable.

## Layers

```
UI (screens, widgets)          lib/screens, lib/widgets
   │  reads state, sends intents
Presentation (Riverpod providers, view models)   lib/app/state
   │
Domain (use cases, scheduling engine, AI tool executor)   lib/domain
   │  pure Dart, no Flutter imports
Data (repositories, Drift DB, HTTP clients)   lib/data
```

Rules:

- `domain/` imports nothing from Flutter. It can be unit tested with plain `dart test`.
- `screens/` never talks to `data/` directly. It goes through providers.
- The AI layer calls **domain use cases**, never the DB. This keeps AI actions identical to user actions.

## Folder structure

```
lib/
  main.dart
  app/
    app.dart                 MaterialApp.router, theme
    router.dart              go_router config (see 06)
    state/                   Riverpod providers (one file per feature)
  theme/
    lt_colors.dart           color tokens (02)
    lt_text.dart             text styles (02)
    lt_theme.dart            ThemeData builder (02)
  widgets/
    crypto/                  TickerStrip, CandleBars, ProgressRing, ... (02)
    common/                  shared buttons, sheets, empty states
  screens/
    today/
    week/
    block_editor/
    focus/
    summary/
    chat/
    settings/
    onboarding/
  domain/
    models/                  pure Dart entities (04)
    scheduling/              engine (07)
    usecases/                create_block, move_block, ... (07, 08)
    ai/
      tool_registry.dart     tool name -> handler (05)
      tool_executor.dart     validates args, runs use case, builds diff (08)
      prompt_builder.dart    system prompt + context (08)
      llm_client.dart        interface (08)
      providers/             openai_client.dart, gemini_client.dart, rule_based_client.dart
  data/
    db/
      app_database.dart      Drift DB (04)
      tables.dart
      daos/
    repositories/            BlockRepository, CategoryRepository, ... (04)
    settings/                secure storage wrappers
  notifications/
    reminder_scheduler.dart  (09)
  util/
    time.dart                timezone helpers, rounding, durations
    ids.dart
test/
  domain/
  data/
  widgets/
  golden/
integration_test/
  demo_flow_test.dart        (11)
```

## Dependency injection

Riverpod providers are the DI container. Each repository and use case is a provider.

```dart
final blockRepositoryProvider = Provider<BlockRepository>((ref) {
  return DriftBlockRepository(ref.watch(appDatabaseProvider));
});
```

Tests override providers with fakes.

## Navigation

See `06_screens_navigation.md`. Summary: bottom nav with Today, Week, Chat, Summary. Block editor and Focus are full-screen routes.

## Error handling

- Domain functions return `Result<T>` (sealed class: `Ok`, `Err`). No thrown exceptions across layer boundaries except for programmer errors.
- Conflicts are not errors. They return a `ScheduleResult` with `conflicts` filled in.
- UI shows errors as snackbars with a retry where it makes sense.

## Time model

- All stored times are UTC epoch milliseconds plus the IANA timezone string at creation.
- Display uses the device timezone (`flutter_timezone`). Day boundaries use local midnight.
- Block times are stored as `startUtc` and `endUtc`. Recurrence (stretch) is stored as RRULE-lite (see `04`).

## Performance budget

- Cold start to Today: under 1.5s on a mid-range device.
- Timeline scroll: 60fps with 50 blocks in a day.
- Chat first token: as fast as the provider allows. Show a `LiveDot` while waiting.

## Configuration

`lib/app/config.dart` holds non-secret constants: default categories, default work hours (09:00 to 18:00), default block length (30 min), and the rounding step (5 min).
