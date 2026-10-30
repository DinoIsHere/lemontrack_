# 06 Screens and Navigation

Owner: UI Agent. Every screen uses `02` tokens and `widgets/crypto` components.

## Navigation shell

Bottom `NavigationBar` (M3) with four destinations:

| Index | Label | Icon (Material Symbols) | Route |
|---|---|---|---|
| 0 | Today | `today` | `/today` |
| 1 | Week | `calendar_view_week` | `/week` |
| 2 | Chat | `auto_awesome` | `/chat` |
| 3 | Summary | `monitoring` | `/summary` |

Full-screen routes (no bottom nav):

| Route | Screen | Entry point |
|---|---|---|
| `/onboarding` | Onboarding | First launch |
| `/block/new?start=...` | Block editor (new) | FAB, long-press on timeline |
| `/block/:id` | Block editor (edit) | Tap a block |
| `/focus/:id` | Focus timer | "Start focus" on a block |
| `/settings` | Settings | Gear icon in Today app bar |
| `/settings/ai` | AI provider settings | Settings list |

Routing uses `go_router`. A `ShellRoute` hosts the bottom nav. Deep links from notifications open `/block/:id`.

## Screen specs

### S1. Onboarding (`/onboarding`)

Three pages with `PageView` and a dot indicator (`LiveDot` as the active dot):

1. **"Plan in blocks."** Shows the Today timeline animation.
2. **"Talk to your time."** Shows a chat bubble that creates a block.
3. **"Connect your AI (optional)."** Provider picker (Rule-based, OpenAI, Gemini), API key field with "Skip for now" button.

The app logo is rendered as `Image.asset('resources/logo.png')` — plus the tagline "Plan in blocks. Talk to your time." No text-only logos.

Finish sets `hasSeenOnboarding = true` and seeds demo data. "Skip" uses rule-based mode.

### S2. Today (`/today`)

Purpose: the daily command center.

Layout (top to bottom):

1. **App bar:** date (headlineMedium) with left/right chevrons to change day. Trailing: settings icon.
2. **`TickerStrip`:** Planned, Tracked, Streak, Focus %.
3. **Hero `StatCard`:** "Next block" with title, start time (`numericMedium`), and a `ProgressRing` countdown if within 60 minutes.
4. **Timeline:** vertical day timeline (see "Timeline widget" below) fills remaining height.
5. **FAB:** extended gradient "Add block".

Interactions:
- Tap a block: opens `/block/:id`.
- Long-press empty space: opens `/block/new` with that start time (snapped).
- Drag a block vertically: moves it. Snap to `snapMinutes`. Conflicts highlight in `coral` while dragging. On drop, the change uses `move_block` through the same use case.
- Swipe a block right: complete. Swipe left: delete with Undo snackbar.
- Pull to refresh: re-reads the day. No network.

Empty state: `GridBackdrop` with the text "Nothing planned. Ask the chat or tap + to add a block." and a `FilledButton` that opens Chat.

### S3. Week (`/week`)

- 7 columns (or a horizontally scrolling 3-day view on narrow screens) with compact blocks.
- Each block is a colored bar with title (ellipsized) and time in mono.
- Tap a day header to jump to Today for that date.
- Conflicts show a small `coral` dot.
- Week total at the top as a `StatCard`.

### S4. Block editor (`/block/new`, `/block/:id`)

Form fields in order:

1. Title (`TextField`, filled, required)
2. Category (`GlowChip` row, single select)
3. Date and start time (tap to open pickers)
4. Duration (stepper with presets 15, 30, 45, 60, 90, custom)
5. Priority (segmented button: low, normal, high)
6. Notes (multi-line, optional)

Live preview at the top: a mini timeline showing the block plus the blocks it overlaps. Conflicts show a warning row with an icon and text: "Overlaps Client call by 30 min."

