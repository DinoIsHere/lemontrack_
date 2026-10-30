# 10 Work Packages

Owner: Lead. This file tracks who builds what, in what order, and what they depend on. Agents claim a package by writing their agent name in the **Owner** column and setting status to `in progress`.

## Phases

| Phase | Goal | Exit criteria |
|---|---|---|
| P0 Foundation | Project compiles, theme loads, DB opens | `flutter run` shows themed empty shell |
| P1 Core | Blocks, engine, timeline, editor | Create, edit, move, delete blocks by hand |
| P2 AI | Tool layer, chat, rule-based client | Chat creates and moves a block with diff card |
| P3 Focus and Summary | Timer, summary, charts | Focus session records tracked time; summary shows it |
| P4 Polish | Onboarding, notifications, motion, crypto accents | Demo script in `11` passes |
| P5 Release | APK, store-ready assets, README | Install and run on a clean device |

## Work packages

Dependencies use package IDs. A package starts only when its dependencies are `done`.

| ID | Package | Spec files | Depends on | Owner | Status |
|---|---|---|---|---|---|
| WP-01 | Project scaffold, lints, folder structure, dependencies | 03, 12 | none | | pending |
| WP-02 | Theme: color tokens, text styles, `ThemeData` | 02 | WP-01 | | pending |
| WP-03 | Crypto widget kit: TickerStrip, StatCard, ProgressRing, GridBackdrop, GlowChip, LiveDot | 02 | WP-02 | | pending |
| WP-04 | Drift DB, tables, DAOs, migrations v1 | 04 | WP-01 | | pending |
| WP-05 | Domain models and repository interfaces | 04 | WP-01 | | pending |
| WP-06 | Repository implementations and seed data | 04 | WP-04, WP-05 | | pending |
| WP-07 | Scheduling engine: conflicts, snap, free slot, shift, summary, layout | 07 | WP-05 | | pending |
| WP-08 | Use cases: create, update, move, shift, complete, delete, restore, undo | 04, 07 | WP-06, WP-07 | | pending |
| WP-09 | Navigation shell, go_router, bottom nav | 06 | WP-02 | | pending |
| WP-10 | Today screen and day timeline widget | 06, 07 | WP-03, WP-08, WP-09 | | pending |
| WP-11 | Block editor screen | 06 | WP-08, WP-10 | | pending |
| WP-12 | Week screen | 06 | WP-08, WP-09 | | pending |
| WP-13 | Tool contract: schemas, registry, envelopes | 05 | WP-08 | | pending |
| WP-14 | Tool executor and action log, undo | 05, 08 | WP-13 | | pending |
| WP-15 | Rule-based LLM client | 08 | WP-14 | | pending |
| WP-16 | Chat screen, diff cards, quick prompts | 06, 08 | WP-14, WP-15, WP-03 | | pending |
| WP-17 | OpenAI and Gemini clients, secure key storage, settings AI page | 08, 06 | WP-16 | | pending |
| WP-18 | Focus screen, focus sessions, recovery | 06, 09 | WP-08, WP-03 | | pending |
| WP-19 | Summary screen, CandleBars, category bars | 06, 07 | WP-03, WP-08 | | pending |
| WP-20 | Notifications: reminders, reconciliation, permissions | 09 | WP-08 | | pending |
| WP-21 | Onboarding and settings screen | 06 | WP-06, WP-20, WP-17 | | pending |
| WP-22 | Motion pass, haptics, accessibility labels | 02, 06 | WP-10 to WP-19 | | pending |
| WP-23 | Test suite: unit, widget, integration demo flow | 11 | all | | pending |
| WP-24 | Release build, icons, splash, README, APK | 12 | WP-23 | | pending |

## Parallel lanes (for max throughput)

Once P0 is done (WP-01 to WP-03), run these lanes in parallel:

- **Lane A (Core):** WP-04, WP-05, WP-06, WP-07, WP-08, WP-20
- **Lane B (UI):** WP-09, WP-10, WP-11, WP-12, WP-19, WP-21
- **Lane C (AI):** WP-13, WP-14, WP-15, WP-16, WP-17
- **Lane D (Focus and polish):** WP-18, WP-22
- **Lane E (QA and release):** WP-23, WP-24 (starts writing tests as soon as WP-07 lands)

Lane B blocks on Lane A for data. Use the contracts in `04` and `05` to build against fakes while the implementations are in progress. Fakes live in `test/fakes/`.

## Agent roster

| Agent | Packages | Primary files |
|---|---|---|
| Lead | WP-01, merges, contract changes | 00, 01, 03, 10 |
| UI Agent | WP-02, WP-03, WP-09 to WP-12, WP-21, WP-22 | 02, 06 |
| Data Agent | WP-04 to WP-06 | 04 |
| Core Agent | WP-07, WP-08, WP-18, WP-20 | 07, 09 |
| AI Agent | WP-13 to WP-17 | 05, 08 |
| QA Agent | WP-23 | 11 |
| DevOps Agent | WP-24 | 12 |

## Contract change requests

When a contract needs to change, add a row here instead of editing the contract yourself:

| Date | Requested by | File and section | Change | Reason | Approved by | Status |
|---|---|---|---|---|---|---|
| | | | | | | |

## Handoff rules

- Before marking a package `done`, the owner runs `flutter analyze` and `flutter test` and attaches the output summary.
- Each package writes a short `HANDOFF.md` note in its feature folder: what exists, what is faked, what is missing.
- Blocked more than 30 minutes? Post the blocker in the table notes and switch to the next unblocked package.
