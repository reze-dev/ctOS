# ctOS Colour System

Source of truth for `shell/desktop/core/Theme.qml` and the palettes it selects
between, in `shell/desktop/core/palettes/`.

This document previously described a navy palette (`#050E1E` base, `#EB4ADF`
magenta accent) that the code no longer contains. The tables below are generated
from the palette files and were checked against `Theme`'s resolved token values
under both palettes.

## Architecture

Three layers, and only the bottom one holds a hex:

| Layer | Where | What it is |
| --- | --- | --- |
| Slots | `palettes/*.js` | 22 named slots per palette. The only place a colour value exists. |
| Roots | `Theme.qml`, `pal*` | One token per slot, wrapped in `Qt.color`. |
| Aliases | `Theme.qml`, everything else | ~90 call-facing tokens pointing at the roots. |

A theme change is therefore a change to `Settings.theme` and nothing else. Every
alias re-resolves, which is why switching repaints the shell without a restart.

## Palettes

`ctos-pine` is the default. `ctos-dark` is the acid palette and predates the
navy rebrand, which is where its name comes from — it is not the darker of the
two, and both are dark.

| Slot | `ctos-pine` | `ctos-dark` | Role |
| --- | --- | --- | --- |
| `bg` | `#13111E` | `#0E0E0E` | page background |
| `surface` | `#191724` | `#202020` | card, panel body |
| `raised` | `#262431` | `#333333` | anything lifted off the page |
| `hover` | `#2E2C39` | `#2A2A2A` | hover state |
| `active` | `#3F3D4A` | `#333333` | pressed / selected border |
| `selected` | `#262431` | `#1A2E24` | selected row. Tinted in acid, grey in pine |
| `border` | `#3F3D4A` | `#3F3D4A` | control edge |
| `borderMuted` | `#6E6A86` | `#7A7A7A` | de-emphasised edge |
| `divider` | `#3F3D4A` | `#3F3D4A` | separator between rows |
| `text` | `#E0DEF4` | `#FFFFFF` | primary text |
| `textDim` | `#C8C5DC` | `#CACACA` | secondary text |
| `textMuted` | `#908CAA` | `#9E9E9E` | tertiary text |
| `textDisabled` | `#3F3D4A` | `#4A4A4A` | disabled text |
| `textInverse` | `#13111E` | `#0E0E0E` | text on an accent fill |
| `accent` | `#C4A7E7` | `#1BFD9C` | active, selected, focused |
| `status` | `#31748F` | `#1BFD9C` | connected, charging, positive |
| `destructive` | `#EB6F92` | `#FC3E38` | error, danger |
| `warning` | `#F6C177` | `#FF964F` | caution |
| `cool` | `#8BBEC7` | `#66B2B2` | informational secondary |
| `love` | `#EB6F92` | `#1BFD9C` | the notch's identity mark |
| `destructiveDim` | `#5E3246` | `#6D211F` | muted half of a destructive pair |
| `radialBackdrop` | `#2A2313` | `#0C2126` | the radial settings surface's own floor |

Notes that do not fit in a cell:

- **`radialBackdrop` is not `bg`.** The radial covers the whole screen while it is
  open and reads as its own place, so it takes a palette-specific floor —
  bronze under pine, deep teal under acid — instead of sharing the desktop's page
  background. Its grid checkerboard is tinted from the same slot, or the grid
  would sit a different hue on the floor. Both values are dark enough for the
  light text and grid that sit on them.
- **`border` and `divider` are separate slots that hold the same value in both
  palettes.** They are kept apart because they mean different things and
  because acid is where they would diverge if they were going to.
- **`selected` is the only tinted surface.** Acid's `#1A2E24` is a desaturated
  green so a selected row reads as *selected* rather than merely brighter. Pine
  cannot afford it: pine's `selected` is also its `raised`, and tinting it would
  drag every raised surface green with it.
- **`accent` and `status` are the same value in acid** (`#1BFD9C`). That collapses
  the accent/status distinction for that palette only. The slots stay separate so
  pulling them apart later is a one-value change.
- **`destructiveDim` in acid is derived**, not picked: `#FC3E38` at 40% toward
  `#0E0E0E`. No acid-era equivalent existed — the slot was introduced with the
  navy rebrand — so it is expressed as a ratio so it keeps tracking
  `destructive` and `bg`.
- `ctos-pine` is a Rosé Pine derivative from nvchad's base46 theme, not the
  official Rosé Pine release. Its base is `#13111E` against official Main's
  `#191724`, so it reads deeper and more muted. Per-slot provenance is in
  `PinePalette.js`'s `notes()`.

## Validation

`Theme.themeName` resolves `Settings.theme` against its registry and checks that
all 22 slots are present and non-empty. An unknown name or an incomplete palette
falls back to `ctos-pine` with a `console.error` naming the problem.

