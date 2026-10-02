# ctOS shell — interaction specification

Visual target: [`../target/`](../target/README.md). Geometry, colour and section
contents are specified there and are not repeated here. This document covers
input routing, state transitions and safety rules.

## One primary surface at a time

The notch is always present. On top of it, at most one of the following is open:
Command Deck, CCC, Calendar C.

Opening one closes another. `Escape` and an outside click both close the active
surface. Closing never discards notification history or a completed action.

The Command Deck and the CCC are opened by **different** targets and must never be
ambiguous:

| Target | Opens |
| --- | --- |
| Notch **logo** | Command Deck |
| Notch **body** (idle or expanded) | CCC |
| Notch **clock** | Calendar C |
| Notch **workspace slot** | switches workspace; does not open a surface |

## Notch state machine

```
IDLE ──hover──► EXPANDED ──pointer leave──► IDLE
  │                 │
  └──click──► CCC_OPEN ──collapse / Esc / outside──► EXPANDED
```

`EXPANDED` and `CCC_OPEN` are mutually exclusive. While `CCC_OPEN`, pointer exit
must not collapse the notch. Any implementation that lets hover-collapse and
CCC-open run concurrently produces flicker — this has been regressed before and
the pin is not optional.

Notification arrival and media playback are *content* changes within the current
state, not separate states. They do not alter the hover contract.

## Output selection

The CCC and Calendar C open on the output that was focused at the moment of the
click. If that output disappears while the surface is open, the surface closes and
state returns to the remaining desktop. No stale screen reference may keep a
surface alive.

## Input handling

The notch changes size during hover, so pointer hit-testing must follow the
*visible rounded pill*, not the item's rectangular bounds. A rectangular test
re-triggers hover in the corners as the pill grows and produces a hover loop.

- Hover is tracked with a `HoverHandler`, not a `MouseArea`. `MouseArea` both
  consumes button events and reports hover, which conflicts with the button
  routing the notch needs.
- Button routing stays on a `MouseArea` placed behind the content, which rejects
  presses outside the pill.
- Clicking inside a surface must not be swallowed by the surface that dismisses
  on outside click. Use a dismissal layer beneath the panel plus an accept
  consumer inside it.
- Wheel over the notch or CCC header adjusts volume in 5 % steps.

## Keyboard

| Action | Default binding |
| --- | --- |
| Toggle Command Deck | `Super` |
| Toggle CCC | `Super+Space` |
| Toggle Calendar C | `Super+N` |
| Lock session | `Super+L` |

These are proposed defaults exposed through the Home Manager module and must be
overridable without the module silently replacing a user binding. Note that
`Super+Space` currently maps to `toggleCommandDeck` in the shipped config; that
mapping must change to match this table.

Command Deck keyboard model: focus starts in the query field; arrows move
selection; `Enter` activates; `Escape` closes. Mouse behaviour must match.

## Session safety

- **Lock** executes immediately.
- **Logout**, **reboot** and **power off** replace the action row with an explicit
  in-panel confirmation. `Escape` or Cancel returns safely.
- Power off is the only element rendered in the danger colour.
- All four go through `SessionService`. No surface may spawn the underlying
  command itself.

## Notifications

ctOS is the notification server when the feature is enabled. An incoming
notification creates a brief toast and a history record. Do-not-disturb suppresses
toasts and retains history. Urgency is conveyed by icon tint and an edge stripe,
not by recolouring text.

## Accessibility

`Settings.reducedMotion` collapses all durations and disables springs. Every
surface must honour it — this is currently not true of the radial subsystem or
the notification urgency pulse.

Meaning is never carried by colour alone. All controls expose visible focus and
readable contrast independent of the accent.
