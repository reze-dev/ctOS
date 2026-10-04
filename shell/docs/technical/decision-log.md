# Technical decision log

## Accepted decisions

| ID | Decision | Rationale | Consequence |
| --- | --- | --- | --- |
| TD-001 | Use a `flake-parts`-organized flake. | Keeps a growing Nix project organized while exporting normal Nix interfaces. | Add `flake.nix` and modular Nix files before desktop implementation. |
| TD-002 | Export a Home Manager module as the primary public interface. | ctOS is a per-user Wayland session application with user-owned settings and keybindings. | Public options live under `programs.ctOS`; a NixOS module is deferred. |
| TD-003 | Support Hyprland only in v1. | The existing prototype already imports Quickshell Hyprland and the target ctos uses Hyprland. | Compositor access is isolated behind a Hyprland adapter so Niri can follow later. |
| TD-004 | Replace the prototype bar with `shell.qml` and isolated surfaces. | The current bar mixes UI, polling, and compositor policy. | `bar.qml` is not the v1 integration point. |
| TD-005 | Own primary overlay state centrally. | Prevents overlapping panels and inconsistent focus behavior. | A single OverlayController routes Command Deck, System Rail, and Event Log requests. |
| TD-006 | Use native ctOS notifications in v1. | Event Log and toast behavior are core to the intended desktop language. | ctOS must be the only active notification server when enabled. |
| TD-007 | Use a fixed ctOS dark theme for v1. | Provides a coherent baseline with fewer runtime dependencies. | Dynamic and wallpaper-derived themes are postponed. |
| TD-007 | **Superseded by TD-010.** ~~Use a fixed ctOS dark theme for v1.~~ | A single hardcoded palette in `Theme.qml` made every colour change a file edit, and the token names drifted from their meanings — `acidGreen` resolved to magenta. | Retained for history. The fixed-theme decision no longer holds. |
| TD-008 | Preserve greeter/lockscreen behavior and package it separately. | Authentication code has a different security and lifecycle boundary from a desktop shell. | No desktop feature may depend on greeter services. |
| TD-009 | Prefer reactive Quickshell services/adapters over UI-owned shell polling. | Keeps rendering, data acquisition, error handling, and resource lifetime separate. | Prototype CPU/RAM loops are not reused. |
| TD-010 | Ship the shell palette as 22 named slots in per-palette data files, selected at runtime from `Settings.theme`. Supersedes TD-007; decides TD-D03. | Two palettes are wanted, so the choice cannot live in the source. Slots keep colour out of the token file, which is what lets the ~90 call-facing tokens be pure aliases and lets a switch repaint without a restart. | `Theme.qml` holds no hex values. An unknown theme name or a palette missing a slot falls back to `ctos-pine` with a logged error rather than rendering undefined colours. Palette values and provenance are documented in [`../target/colors.md`](../target/colors.md) and in `core/palettes/`. Wallpaper-*derived* theming stays out of scope — the palette is chosen, not computed. |

## Deferred decisions

| ID | Deferred item | Trigger for deciding |
| --- | --- | --- |
| TD-D01 | NixOS system module | A system-owned feature requires declarative installation beyond Home Manager. |
| TD-D02 | Niri adapter | The Hyprland v1 adapter and core surface contracts are stable. |
| TD-D03 | **Decided by TD-010.** ~~Dynamic theming~~ | Fixed-theme contrast and token system are validated in daily use. | Runtime palette selection is in. Themes are a closed set of authored palettes; deriving one from the wallpaper is still deferred and has no trigger yet. |
| TD-D04 | File search and clipboard history | Command Deck action/application search has a stable data model and interaction flow. |
| TD-D05 | Bluetooth, overview, calendar, screenshots, recording, and media controls | v1 daily-driver acceptance is complete. |

## Implementation conventions

- New desktop modules use `desktop/` and do not import `greeter/`.
- Services expose availability, status, reactive values, and named actions; surfaces do not execute backend shell commands directly.
- Generated Home Manager settings are the desktop runtime’s configuration boundary. Do not write machine-specific settings to `/etc/ctos` for the desktop shell.
- Every new optional integration has a visible unavailable state and a startup diagnostic.
- Any change to these decisions updates this log and the affected design document in the same commit.
