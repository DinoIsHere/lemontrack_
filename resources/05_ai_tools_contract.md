# 05 AI Tools Contract

Owner: AI Agent. This is the public interface the chatbot uses to control LemonTrack. Every tool maps to a domain use case. The model never touches the database.

## Principles

1. **Typed and validated.** Every argument is validated against the schema before execution. Invalid calls return a structured error to the model, not a crash.
2. **Same path as the UI.** Tools call the same use cases the screens call.
3. **Reversible.** Every mutating tool writes an `ActionLogEntry` so Undo works.
4. **Time-zone aware.** All times passed to tools are ISO 8601 local times with offset. The executor converts them to UTC.
5. **Small surface.** 9 tools total for the prototype. Each does one job.

## Tool list

| # | Tool name | Kind | Purpose |
|---|---|---|---|
| 1 | `get_day` | read | List blocks for a date |
| 2 | `get_range` | read | List blocks between two datetimes |
| 3 | `find_free_slot` | read | Find the earliest free window of N minutes |
| 4 | `create_block` | write | Create a block |
| 5 | `update_block` | write | Change title, times, category, notes, priority |
| 6 | `move_block` | write | Shift a block to a new start, keep duration |
| 7 | `shift_following` | write | Shift all blocks after a time by N minutes |
| 8 | `complete_block` | write | Mark done, optional tracked seconds |
| 9 | `delete_block` | write | Soft delete |
| 10 | `summarize_day` | read | Totals: planned, tracked, by category, conflicts |

That is 10 tools. Keep the list at 10 unless the spec changes.

## Shared types

```jsonc
// DateTimeLocal: "2026-10-30T14:00:00+08:00"
// Duration: integer minutes, 5 to 720
// CategoryId: one of "deep_work" | "meetings" | "study" | "health" | "admin" | "personal"
// BlockId: uuid string
```

## Tool schemas (JSON Schema, passed to the LLM provider)

### 1. `get_day`
```json
{
  "name": "get_day",
  "description": "List all time blocks on a given local date, sorted by start time. Use before editing to learn existing block ids.",
  "parameters": {
    "type": "object",
    "properties": {
      "date": { "type": "string", "format": "date", "description": "Local date YYYY-MM-DD" }
    },
    "required": ["date"]
  }
}
```

### 2. `get_range`
```json
{
  "name": "get_range",
  "description": "List time blocks that overlap a local datetime range.",
  "parameters": {
    "type": "object",
    "properties": {
      "start": { "type": "string", "format": "date-time" },
      "end": { "type": "string", "format": "date-time" }
    },
    "required": ["start", "end"]
  }
}
```

### 3. `find_free_slot`
```json
{
  "name": "find_free_slot",
  "description": "Find the earliest free window of at least the given length inside the search range. Respects workday hours unless ignore_workday is true.",
  "parameters": {
    "type": "object",
    "properties": {
      "date": { "type": "string", "format": "date" },
      "duration_minutes": { "type": "integer", "minimum": 5, "maximum": 720 },
      "earliest": { "type": "string", "format": "time", "description": "HH:MM local, optional" },
      "ignore_workday": { "type": "boolean", "default": false }
    },
    "required": ["date", "duration_minutes"]
  }
}
```

### 4. `create_block`
```json
{
  "name": "create_block",
  "description": "Create a new time block. If the time conflicts with another block, it is still created and the result lists the conflicts. Prefer find_free_slot first when the user did not give a time.",
  "parameters": {
    "type": "object",
    "properties": {
      "title": { "type": "string", "minLength": 1, "maxLength": 120 },
      "start": { "type": "string", "format": "date-time" },
      "duration_minutes": { "type": "integer", "minimum": 5, "maximum": 720 },
      "category": { "type": "string", "enum": ["deep_work", "meetings", "study", "health", "admin", "personal"] },
      "priority": { "type": "integer", "minimum": 0, "maximum": 2 },
      "notes": { "type": "string", "maxLength": 2000 }
    },
    "required": ["title", "start", "duration_minutes", "category"]
  }
}
```

### 5. `update_block`
```json
{
  "name": "update_block",
  "description": "Change fields of an existing block. Only send fields that change.",
  "parameters": {
    "type": "object",
    "properties": {
      "block_id": { "type": "string" },
      "title": { "type": "string", "minLength": 1, "maxLength": 120 },
      "start": { "type": "string", "format": "date-time" },
      "duration_minutes": { "type": "integer", "minimum": 5, "maximum": 720 },
      "category": { "type": "string", "enum": ["deep_work", "meetings", "study", "health", "admin", "personal"] },
      "priority": { "type": "integer", "minimum": 0, "maximum": 2 },
      "notes": { "type": "string", "maxLength": 2000 }
    },
    "required": ["block_id"]
  }
}
```