Bottom bar: `OutlinedButton` "Delete" (only when editing) and `FilledButton` "Save". Save runs validation from `04`. Conflicts do not block save, but the button shows "Save anyway" when there is a conflict.

### S5. Focus (`/focus/:id`)

- Full-screen dark with a large `ProgressRing` (dashed outer ring, lemon progress arc).
- Center: remaining time in `numericLarge`.
- Under the ring: block title, category, and "Tracked so far".
- Controls: Pause/Resume (`FilledButton`), End session (`OutlinedButton`).
- Break suggestion after 50 minutes: a `GlowChip` "Take a 5 min break?" (non-blocking).
- On end: writes a `FocusSession`, updates `trackedSeconds`, and offers "Mark done" with a `FilledButton`.
- Keep the screen awake while running (`wakelock_plus`).

### S6. Chat (`/chat`)

Layout:

- App bar: "LemonTrack AI" with a `LiveDot` when waiting on a response. Trailing: clear chat icon, and an AI status `GlowChip` ("Rule-based" or "Gemini" etc.).
- Message list. User bubbles right-aligned in `primaryContainer`. Assistant bubbles left in `graphite`.
- **Tool result cards** inline after the assistant message that triggered them. Card shows:
  - Action label ("Moved", "Created", "Shifted 3 blocks")
  - Before → after rows in mono
  - Conflict chips if any
  - `TextButton` "Undo" (uses `action_log_id`)
- Quick prompt chips above the input when the chat is empty: "What's left today?", "Move my afternoon back 30 min", "Find 45 min tomorrow", "Summarize my day".
- Input: filled `TextField`, send `IconButton` in lemon.

Streaming: assistant text streams token by token. Tool calls appear as a "Working…" row with a `LiveDot`, replaced by the result card when done.

### S7. Summary (`/summary`)

- Date picker at top (same chevrons as Today).
- Hero: `StatCard` "Tracked today" with gradient border and a delta vs planned (up or down arrow).
- `CandleBars` for the last 14 days (planned vs tracked per day).
- Category breakdown: horizontal bars in category colors with mono minutes.
- Done count and completion rate.
- Streak card with the flame color `ember`.

### S8. Settings (`/settings`)

Sections:

- **Schedule:** workday start and end, default block length, snap minutes, reminder lead time.
- **AI:** provider, model name, API key (masked, stored securely), "Test connection" button, "Use rule-based mode" switch.
- **Data:** reseed demo data, clear all, export JSON (stretch).
- **About:** version, licenses.

Settings changes take effect immediately. No save button.

## Timeline widget (`widgets/crypto/day_timeline.dart`)

- Vertical scroll. Hour rows every 60dp (configurable), with time labels in `numericMedium`, `ash` color.
- Background: `GridBackdrop`.
- Now-line: 2dp `lemon` line with a `LiveDot` at the left gutter.
- Blocks are positioned by minute offset. Height = duration. Overlapping blocks share columns (max 3 columns, then "+N" overflow chip).
- Block visual: `graphite` fill, 3px category color bar on the left, title (`titleMedium`), time range (`numericMedium` small), and a status glyph (done check, in-progress dot, skipped slash).
- Done blocks: 60% opacity with a `up` check.
- In-progress block: 1px `lemon` border plus `glow`.

Performance: use `SliverList` with fixed-extent children where possible. Block layout is computed in a pure function in `domain/scheduling/layout.dart` (testable).

## Motion map

| Moment | Motion |
|---|---|
| Screen push | Shared axis (M3) |
| Block snap | Haptic click and 150ms height settle |
| Undo appears | Snackbar slide-in |
| Tool card appears | Fade and slide up 8dp, 200ms |
| FAB extend | M3 extended FAB animation |

## Accessibility notes

- Every block has a `Semantics` label: "Thesis draft, 09:00 to 11:00, Deep work, done".
- Drag has a non-drag alternative: long-press → Edit.
- Chat messages announce as live regions.
