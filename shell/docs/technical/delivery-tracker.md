# ctOS delivery tracker

Replaces the previous T0–T8 milestone list, which described a bar-and-panel
architecture that no longer exists. The plan now follows the implementation order
in [`../target/neon-notch-spec.md`](../target/neon-notch-spec.md) §7.

**Status key:** `done` · `active` · `todo` · `blocked`

## Phase A — Foundations

| # | Item | Status |
| --- | --- | --- |
| A0 | Design baseline: target spec, colour system, reference images | done |
| A1 | Reconcile `shell/docs/` with the target; delete superseded documents | done |
| A2 | Fix CCC double-toggle so click → CCC actually opens | todo |
| A3 | Route session actions through `SessionService`; delete duplicate `Process` objects | todo |
| A4 | Delete dead code: `legacyCompatibilityLayer`, `DynamicIsland.qml`, duplicate calendar grids, orphan files | todo |
| A5 | Rebase `Theme.qml` on the navy ramp; add neon tokens; keep legacy aliases | todo |
| A6 | Reconcile `Theme.barHeight` / `Settings.barHeight` to one source of truth | todo |

A2 and A3 are small and unblock visual evaluation. A4 must land before Calendar C
is built so the duplicated date math is not extended a third time.

## Phase B — Notch

| # | Item | Status |
| --- | --- | --- |
| B1 | Idle state re-skin: 220 × 30 stadium pill, gradient border, glow | todo |
| B2 | Expanded state: 320 × 60, two-row date/time block, spring animation | todo |
| B3 | `reducedMotion` honoured by every animating surface | todo |
| B4 | Hover / CCC-open pin state machine — no flicker | todo |

## Phase C — Command & Control Center

| # | Item | Status |
| --- | --- | --- |
| C1 | Single-surface hosting: CCC inside `AmbientBar`, window grows downward | todo |
| C2 | Extend `flushWaylandMask()` to cover CCC bounds | todo |
| C3 | Two-column layout, 760 px, content-driven height | todo |
| C4 | Section: Notifications (count, DND, list, urgency) | todo |
| C5 | Section: Power & Session (4 tiles, danger poweroff, inline confirmation) | todo |
| C6 | Section: Audio (slider + media card with transport) | todo |
| C7 | Section: Wi-Fi and Bluetooth | todo |
| C8 | Section: System Status (CPU / Memory / Disk / Network) | blocked on A-scope: disk telemetry missing |
| C9 | Context-aware priority expansion | todo |

C1 is the architectural keystone. Until the CCC is hosted in the notch's own
window, the "one surface" requirement cannot be met regardless of layout work.

## Phase D — Calendar C

| # | Item | Status |
| --- | --- | --- |
| D0 | Decide event backend | blocked — no decision recorded |
| D1 | `CalendarService` with an `eventsForDate()` projection | todo |
| D2 | Month grid: navigation, Today, gradient current-day marker, event dots | todo |
| D3 | Day timeline: times, coloured segments, source, `⋮` menu, relative-time pill | todo |
| D4 | NOW marker | todo |
| D5 | `+ Add Event` | todo — may ship disabled until a write path exists |

## Phase E — Hardening

| # | Item | Status |
| --- | --- | --- |
| E1 | Services: capture `stderr`, handle `exited`, bound retries, log once on degrade | todo |
| E2 | `SystemMonitorService`: fix the one-way `available` latch | todo |
| E3 | `NetworkService`: stop passing Wi-Fi secrets as process arguments | todo |
| E4 | `NetworkTracerService`: real `available` probe; stop defaulting `ss` on | todo |
| E5 | DPI scale token in `Theme.qml`; retire absolute pixel literals | todo |
| E6 | `programs.ctOS` generates `settings.json`; implement the documented contract | todo |
| E7 | QML linting and execution wired into `nix flake check` / CI | todo |
| E8 | `Settings.barHeight` no longer conflicts with the notch geometry | todo |

`tests/` contains roughly 20,000 lines of QML e2e harness across four tiers and is
entirely outside CI. A4 will invalidate a portion of it; E7 should follow so the
remainder is actually exercised.

## Out of scope

Retained unchanged, not part of the target design:

- Radial settings skill tree (`desktop/surfaces/radial/`)
- Floating desktop telemetry widgets (`desktop/surfaces/widgets/`)

Their removal is a separate decision.
