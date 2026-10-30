# 09 Notifications and Background

Owner: Core Agent. Code in `lib/notifications/`.

## Goals

- Remind the user before each planned block.
- Keep reminders correct after edits, moves, deletes, and reboots.
- Keep the focus timer accurate when the app is backgrounded.

## Reminders

### Behavior

- A reminder fires `reminderLeadMinutes` before `startUtc` (default 10).
- Only blocks with status `planned` get reminders.
- Done, skipped, and deleted blocks have no reminder.
- Quiet hours: none in the prototype. Stretch: 22:00 to 07:00.

### Implementation

- `flutter_local_notifications` with a channel `lt_reminders` (importance high, sound on, vibration on).
- Use `zonedSchedule` with `timezone` so reminders fire at the correct local time across DST.
- Notification id = stable hash of `blockId` (32-bit). Re-scheduling replaces the old one.
- Payload: `/block/<id>`. Tapping opens the block editor via `go_router` deep link.
- Android 13+: request `POST_NOTIFICATIONS` at onboarding end, with a rationale screen. If denied, show a banner in Today: "Reminders are off."
- Android 12+: request `SCHEDULE_EXACT_ALARM` only if needed. Prefer inexact alarms (`AndroidScheduleMode.inexactAllowWhileIdle`). A 1 to 2 minute slip is acceptable for the prototype.

### Reconciliation

`ReminderScheduler` listens to the block stream and reconciles:

1. Compute the desired set: `{ blockId → fireAtUtc }` for planned future blocks.
2. Diff against scheduled notifications.
3. Cancel removed, reschedule changed, schedule new.

Run reconciliation:
- On app start.
- On every block change (debounced 300ms).
- On boot (`RECEIVE_BOOT_COMPLETED`, via `flutter_local_notifications` boot receiver or `workmanager` re-run).
- On timezone change (listen for `ACTION_TIMEZONE_CHANGED` via a platform channel, or re-check on resume).

### Copy

- Title: block title.
- Body: "Starts in 10 min · Deep work".
- Action buttons: "Start focus", "Snooze 10".

Snooze reschedules by 10 minutes without changing the block. Start focus opens `/focus/:id`.

## Focus timer

### Behavior

- Starts a `FocusSession` (kind `focus`) and sets block `inProgress`.
- Timer uses wall-clock deltas, not `Timer.periodic` counts, so it stays right after the app is backgrounded.
- Foreground service notification on Android while running: "Focus · 24:13 left · Thesis draft". Channel `lt_focus`, low importance, ongoing.
- Pause stops accruing. Resume continues.
- End session: writes `endedUtc` and `seconds`, adds to block `trackedSeconds`.
- Auto-end when the planned end time passes, with a prompt to extend or finish.

### Implementation

- Ongoing notification via `flutter_local_notifications` with `ongoing: true` and `autoCancel: false`. Update once per 30 seconds to save battery, or on pause and resume.
- Keep the screen awake with `wakelock_plus` on `/focus`.
- On app kill during a session: on next launch, find sessions with `endedUtc == null`, close them at the last heartbeat (store heartbeat every 30 seconds in the row), and show "Session recovered" in Today.

## Permissions summary

| Permission | When requested | Required |
|---|---|---|
| `POST_NOTIFICATIONS` | End of onboarding | Yes, for reminders |
| `SCHEDULE_EXACT_ALARM` | Not requested in prototype | No |
| `RECEIVE_BOOT_COMPLETED` | Declared in manifest | Yes, for reboot recovery |
| `FOREGROUND_SERVICE` | Declared | Only if the timer uses a foreground service |
| `INTERNET` | Declared | Only for AI providers |

Declare only what is used. Remove unused permissions before release.

## Testing hooks

- `ReminderScheduler` takes a `NotificationGateway` interface. Tests use a fake that records calls.
- `Clock` is injectable. All time logic uses it.
- Integration test (`integration_test/reminder_test.dart`) schedules a reminder 1 minute ahead on a real device and checks the notification appears. Manual on the demo device is acceptable.
