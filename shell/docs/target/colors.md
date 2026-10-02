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
| `acidGreen` | `#1BFD9C` | `#4FE7A2` | **deprecated alias** for `statusGreen` |
| `success` | `#1BFD9C` | `#4FE7A2` | status only |
| `connected` | `#1BFD9C` | `#4FE7A2` | status only |
| `warningRed` | `#FC3E38` | `#D1605D` | danger; matches `--danger` |
| `destructive` | `#FC3E38` | `#D1605D` | follows `danger` |
| `error` | `#FC3E38` | `#D1605D` | follows `danger` |
| `warning` | `#FC3E38` | `#D1605D` | follows `danger` |
| `border` | `#D9D9D9` | `#243D70` | **must be redefined**, not inherited from `gray200` |
| `hairline` | `#D9D9D9` | `#243D70` | **must be redefined** |
| `divider` | `#7A7A7A` | `#243D70` | **must be redefined** |
| `ctosGray` | `#D9D9D9` | `#243D70` | **must be redefined** |

### New tokens to add

```
readonly property color statusGreen:  "#4FE7A2"
readonly property color accentMagenta: "#EB4ADF"
readonly property color accentBlue:    "#4695F6"
readonly property color accentViolet:  "#7362F5"
readonly property color borderSubtle:  "#243D70"
readonly property color surfaceDeep:   "#061121"
readonly property color pageBackground: "#050E1E"
```

### Deprecation policy

`acidGreen` keeps working as an alias for `statusGreen` so the existing 142 call
sites do not break visually mid-migration. Call sites must not be *added*; each
one migrated to `statusGreen`, `accentMagenta`, or `accentBlue` as appropriate.
Remove the alias once the count reaches zero.

`accent` currently has 142 direct references via `acidGreen`. Any reference that
meant "this is selected/active/focused" must move to `accent`; any reference that
meant "this is healthy/connected" must move to `statusGreen`. These are different
intentions and the old single-green token could not distinguish them.

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
