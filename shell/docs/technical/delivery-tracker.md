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
| A5 | Rebase `Theme.qml` on the navy ramp; add neon tokens; keep legacy aliases | done — superseded |
| A6 | Reconcile `Theme.barHeight` / `Settings.barHeight` to one source of truth | todo |

A2 and A3 are small and unblock visual evaluation. A4 must land before Calendar C
is built so the duplicated date math is not extended a third time.

A5 was closed as superseded rather than completed: the navy ramp it asked for is
not the palette the shell ended up with. It was replaced by extracting the
existing pine palette into `core/palettes/PinePalette.js`, adding the acid
palette alongside it as `AcidPalette.js`, and reducing `Theme.qml` to aliases over
21 validated slots. Two user-selectable palettes, not one navy ramp.

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

## Phase R — Radial settings skill tree

Brought in scope when the radial gained the palette switch and became the place
the shell's own settings live. Previously listed under "Out of scope" as a
retained prototype; it is now held to the same rules as the notch and the CCC.

Reference images are in the repository root: `base-settings-tree.png`,
`base-settings-tree-with-highlight.png`, `2-branch-tree-expanded.png`,
`3-branch-tree-expanded.png` and `WatchDogs1 Skill tree background..png`.

| # | Item | Status |
| --- | --- | --- |
| R1 | Stop printing "PREREQUISITE LOCKED" while enforcing nothing | done — see below |
| R2 | Resolve the stub nodes and the invented lock reasons | done — 5 removed, 3 replaced |
| R3 | Honour `Settings.reducedMotion` in every animating surface | done — 35 durations, 3 timers, 1 infinite loop |
| R4 | `leftAnchorX: -70` | **no change** — reviewed against the references and it is deliberate |
| R5 | Delete the never-emitted `RadialSegment.clicked()` / `hovered()` signals | done |
| R6 | `net-core` reports a raw interface name instead of a connection state | done |
| R7 | Glyphs on preview nodes | done — were hidden outright, so the base-state trees were blank |
| R8 | Blip in both states: red when off, green when on | done |
| R9 | Resolve the `readonly` nodes | done — 5 deleted, 3 made functional |
| R10 | More nodes and branches per section | todo — plus the security tooling branches |
| R11 | Animated 3D-city skill-tree background (`WatchDogs1` reference). Not implemented | todo |

R7–R10 came from reading the reference images against the running shell. The arc
maths the references describe is already implemented and was verified against
them: `focusedWidth` is 90°, exactly 1/4 of the circumference, the focused arc is
anchored at the top and neighbours are pushed out sequentially, and the remaining
7 share the other 3/4. The gap unit is degrees rather than the 2px the reference
implies, which was reviewed and accepted.

## Out of scope

Retained unchanged, not part of the target design:

- Floating desktop telemetry widgets (`desktop/surfaces/widgets/`)

Their removal is a separate decision.
