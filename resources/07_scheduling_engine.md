# 07 Scheduling Engine

Owner: Core Agent. Pure Dart in `lib/domain/scheduling/`. No Flutter imports. Every rule here has a unit test (see `11`).

## Responsibilities

1. Detect conflicts between blocks.
2. Find free slots inside a window and workday.
3. Compute timeline layout (columns for overlaps).
4. Snap times to the grid.
5. Shift sets of blocks with rules.
6. Compute daily summaries.

## Public API

```dart
class SchedulingEngine {
  const SchedulingEngine({required this.settings});
  final Settings settings;

  List<Conflict> findConflicts(List<TimeBlock> blocks);

  DateTime? findFreeSlot({
    required List<TimeBlock> dayBlocks,
    required DateTime dayStartLocal,   // local midnight of target day
    required int durationMinutes,
    DateTime? earliestLocal,
    bool ignoreWorkday = false,
  });

  DateTime snap(DateTime t);           // to settings.snapMinutes, rounding to nearest

  List<TimeBlock> shiftFollowing({
    required List<TimeBlock> blocks,
    required DateTime fromUtc,
    required int deltaMinutes,
    Set<String> excludeCategoryIds = const {},
  });                                  // returns NEW blocks, does not mutate

  DaySummary summarize({
    required List<TimeBlock> blocks,
    required List<Category> categories,
  });

  List<BlockLayout> layoutForTimeline({
    required List<TimeBlock> blocks,
    required DateTime dayStartLocal,
  });
}
```

## Rules

### R1. Overlap definition

Two blocks A and B conflict when `A.start < B.end && B.start < A.end`. Touching edges (A ends at 10:00, B starts at 10:00) is **not** a conflict.

Conflicts ignore soft-deleted blocks and blocks with status `skipped`.

### R2. Conflict output

```dart
class Conflict {
  final String blockAId;
  final String blockBId;
  final int overlapMinutes;   // rounded up to whole minutes
}
```

Pairs are unique and ordered by `blockAId < blockBId` to keep results stable.

### R3. Snapping

- `snap(t)` rounds to the nearest multiple of `snapMinutes` on the local clock.
- Ties round up.
- Snap happens in local time, then converted to UTC. This keeps 9:00 at 9:00 across DST changes.
- Durations also snap: `duration = max(snapMinutes, round(duration / snapMinutes) * snapMinutes)`.

### R4. Free slot search

- Default window: `workdayStart` to `workdayEnd` on `dayStartLocal`. If `ignoreWorkday`, use 00:00 to 24:00.
- `earliestLocal` clamps the window start. If it is earlier than the window, ignore it.
- Iterate blocks sorted by start. A gap qualifies when `gapEnd - gapStart >= durationMinutes`.
- Return the **earliest** start that fits, snapped **up** to the grid.
- Return `null` when nothing fits. The tool layer maps this to `NO_FREE_SLOT`.
- Past times: when `dayStartLocal` is today, the window start is clamped to `now` rounded up to snap.

### R5. Shift rules

`shiftFollowing`:

- Select blocks with `start >= fromUtc` and not in `excludeCategoryIds`.
- Shift start and end by `deltaMinutes`. Preserve duration.
- Do not shift a block into negative time (before local midnight). Clamp and report it as a skipped change.
- Blocks with status `done` are **not** shifted. They are history.
- Return the new list. The use case persists changes in one transaction.

### R6. Summary

`summarize` returns:

```dart
class DaySummary {
  final int plannedMinutes;        // sum of durations, excluding skipped and deleted
  final int trackedMinutes;        // sum of trackedSeconds / 60, floor
  final Map<String, int> minutesByCategory;
  final int doneCount;
  final int totalCount;
  final double completionRate;     // doneCount / totalCount, 0 when empty
  final List<Conflict> conflicts;
}
```

Tracked time can exceed planned time. That is valid and shown as a positive delta.

### R7. Timeline layout

- Input: blocks for the day, sorted by start.
- Group blocks into clusters of transitive overlap.
- Within a cluster, assign columns greedily. Max 3 visible columns. Extra blocks get a `+N` overflow marker on the last column.
- Output `BlockLayout { blockId, top (dp), height (dp), column, totalColumns }`.
- Scale: `pxPerMinute = 1.0` by default (60dp per hour). Pass it in as a parameter.

### R8. Status transitions

```
planned ──start focus──▶ inProgress ──end focus / complete──▶ done
   │                         │
   └────────skip─────────────┴──▶ skipped
```

- `done` and `skipped` cannot return to `planned` from UI. Undo can restore the previous state through the action log.
- Starting focus on a block sets `inProgress` and creates a `FocusSession`.

## Edge cases (must be tested)

1. Zero-length or negative duration: rejected by validation before the engine.
2. Blocks crossing midnight: allowed. They belong to the day where they start. `summarize` counts their full duration on that start day. Timeline shows the portion within the day with a "continues" marker.
3. DST spring-forward day: a 09:00 block stays at 09:00 local. A block spanning the missing hour shows its real duration.
4. Two identical blocks: both appear, both conflict.
5. Empty day: `summarize` returns zeros. `findFreeSlot` returns the window start.
6. Block exactly at workday end: no room for any duration. Return `null`.
7. Snap collision: two blocks snap to the same time. Still a conflict, reported normally.

## Performance

- All functions are O(n log n) on sorted input. Sort once per call.
- A 500-block day must compute layout in under 16ms on a mid-range device. Benchmark test in `test/domain/scheduling_benchmark_test.dart`.