### 6. `move_block`
```json
{
  "name": "move_block",
  "description": "Move a block to a new start time, keeping its duration.",
  "parameters": {
    "type": "object",
    "properties": {
      "block_id": { "type": "string" },
      "new_start": { "type": "string", "format": "date-time" }
    },
    "required": ["block_id", "new_start"]
  }
}
```

### 7. `shift_following`
```json
{
  "name": "shift_following",
  "description": "Shift every block that starts at or after a given time by a number of minutes (negative to move earlier). Use when a meeting runs long or the day changes. Returns the list of moved blocks.",
  "parameters": {
    "type": "object",
    "properties": {
      "from": { "type": "string", "format": "date-time", "description": "Blocks starting at or after this time are moved" },
      "delta_minutes": { "type": "integer", "minimum": -720, "maximum": 720 },
      "exclude_category": { "type": "string", "enum": ["deep_work", "meetings", "study", "health", "admin", "personal"] }
    },
    "required": ["from", "delta_minutes"]
  }
}
```

### 8. `complete_block`
```json
{
  "name": "complete_block",
  "description": "Mark a block as done. Optionally record the tracked time in minutes.",
  "parameters": {
    "type": "object",
    "properties": {
      "block_id": { "type": "string" },
      "tracked_minutes": { "type": "integer", "minimum": 0, "maximum": 720 }
    },
    "required": ["block_id"]
  }
}
```

### 9. `delete_block`
```json
{
  "name": "delete_block",
  "description": "Soft-delete a block. The user can undo it. Confirm with the user before deleting more than one block.",
  "parameters": {
    "type": "object",
    "properties": {
      "block_id": { "type": "string" }
    },
    "required": ["block_id"]
  }
}
```

### 10. `summarize_day`
```json
{
  "name": "summarize_day",
  "description": "Return totals for a local date: planned minutes, tracked minutes, minutes per category, number of done blocks, and conflicting pairs.",
  "parameters": {
    "type": "object",
    "properties": {
      "date": { "type": "string", "format": "date" }
    },
    "required": ["date"]
  }
}
```

## Result envelope

Every tool returns the same envelope. The model reads it, and the UI renders the diff card from it.

```json
{
  "ok": true,
  "tool": "move_block",
  "data": { "...tool specific..." },
  "changes": [
    {
      "block_id": "b_123",
      "title": "Thesis draft",
      "kind": "move",
      "before": { "start": "2026-10-30T09:00:00+08:00", "end": "2026-10-30T11:00:00+08:00" },
      "after":  { "start": "2026-10-30T10:00:00+08:00", "end": "2026-10-30T12:00:00+08:00" }
    }
  ],
  "conflicts": [
    { "block_a": "b_123", "block_b": "b_200", "overlap_minutes": 30 }
  ],
  "action_log_id": "al_889"
}
```

Error envelope:

```json
{
  "ok": false,
  "tool": "move_block",
  "error": { "code": "BLOCK_NOT_FOUND", "message": "No block with id b_999 exists." }
}
```

Error codes: `VALIDATION_FAILED`, `BLOCK_NOT_FOUND`, `CATEGORY_UNKNOWN`, `OUT_OF_RANGE`, `NO_FREE_SLOT`, `INTERNAL`.

Read tools return `changes: []`.

## Execution rules (tool executor)

1. Parse the model's tool call. Unknown tool name → `VALIDATION_FAILED`.
2. Validate args against the schema. Coerce only ISO strings and integers. No other coercion.
3. Resolve `block_id` values. Fail fast on unknown ids.
4. Call the use case inside one transaction.
5. Write the `ActionLogEntry` in the same transaction.
6. Return the envelope. Never return raw DB rows.
7. Max 5 tool calls per user turn. Beyond that, stop and tell the model to ask the user.
8. Destructive batch guard: `delete_block` or `shift_following` affecting more than 3 blocks in one turn needs a user confirmation chip before executing.

## Example turns

**User:** "My meeting ran long, push everything after 14:00 back 30 minutes except deep work."

Expected calls:
1. `shift_following({ from: "2026-10-30T14:00:00+08:00", delta_minutes: 30, exclude_category: "deep_work" })`

Assistant reply: "Moved 3 blocks by 30 min, skipped Deep work. Reading now ends at 15:00. [Undo]"

**User:** "Find me 45 minutes tomorrow morning for gym."

1. `find_free_slot({ date: "2026-10-31", duration_minutes: 45, earliest: "07:00", ignore_workday: true })`
2. `create_block({ title: "Gym", start: "<returned start>", duration_minutes: 45, category: "health" })`

**User:** "How did today go?"

1. `summarize_day({ date: "2026-10-30" })`

Assistant reply uses the numbers. No extra tool calls needed.
