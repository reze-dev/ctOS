# Changelog

All notable changes to ctOS are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## [Unreleased]

### Fixed

#### Major Bug Fixes

- **Radial menu geometry was completely inverted** — Trees grew sideways across their own segment instead of outward along the segment axis. Fixed by correcting the layout frame from `(sin, -cos)` to `(cos, sin)` so `dir 0` maps to `+x` (outward). (commit `1162e81`)

- **Radial tree branching was dendrite instead of columns** — Each fork was inherited by the subtree, causing ever-widening spread. Now fork angle is local to the generation; descendants return to the axis, producing parallel columns. (commit `be5bda0`)

- **Preview trunk was 2× too long** — `r1Point` 300 → 242, matching the reference proportion (0.35× ring radius). The drawn trunk went from 99px to 41px. (commit `53b39d8`)

- **Mic volume slider was completely broken** — Node declared `minValue`/`maxValue`/`stepSize` but slider reads `minVal`/`maxVal`/`step`. It inherited defaults `0/100/1` against a 0–1 gain, making it off-or-full with nothing between. Also added missing `root.revision++` for repaint. (commit `21a006f`)

- **Wallpaper selection reverted after reboot** — Three stacked faults:
  1. `ctos-wallpaper.service` applied v1 unconditionally, never reading `settings.json`
  2. Fallback could destroy the record: a premature scan saw the default `wallpaper-v1.png`, which wasn't in the directory, so it wrote the first image over the user's choice and saved it
  3. Stale-result guard compared against the *intended* directory, so an old scan's files were adopted as the current directory's — producing fallbacks to images from the wrong directory
  (commit `5c0f726`)

- **Boot flash of wallpaper v1** — `ctos-wallpaper.service` hardcoded v1. Now the unit reads `settings.json` and applies the recorded choice, falling back to v1 only when the setting is missing/unreadable/invalid. Removed dead code `defaultWallpaper`. (commit `7dccfff`)

- **Network/Bluetooth popups were dead code but live** — 1682 lines deleted. Notch and IPC rewired to Command Center cards. Verified zero ReferenceErrors on boot. (commit `f557517`)

- **Mic volume slider was inverted contract** — Node used `minValue`/`maxValue`/`stepSize` but slider reads `minVal`/`maxVal`/`step`. Added missing `root.revision++` for repaint. (commit `21a006f`)

#### Minor Bug Fixes

- **Wallpaper grid only showed 2 rows** — Footer filler `Item { Layout.fillHeight: true }` competed with browser control box for leftover space. Filler now yields when browser is active: 2 → 5 rows. (commit `58ee861`)

- **Wallpaper list never refreshed** — Scanned once at boot. Now rescans when browser becomes visible. (commit `58ee861`)

- **Stale scan results from wrong directory** — `_scannedDir` recorded intent, not actual scan directory. Scan output now self-describes its directory; guard compares against that. (commit `5c0f726`)

- **Preview trunk drawn 2× too long** — `r1Point` 300 → 242 (reference proportion 0.35× ring radius). Visible run: 99px → 41px. (commit `53b39d8`)

- **Radial preview trunk was 2× too long** — `r1Point` 300 → 242 (reference proportion 0.35× ring radius). Visible run: 99px → 41px. (commit `53b39d8`)

- **Radial trees grew sideways** — Local layout frame was `(sin, -cos)` so `dir 0` = up. Changed to `(cos, sin)` so `dir 0` = +x (outward). (commit `1162e81`)

- **Radial trees were dendrites, not columns** — Fork angle was inherited by subtree. Now fork is local; descendants return to axis. (commit `be5bda0`)

- **Network/Bluetooth popups showed wrong glyph** — Notch always showed wifi glyph even on ethernet. Now conditional: wifi glyph on WiFi, ethernet glyph on wired. (commit `bfcac30`)

- **Volume/battery glyphs too small** — `opticalScale`: volume 0.85→0.90, battery 0.73→0.85 (now matches wifi scale). (commit `bfcac30`)

- **DevShell `CTOS_INPUT` flag was broken** — `${CTOS_INPUT: -0}` inside indented string was parsed as Nix interpolation. Fixed to `''${CTOS_INPUT:-0}`. (commit `b04f5f5`)

