# ctOS desktop shell — vision

## Product statement

**ctOS is a calm Wayland desktop that reveals a live operations interface when summoned.** It is a personal NixOS/Hyprland rice built with Quickshell. It takes inspiration from ctOS’s interface grammar—machine identity, terse signals, grids, segmented controls, and verification states—without reproducing game screens or claiming affiliation.

The desktop must remain pleasant to use for long work sessions. Visual spectacle is an interaction response, not permanent background noise.

## Audience and platform

- Primary audience: the maintainer’s personal NixOS configuration.
- Runtime target: NixOS with Hyprland and Wayland.
- Input target: keyboard-first, with every v1 interaction also usable by mouse.
- Development hosts may differ from NixOS; they are not supported deployment targets.

## Experience model

| Layer | Purpose | Visual intensity |
| --- | --- | --- |
| Ambient | Bar, state indicators, OSDs, brief notification toasts | Quiet, low contrast, compact |
| Utility | Command Deck, System Rail, Event Log | Functional panels with ctOS framing |
| Immersive | Future overview and optional dashboard | Rich grid, telemetry, and staged motion |

Only ambient and utility layers are included in v1. At rest, the user sees one thin bar per output and the wallpaper. All dense information is intentional and on demand.

## Visual grammar

- **Base:** near-black surfaces, subtle grid/noise, hairline dividers, square or minimally rounded geometry.
- **Typography:** a legible monospace family for identifiers, values, and metadata; reserve large type for the active command/query, not decoration.
- **Color:** neutral grayscale carries almost all content. Acid green means active, connected, verified, selected, or recording. Red means error, warning, or destructive action. Color never supplies meaning alone.
- **Identity:** use neutral ctOS-inspired terms such as `NODE`, `SESSION`, `EVENT LOG`, and `COMMAND DECK`; avoid copied in-game text, layouts, or assets.
- **Density:** labels are short and values are scannable. Details expand inside panels rather than crowding the bar.
- **Wallpaper:** v1 ships a curated fixed dark wallpaper selection. Wallpaper-derived palettes are out of scope.

## Motion and accessibility

- Opening a utility surface may use a short scan/assemble transition; closing is immediate or nearly immediate.
- Motion communicates hierarchy and state only. It must not delay typing, clicking, or closing.
- `reducedMotion` removes decorative scans, staggered content, and persistent noise while retaining essential focus/state changes.
- All controls expose visible keyboard focus, accessible text labels/tooltips where useful, and readable contrast independent of green/red accents.
- The shell must remain usable when a font, battery, network, media player, or optional backend is unavailable.

## v1 outcome and non-goals

The v1 daily-driver experience consists of an ambient bar, Command Deck, System Rail, volume/brightness OSDs, native notifications with history, ambient playback state, and declarative packaging of the existing greeter.

V1 explicitly does not include Niri support, a window overview, Bluetooth, calendar, clipboard history, file search, screenshot/recording workflows, dynamic theming, a media-control panel, or broad cross-distro support.
