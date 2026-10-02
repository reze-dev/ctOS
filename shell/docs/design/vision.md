# ctOS shell — vision

## Product statement

**ctOS is a calm Wayland desktop whose entire top surface is one shape that
changes according to what you are doing.** A single notch rests at the top of
every output, breathes open on hover, and unfolds into a full command centre on
click. There is no other bar, no tray, and no cluster of independent popups.

## Experience model

| State | Surface | Intensity |
| --- | --- | --- |
| Idle | 220 × 30 notch | quiet, near-black, one gradient edge |
| Hover | 320 × 60 notch | adds a second content row |
| Open | Command & Control Center | the working surface — dense on demand |
| Deep | Calendar C | full-width, month + timeline |

At rest the user sees a small pill and the wallpaper. Everything else is a
consequence of an explicit action.

## Visual grammar

- **Base:** deep navy, never neutral grey. Surfaces are `#050E1E` through
  `#0A192C`; cards are `#061121`.
- **Identity:** a single horizontal gradient — blue `#4695F6` → violet `#7362F5` →
  magenta `#EB4ADF` — runs along the notch and CCC border. It is the shell's
  signature and appears nowhere else at that weight.
- **Meaning of colour:**
  - magenta = active, selected, focused, today
  - blue = interactive affordance, live value
  - green = healthy, connected, positive **only**
  - red = destructive **only**
- Green is not the accent. This is the central change from the shell's previous
  identity, where a single green meant everything at once.
- **Typography:** monospace throughout. Large type is reserved for the clock and
  active query, never decoration.
- **Geometry:** stadium-shaped pill at rest; 12–16 px radii on cards; hairline
  borders; generous internal padding.
- **Glow:** present but restrained. A shell, not a nightclub.

## Motion

Motion communicates state change only. Springs drive the notch on both axes with
a slight overshoot; accordions interpolate height; content crossfades. No
persistent ambient animation except a subtle NOW marker in Calendar C.

Motion must never delay input. `reducedMotion` removes all of it.

## Identity and originality

The shell uses original terms and construction. It is inspired by the general
grammar of tactical interfaces — terse labels, grids, segmented controls,
verification states — without reproducing game screens, layouts, or assets, and
without claiming affiliation.

## Scope

**In:** the unified notch, the CCC, Calendar C, Command Deck, notifications,
session controls with confirmation, and declarative packaging including the
existing greeter.

**Out:** Niri support, window overview, clipboard history, file search, screenshot
workflows, dynamic wallpaper theming, and any second top-edge surface.

The radial settings skill tree and the floating desktop telemetry widgets predate
this target and are retained unchanged. They are not part of the target design
and their removal is a separate decision.
