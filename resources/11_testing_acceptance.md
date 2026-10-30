# 11 Testing and Acceptance

Owner: QA Agent. Every package in `10` ships with the tests listed for it here.

## Test layers

| Layer | Tool | Location | Target |
|---|---|---|---|
| Unit (domain) | `flutter_test` (pure Dart) | `test/domain/` | 90% line coverage on `domain/scheduling` and `domain/ai` |
| Unit (data) | `flutter_test` + Drift in-memory | `test/data/` | All DAOs and repositories |
| Widget | `flutter_test` | `test/widgets/` | Crypto kit, timeline, block editor, chat card |
| Golden | `flutter_test` goldens | `test/golden/` | TickerStrip, StatCard, ProgressRing, CandleBars, Today (light and dark not needed; dark only) |
| Integration | `integration_test` | `integration_test/` | Demo flow end to end on an emulator |
| AI eval | Custom runner | `test/ai/eval_cases.json` | Tool-call accuracy (see `08`) |
| Manual | Checklist | Section below | Device-only items (notifications, wakelock, haptics) |

## Required unit tests (minimum)

### Scheduling engine (`07`)

- Overlap: touching edges are not conflicts. Partial overlap is a conflict with correct minutes.
- Snap: 09:02 snaps to 09:00. 09:03 snaps to 09:05. Ties round up.
- Free slot: finds first gap. Respects workday. Honors `earliest`. Returns null when full. Clamps past times to now on today.
- Shift: moves following blocks. Excludes category. Skips done blocks. Refuses to go before midnight.
- Summary: totals, category map, completion rate, empty day.
- Layout: two overlapping blocks get two columns. Three-way overlap. Overflow marker past 3.
- Edge cases in `07` section "Edge cases". Each is one test.

### Use cases (`04`, `08`)

- Create with conflict still saves and reports conflict.
- Update rejects `endUtc <= startUtc`.
- Soft delete hides the block. Restore brings it back.
- Action log written for every write, with correct before and after.
- Undo restores the previous state for create, update, move, delete, complete.

### Tool executor (`05`, `08`)

- Unknown tool name returns `VALIDATION_FAILED`.
- Extra property in args returns `VALIDATION_FAILED`.
- Unknown block id returns `BLOCK_NOT_FOUND`.
- Max 5 tool calls per turn enforced.
- Batch guard: `shift_following` affecting more than 3 blocks returns a confirmation-required result when not confirmed.
- Envelope shape matches `05` for read and write tools.

### Rule-based client (`08`)

- Each intent row in the table maps to the expected tool call.
- Unmatched input returns the supported-phrases reply, with no tool call.

## Widget tests (minimum)

- `TickerStrip` renders four items with correct delta colors (`up` and `down`).
- `DayTimeline` renders blocks at correct offsets for a fixture day.
- `DayTimeline` marks overlapping blocks with the correct column count.
- Block editor shows the conflict row when overlapping and enables "Save anyway".
- Chat diff card shows before and after rows and an Undo button that calls the undo use case.
- Swipe to complete on a block calls `complete_block` through the use case (use a fake repo).

## Golden tests

Generate once, commit, and fail on drift. Fixtures use the seed day from `04`.

- `ticker_strip.png`
- `stat_card_hero.png`
- `progress_ring_40pct.png`
- `candle_bars_14d.png`
- `today_seed_day.png`

Golden tests must set a fixed font loader so text rendering is stable.

## Integration: demo flow

File: `integration_test/demo_flow_test.dart`. Runs on an Android emulator (API 34) in CI or locally.

