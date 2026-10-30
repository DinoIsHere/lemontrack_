# 04 Data Models

Owner: Data Agent. Consumers: Core, AI, and UI agents. Changes go through a contract change request in `10`.

## Entities (domain, pure Dart)

### `TimeBlock`

| Field | Type | Required | Notes |
|---|---|---|---|
| `id` | `String` (uuid v4) | yes | Primary key |
| `title` | `String` | yes | 1 to 120 chars |
| `notes` | `String?` | no | Up to 2000 chars |
| `startUtc` | `DateTime` (UTC) | yes | |
| `endUtc` | `DateTime` (UTC) | yes | Must be after `startUtc`. Min 5 min. |
| `timezone` | `String` | yes | IANA name at creation, e.g. `Asia/Kuala_Lumpur` |
| `categoryId` | `String` | yes | FK to `Category` |
| `status` | `BlockStatus` | yes | `planned`, `inProgress`, `done`, `skipped` |
| `trackedSeconds` | `int` | yes | Default 0. Updated by Focus timer. |
| `priority` | `int` | yes | 0 (low) to 2 (high). Default 1. |
| `source` | `BlockSource` | yes | `user`, `ai`, `seed` |
| `createdAtUtc` | `DateTime` | yes | |
| `updatedAtUtc` | `DateTime` | yes | |
| `deletedAtUtc` | `DateTime?` | no | Soft delete for Undo |
| `recurrenceRule` | `String?` | no | Stretch goal, RRULE subset |

Derived (not stored): `duration`, `isActive(now)`, `plannedSeconds`.

### `Category`

| Field | Type | Notes |
|---|---|---|
| `id` | `String` | Slug, e.g. `deep_work` |
| `name` | `String` | Display name |
| `colorHex` | `int` | ARGB, from `02` category palette |
| `iconName` | `String` | Material Symbols name |
| `sortOrder` | `int` | |

Seeded with six categories from `02`.

### `Settings` (singleton)

| Field | Type | Default |
|---|---|---|
| `workdayStart` | `TimeOfDay` | 09:00 |
| `workdayEnd` | `TimeOfDay` | 18:00 |
| `defaultBlockMinutes` | `int` | 30 |
| `snapMinutes` | `int` | 5 |
| `reminderLeadMinutes` | `int` | 10 |
| `aiProvider` | `AiProvider` | `ruleBased` |
| `aiModelName` | `String` | provider default |
| `hasSeenOnboarding` | `bool` | false |

API key is **not** here. It is in secure storage under key `lt.ai.apiKey.<provider>`.

### `ActionLogEntry` (for Undo and the diff cards)

| Field | Type | Notes |
|---|---|---|
| `id` | `String` | uuid |
| `atUtc` | `DateTime` | |
| `actor` | `ActionActor` | `user` or `ai` |
| `kind` | `String` | `create`, `update`, `move`, `delete`, `complete` |
| `blockId` | `String?` | |
| `before` | `String?` | JSON snapshot of the block before the change |
| `after` | `String?` | JSON snapshot after |
| `undone` | `bool` | Default false |
| `conversationId` | `String?` | Links AI actions to the chat |

Undo restores `before` through the same use cases. Keep the last 50 entries.

### `ChatMessage`

| Field | Type | Notes |
|---|---|---|
| `id` | `String` | |
| `conversationId` | `String` | Prototype has one conversation, but the field stays |
| `role` | `ChatRole` | `user`, `assistant`, `tool`, `system` |
| `content` | `String` | Text, may be empty for tool-call turns |
| `toolCallsJson` | `String?` | Serialized tool calls from the assistant |
| `toolCallId` | `String?` | For `tool` role messages |
| `createdAtUtc` | `DateTime` | |

## Drift tables (SQL-level)

```
time_blocks       id PK, title, notes, start_utc INT, end_utc INT, timezone TEXT,
                  category_id FK, status TEXT, tracked_seconds INT, priority INT,
                  source TEXT, created_at_utc INT, updated_at_utc INT,
                  deleted_at_utc INT NULL, recurrence_rule TEXT NULL
                  INDEX (start_utc), INDEX (deleted_at_utc)

categories        id PK, name, color_hex INT, icon_name TEXT, sort_order INT

action_log        id PK, at_utc INT, actor TEXT, kind TEXT, block_id TEXT NULL,
                  before TEXT NULL, after TEXT NULL, undone INT, conversation_id TEXT NULL
                  INDEX (at_utc)

chat_messages     id PK, conversation_id TEXT, role TEXT, content TEXT,
                  tool_calls_json TEXT NULL, tool_call_id TEXT NULL, created_at_utc INT
                  INDEX (conversation_id, created_at_utc)

focus_sessions    id PK, block_id FK, started_utc INT, ended_utc INT NULL,
                  seconds INT, kind TEXT   -- 'focus' | 'break'
```

Settings are stored in a key-value `app_settings` table (`key TEXT PK, value TEXT`) for simplicity.

Drift schema version: 1. Migrations start at 1 and must be written for every change.

## Repositories (interfaces in `domain/`, implementations in `data/`)

```dart
abstract interface class BlockRepository {
  Stream<List<TimeBlock>> watchRange(DateTime fromUtc, DateTime toUtc);
  Future<TimeBlock?> getById(String id);
  Future<void> upsert(TimeBlock block);
  Future<void> softDelete(String id, DateTime nowUtc);
  Future<void> restore(String id);
}

abstract interface class CategoryRepository {
  Stream<List<Category>> watchAll();
  Future<Category?> getById(String id);
}

abstract interface class ActionLogRepository {
  Future<void> append(ActionLogEntry entry);
  Future<List<ActionLogEntry>> recent({int limit = 50});
  Future<void> markUndone(String id);
}

abstract interface class FocusRepository {
  Future<void> startSession(FocusSession s);
  Future<void> endSession(String id, DateTime endedUtc);
  Stream<List<FocusSession>> watchForBlock(String blockId);
}

abstract interface class ChatRepository {
  Stream<List<ChatMessage>> watchConversation(String conversationId);
  Future<void> append(ChatMessage m);
  Future<void> clear(String conversationId);
}

abstract interface class SettingsRepository {
  Future<Settings> load();
  Future<void> save(Settings s);
}
```

## Seed data (demo)

Seed on first run only (`hasSeenOnboarding == false`). Seed set for "today" relative to device time:

- 08:30 to 09:00 `Morning review` (admin)
- 09:00 to 11:00 `Thesis draft` (deep work), tracked 1h 20m, status `done` for the 09:00 block only if the time has passed. Otherwise planned.
- 11:00 to 11:30 `Standup` (meetings)
- 13:00 to 14:30 `Reading: distributed systems` (study)
- 15:00 to 15:45 `Gym` (health)
- 16:00 to 17:00 `Email and invoices` (admin). Overlaps with a 16:30 `Client call`, so the demo shows a conflict.
- 17:00 to 17:30 `Call with Ana` (meetings)

Seed must set `source = seed`.

## Validation rules (enforced in domain, not UI)

1. `endUtc > startUtc`, and duration ≥ 5 min and ≤ 12 hours.
2. Start and end snap to `snapMinutes` when set by the user or AI. Raw times from the AI are snapped and the diff card shows the snapped result.
3. Title is trimmed and non-empty.
4. `categoryId` must exist.
5. Conflicts are allowed but reported. The user or AI decides.
6. Soft-deleted blocks are excluded from all queries except `restore`.