This is checked rather than assumed because a missing slot does not fail — it
resolves to `undefined`, `Qt.color(undefined)` is transparent black, and the
visible result is an invisible border or unreadable text with nothing in the log.

## Token naming: two known warts

Both are preserved deliberately rather than fixed, because fixing either changes
rendering or breaks call sites, and neither is worth that in a palette extraction.

### `acidGreen` is not green

`Theme.acidGreen` and `Theme.accentGreen` both resolve to the **accent** slot.
Under pine that is lavender; under acid it happens to be green. The name is
accurate only by coincidence in one of the two palettes.

It is kept because it has ~127 call sites. Audited by meaning rather than name,
the large majority are borders, corner brackets, hover and focus rings — the
generic accent — and only about 39 are genuine status sites, which now use
`statusGreen` explicitly. Aliasing it to `statusGreen` would paint ~88 borders
and focus rings green.

New code must not reference it. Use `accent` / `accentMagenta` for attention and
`statusGreen` for health.

### `textMuted` resolves to the *border*-muted slot

The slots distinguish `borderMuted` (`#6E6A86` in pine) from `textMuted`
(`#908CAA`). Before the split, `Theme.textDim` and `Theme.textMuted` were both
`#6E6A86` — the tree conflated the two roles.

Mapping the tokens to the same-named slots would have quietly lightened every
muted label in pine, so the tokens keep the value they have always rendered with:

| Token | Resolves to | Pine value |
| --- | --- | --- |
| `Theme.textDim` | `palette.borderMuted` | `#6E6A86` |
| `Theme.textMuted` | `palette.borderMuted` | `#6E6A86` |
| `Theme.textPrimaryDim` | `palette.textDim` | `#C8C5DC` |
| `Theme.textPrimaryDimmer` | `palette.textMuted` | `#908CAA` |

The clean fix is to rename the slots to match the tokens rather than the reverse,
but that is a breaking change for anything that names a slot in config.

## `gray50`–`gray900` are an alias layer, not a ramp

These are the most-used tokens in the tree and the worst-named: `gray700` is a
hover surface, `gray900` is the page background, `gray600` is a border, and only
`gray50`/`100`/`200` are text steps. Each resolves to the slot that means the same
thing, which is what lets the neutral ladder follow the active palette instead of
pinning it.

| Token | Slot | Pine | Acid |
| --- | --- | --- | --- |
| `gray50` | `text` | `#E0DEF4` | `#FFFFFF` |
| `gray100` | `textDim` | `#C8C5DC` | `#CACACA` |
| `gray200` | `text` | `#E0DEF4` | `#FFFFFF` |
| `gray300` | `textMuted` | `#908CAA` | `#9E9E9E` |
| `gray400` | `borderMuted` | `#6E6A86` | `#7A7A7A` |
| `gray500` | `borderMuted` | `#6E6A86` | `#7A7A7A` |
| `gray600` | `border` | `#3F3D4A` | `#3F3D4A` |
| `gray700` | `hover` | `#2E2C39` | `#2A2A2A` |
| `gray800` | `surface` | `#191724` | `#202020` |
| `gray900` | `bg` | `#13111E` | `#0E0E0E` |

`border`, `ctosGray`, `divider` and `hairline` are the four tokens that resolve
identically in both palettes.

## Canvas colours

Canvas drawing APIs take CSS colour strings, not QML colours, so a small set of
string-form tokens exists: `accentMagentaHex`, `statusGreenHex`, `dangerHex`,
`dangerDimHex`, `textDimHex`, `gray300Hex`, `gray700Hex`. Each is a direct read
of the slot its colour-token namesake resolves to.

For translucent draws use `Theme.withAlpha(colour, a)`. Six call sites in
`CpuHexGrid.qml` and one in `NetworkFlowMatrix.qml` used to hand-write
`rgba(27, 253, 156, …)` — invisible to a grep for palette drift, because the
literal never mentioned a token. That is how those two widgets stayed green
through the last rebrand while everything around them changed.

## Gradients

The notch ring is a three-stop horizontal gradient, `cool → accent → accent`
(`accentBlue → accentViolet → accentMagenta`, or `danger` at both ends while a
notification is at urgency 2). Because the mid and end stops resolve to the same
slot, only the left half of the ring carries a hue shift: teal→lavender in pine,
teal→green in acid.

## Out-of-band colour

The QML tree is clean: no hex literal outside the palette files, and no
`"black"`/`"white"` in QML. The remaining literals are the SVG assets in
`shell/desktop/assets/icons/`, whose `fill="white"` is the tinting mechanism —
`CtosIcon.color` recolours them — not a palette leak.