- **`defaultWallpaper` dead code removed** — Defined but never referenced. (commit `7dccfff`)

### Added

- **Wallpaper grid scroll indicator** — Hand-rolled track+thumb (no Controls dependency). Thumb proportional to visible fraction with 24px floor. Travel arithmetic verified: thumb lands exactly on track bottom at max scroll. (commit `8cac07e`)

- **Conditional network glyph in notch** — WiFi glyph on WiFi, ethernet (router) glyph on wired. Detail shows signal% on WiFi, "LAN" on Ethernet. (commit `bfcac30`)

- **Ethernet glyph added** — Material Symbols U+E328 (router) added to `GlyphIcon.qml`. (commit `bfcac30`)

- **Volume/battery glyph size parity** — Volume `opticalScale` 0.85→0.90, battery 0.73→0.85 (matches wifi scale). (commit `bfcac30`)

- **Wallpaper unit reads recorded choice** — `ctos-wallpaper.service` now reads `settings.json` and applies recorded choice; falls back to v1 only when unreadable/absent/invalid. (commit `7dccfff`)

- **Wallpaper grid scroll indicator** — Hand-rolled track+thumb with 24px floor. (commit `8cac07e`)

- **Wallpaper rescans on browser open** — List was frozen at boot; now rescans when browser becomes visible. (commit `58ee861`)

- **Stale scan guard now self-describing** — Scan output declares its directory; guard compares against that, not against overwritten `_scannedDir`. (commit `5c0f726`)

- **Mic volume slider contract fix** — Node used `minValue`/`maxValue`/`stepSize`; slider reads `minVal`/`maxVal`/`step`. Added missing `root.revision++`. (commit `21a006f`)

- **DevShell `CTOS_INPUT` escaping fix** — `${CTOS_INPUT: -0}` → `''${CTOS_INPUT:-0}`. (commit `b04f5f5`)

### Changed

- **Radial trees now grow outward** — Local frame `(cos, sin)` so `dir 0` = +x (outward). `projectPoint` maps this to outward radial for every segment. (commit `1162e81`)

- **Radial fork angle is now local** — Descendants return to axis, producing parallel columns instead of widening dendrite. (commit `be5bda0`)

- **Preview trunk shortened to reference proportion** — `r1Point` 300 → 242 (0.35× ring radius). (commit `53b39d8`)

- **Wallpaper unit now reads settings** — Applies recorded choice; falls back to v1 only on error. (commit `7dccfff`)

- **Network/Bluetooth popups retired** — Replaced by Command Center cards. Notch and IPC rewired to CCC submenus. (commit `f557517`)

- **Volume/battery glyph sizes increased** — Volume `opticalScale` 0.85→0.90, battery 0.73→0.85. (commit `bfcac30`)

- **Conditional network glyph in notch** — WiFi glyph on WiFi, ethernet glyph on wired. Detail shows signal% or "LAN". (commit `bfcac30`)

- **Ethernet glyph added** — Material Symbols U+E328 (router). (commit `bfcac30`)

- **DevShell `CTOS_INPUT` escaping fixed** — `${CTOS_INPUT: -0}` → `''${CTOS_INPUT:-0}`. (commit `b04f5f5`)

- **`defaultWallpaper` dead code removed** (commit `7dccfff`)

### Removed

- **NetworkPopup.qml** (910 lines) — Retired, replaced by CCC WiFi card. (commit `f557517`)

- **BluetoothPopup.qml** (772 lines) — Retired, replaced by CCC Bluetooth card. (commit `f557517`)

- **`defaultWallpaper`** dead code in `wallpaper.nix` (commit `7dccfff`)

- **`toggleNetwork`/`toggleBluetooth` helpers in `shell.qml`** — Rewired to CCC submenus. (commit `f557517`)

- **`bluetoothVisible`/`networkVisible` properties** — No longer needed. (commit `f557517`)

- **Per-screen liveness checks for popups** — No longer needed. (commit `f557517`)

---

## [0.1.0] - 2026-10-05

Initial release baseline.