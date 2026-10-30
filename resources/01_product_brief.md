# 01 Product Brief

## Vision

LemonTrack lets people plan and track their day by talking to it. Time blocks are the unit of planning. The chatbot is the fastest way to change the plan, and the timeline is the fastest way to see it.

Tagline: **"Plan in blocks. Talk to your time."**

## Target users (prototype)

- **Primary:** students and knowledge workers who juggle many short tasks and want to plan by blocks.
- **Secondary:** freelancers who bill by time and want a clean log of what they did.

## Core jobs to be done

1. "Put my day in order without fiddling with a calendar UI."
2. "Move my afternoon because the meeting ran long, and fix everything that depends on it."
3. "Tell me what I actually did versus what I planned."
4. "Remind me before the next block starts."

## Key differentiators

- **Chat-controlled scheduling.** Natural language maps to typed tool calls, not free-text guesses.
- **Transparent AI.** Every AI change shows a diff card ("moved Deep Work 14:00 to 15:30") with Undo.
- **Block-first UI.** A vertical day timeline with draggable blocks and a crypto-style ticker of today's totals.

## Scope

### In scope (prototype)

- Day timeline view and week grid view.
- Time blocks: create, edit, move, resize, complete, delete. Categories with color.
- Conflict detection and auto-suggest a free slot.
- Focus timer per block with actual-vs-planned tracking.
- Daily summary: planned vs tracked, streak, category breakdown.
- AI chat with tool calling (see `05`, `08`).
- Local notifications for upcoming blocks.
- Demo seed data and onboarding that asks for an AI API key (optional).

### Out of scope (prototype)

- Cloud sync, accounts, multi-device.
- Calendar integrations (Google/Outlook). Mention as roadmap only.
- iOS and web builds. Android only.
- Voice input (roadmap; the chat accepts text only).
- Team or shared schedules.

## Success criteria (judging-oriented)

| Criterion | How we show it |
|---|---|
| Innovation | Live chat edits the timeline with visible diff cards |
| Technical depth | Typed tool layer, repository pattern, conflict engine, offline-first |
| Design | Black/yellow M3 theme, crypto accents, smooth motion |
| Completeness | Full demo script in `11` runs end to end without errors |
| Usefulness | Focus timer and daily summary show a real loop |

## Assumptions

- The competition allows a third-party LLM API. If not, the app ships with a **local rule-based fallback parser** (see `08`, section "Offline mode") so the demo still works.
- Device target: Android 10+ phone, portrait.
