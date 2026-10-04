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

- **Base:** deep and low-chroma, never a flat neutral. Two palettes ship;
  `ctos-pine` is a Rosé Pine derivative and `ctos-dark` a neutral grey with one
  green-tinted surface. Neither is "the" palette -- the shell picks one from
  `Settings.theme`.
- **Identity:** a horizontal gradient along the notch and CCC border, running
  `cool → accent → accent`. Because the mid and end stops resolve to the same
  slot, only the left half carries a hue shift: teal→lavender in pine,
  teal→green in acid.
- **Meaning of colour** is per-role and identical in both palettes:
  - `accent` = active, selected, focused, today
  - `cool` = interactive affordance, live value
  - `status` = healthy, connected, positive
  - `destructive` = error, danger **only**
  - `warning` = caution
- The accent is not green. That was the central change from the shell's first
  identity, where one green meant everything at once. It holds in pine, where
  the accent is lavender. In acid the accent happens to be green again, but by
  coincidence of that palette rather than by intent — the slots are separate so
  pulling them apart is a one-value change.
- **Typography:** monospace for data, a proportional sans for labels. Large type
  is reserved for the clock and active query, never decoration.
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

The radial settings skill tree is now a target surface rather than a retained
prototype. It is where the shell's own settings live, including the palette
switch, so it is held to the same rules as the notch and the CCC: its controls
are real, its values are read from and written to Settings, and its lock states
name a requirement they actually enforce.

The floating desktop telemetry widgets still predate this target and are
retained unchanged. They are not part of the target design and their removal is
a separate decision.
