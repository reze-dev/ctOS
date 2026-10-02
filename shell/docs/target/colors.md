# Neon Notch — Colour System

Source of truth for `shell/desktop/core/Theme.qml`. Values transcribed from the
four reference images in `images/`.

## Palette

| Role | Token | Hex |
| --- | --- | --- |
| Page background | `--bg` | `#050E1E` |
| Panel body | `--surface` | `#0A192C` |
| Card / deep surface | `--surface-2` | `#061121` |
| Subtle border, divider | `--border` | `#243D70` |
| Primary accent (blue) | `--blue` | `#4695F6` |
| Secondary accent (violet) | `--violet` | `#7362F5` |
| Highlight (magenta) | `--magenta` | `#EB4ADF` |
| Status positive (green) | `--green` | `#4FE7A2` |
| Text primary | `--text` | `#BACADA` |
| Text muted | `--muted` | `#606A9B` |
| Danger | `--danger` | `#D1605D` |

## Navy ramp

Replaces the neutral grayscale ramp. Every `Theme.gray*` reference resolves into
this ramp, so the whole shell shifts to cool navy without touching call sites.

| Token | Old | New | Use |
| --- | --- | --- | --- |
| `gray50` | `#FFFFFF` | `#EDF3FF` | maximum-contrast text |
| `gray100` | `#CACACA` | `#D6E0F5` | primary text, dim |
| `gray200` | `#D9D9D9` | `#BACADA` | primary text |
| `gray300` | `#C3C3C3` | `#9AA7CC` | text, dimmer |
| `gray400` | `#9E9E9E` | `#7A88B4` | text, disabled |
| `gray500` | `#7A7A7A` | `#606A9B` | muted text, secondary border |
| `gray600` | `#4A4A4A` | `#3D4877` | disabled text, deep border |
| `gray700` | `#202020` | `#1A2647` | elevated surface |
| `gray800` | `#0E0E0E` | `#0A192C` | surface |
| `gray900` | `#080808` | `#050E1E` | background |

## Semantic mapping — this is a remap, not a swap

The important consequence of the new palette is that **green stops being the
accent**. Green becomes a status role only. Magenta becomes attention.

| Token | Old value | New value | Note |
| --- | --- | --- | --- |
| `accent` | `#1BFD9C` | `#EB4ADF` | **semantic change.** Active workspace, current day, selection |
| `active` | `#1BFD9C` | `#EB4ADF` | follows `accent` |
| `textAccent` | `#1BFD9C` | `#EB4ADF` | follows `accent` |
| `borderActive` | `#1BFD9C` | `#EB4ADF` | follows `accent` |
| `acidGreen` | `#1BFD9C` | `#EB4ADF` | **misnomer.** Resolves to magenta — see below |
| `success` | `#1BFD9C` | `#4FE7A2` | status only |
| `connected` | `#1BFD9C` | `#4FE7A2` | status only |
| `available` | — | `#4FE7A2` | new; status only |
| `warningRed` | `#FC3E38` | `#D1605D` | danger; matches `--danger` |
| `destructive` | `#FC3E38` | `#D1605D` | follows `danger` |
| `error` | `#FC3E38` | `#D1605D` | follows `danger` |
| `warning` | `#FC3E38` | `#D1605D` | follows `danger` |
| `border` | `#D9D9D9` | `#243D70` | **pinned directly**, no longer from `gray200` |
| `hairline` | `#D9D9D9` | `#243D70` | **pinned directly** |
| `divider` | `#7A7A7A` | `#243D70` | **pinned directly**, no longer from `gray500` |
| `ctosGray` | `#D9D9D9` | `#243D70` | **pinned directly** |
| `surfaceSelected` | `#1A2E24` | `#3A1B47` | was green-tinted; now magenta-tinted |

### `acidGreen` resolves to magenta, not green

This is the one genuinely counter-intuitive decision in the token table, and the
first draft of this document got it backwards.

`acidGreen` has 127 call sites. Auditing them by meaning rather than by name:

| Meaning | Sites | Resolves to |
| --- | --- | --- |
| borders, corner brackets, hover, focus rings | ~88 | magenta — attention |
| connected / powered / charging / playing / not-overloaded | 39 | `statusGreen` — health |

So `acidGreen` was never carrying a status meaning at the majority of its call
sites; it was the generic accent. Aliasing it to `statusGreen` would have
painted 88 borders and focus rings green. It therefore resolves to **magenta**,
which is also why no call site outside those 39 needed editing — they inherit the
correct colour through the token.

The 39 status sites were converted to `statusGreen` explicitly. The token name is
now a misnomer and should eventually be renamed to `accentLegacy` and then
folded into `accent`; 88 remaining call sites make that a mechanical follow-up,
not a blocker.

### Tokens added

```
statusGreen  accentMagenta  accentBlue  accentViolet   -- semantic roles
pageBackground  surfaceDeep  borderSubtle               -- surfaces
notchWidthCompact  notchHeightExpanded  notchHostPadding
commandCenterWidth  commandCenterColumnGutter  commandCenterSectionRadius
calendarWidth  calendarHeight  accordionHeaderHeight     -- geometry
springStiffness  springDamping  springMass                -- motion
radiusLarge  borderWidthAccent  danger  blue  violet  magenta  green  red
```

### Deprecation policy

New code must not reference `acidGreen`. Use `accent` / `accentMagenta` for
attention and `statusGreen` for health. The alias exists only to avoid touching
88 call sites during the palette change.

## Gradients

The notch and CCC border is a horizontal three-stop gradient:

```
#4695F6  →  #7362F5  →  #EB4ADF
```

Current-day marker in the calendar is a two-stop radial/linear blend:

```
#EB4ADF  →  #7362F5
```

Volume slider track: `#7362F5` → `#4695F6`, left to right.

## Out-of-band colour

108 hex fills exist across the SVG assets in `shell/`, and 33 literal hex values
appear in 14 QML files outside `Theme.qml`. Both bypass the token system and will
survive a `Theme.qml` rewrite unchanged. They are inventory work, tracked
separately from the palette change; icon fills should be recoloured to
`currentColor` or a token reference where the icon permits.