1. Fresh install. Onboarding shows three pages. Tap "Skip for now" on the AI step. Land on Today.
2. Today shows 7 seeded blocks, the conflict badge on "Email and invoices", and the ticker strip.
3. Long-press empty space at 12:00. Editor opens with 12:00 prefilled. Enter title "Lunch walk", category Health, 30 min. Save. Block appears on the timeline.
4. Drag "Reading: distributed systems" 30 minutes later. Conflict highlight appears only if it overlaps. Drop. Change persists after restart.
5. Open Chat. Tap quick prompt "Summarize my day". Assistant replies with totals. No diff card (read-only).
6. Send "Move my afternoon back 30 min". Diff card shows moved blocks. Tap Undo. Blocks return to prior times.
7. Send "Find 45 minutes tomorrow morning for gym". Diff card shows the created block on the next day.
8. Open a block, tap "Start focus". Timer runs for 5 seconds (test shortcut). End session. Tracked time updates on Today.
9. Open Summary. Tracked total matches the focus session. CandleBars shows today.
10. Kill and relaunch. Data persists. Focus session shows as recovered if it was running.

## Manual device checklist

Run on a physical Android 10+ device before demo day.

- [ ] Reminder fires 10 minutes before a block, with the correct title.
- [ ] Tapping the reminder opens the correct block.
- [ ] "Start focus" action in the notification opens the focus screen.
- [ ] Ongoing focus notification updates and disappears on end.
- [ ] Screen stays awake on the focus screen.
- [ ] Haptic click on block snap.
- [ ] Rotating the device does not crash (portrait locked, so only check it does not rotate).
- [ ] Font scale 1.3x keeps the timeline readable and tappable.
- [ ] Dark theme is the only theme; system light mode does not change the app.
- [ ] Airplane mode: app works, AI falls back to rule-based with a visible chip.
- [ ] Clean install to first useful screen under 60 seconds.

## Acceptance criteria (must pass for prototype sign-off)

| ID | Criterion | How to verify |
|---|---|---|
| AC-01 | App launches to Today with seed data on first run | Integration step 1 and 2 |
| AC-02 | Create, edit, move, complete, delete a block by hand | Integration step 3 and 4, plus widget tests |
| AC-03 | Conflicts are visible and do not block save | Editor widget test and step 2 |
| AC-04 | Chat moves blocks through tools, shows diff, Undo restores | Integration step 6 |
| AC-05 | Chat finds a free slot and creates a block | Integration step 7 |
| AC-06 | Rule-based mode works with no network and no key | Manual airplane mode check |
| AC-07 | Focus records tracked time and survives app kill | Integration step 8 and 10 |
| AC-08 | Summary totals match the data | Integration step 9 and unit tests |
| AC-09 | Reminders fire on device | Manual checklist |
| AC-10 | Theme is black and yellow with crypto accents on every main screen | Golden tests and visual review |
| AC-11 | `flutter analyze` has no errors, and no raw color literals outside `theme/` and `widgets/crypto/` | CI grep and analyzer |
| AC-12 | `flutter test` passes; coverage on `domain/` at 90% or higher | CI |

## Demo script (judges, about 3 minutes)

1. **Hook (20s):** "Your day is a list of blocks. LemonTrack lets you talk to them." Show Today with the ticker and the conflict badge.
2. **Chat control (60s):** "My meeting ran long. Move everything after 2pm back 30 minutes." Show diff card, point at the conflict, tap Undo, then redo it.
3. **Free slot (30s):** "Find 45 minutes tomorrow morning for the gym." Show the created block on the next day's timeline.
4. **Focus (40s):** Start focus on a block, show the ring and the ongoing notification, end it, show tracked time update.
5. **Summary (20s):** Show planned vs tracked and CandleBars. Mention the crypto-style data view.
6. **Close (10s):** "Offline first. Rule-based AI works with no key. Bring your own model when you want more."

## Bug severity

| Level | Definition | Action |
|---|---|---|
| S1 | Crash, data loss, or wrong times saved | Blocks merge. Fix before any other work. |
| S2 | Feature broken for the demo script | Fix before demo |
| S3 | Visual glitch, minor copy issue | Fix if time allows |
| S4 | Nice-to-have | Backlog |
