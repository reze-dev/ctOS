# ctOS delivery tracker

**Status key:** `done` = acceptance evidence exists; `active` = current focus; `todo` = not started; `blocked` = external dependency or decision prevents work.

| Milestone | Status | Exit gate |
| --- | --- | --- |
| T0 — Design baseline | done | Product, interaction, architecture, Nix, audit, technical decisions, and validation documents exist. |
| T1 — Nix package and module | active | Flake evaluates; package builds; Home Manager module installs and starts an empty shell service. |
| T2 — Shell foundation | todo | `shell.qml`, generated settings, design tokens, OverlayController, and per-output window lifecycle work. |
| T3 — Hyprland ambient bar | todo | Reactive workspace/focused-window state and compact system state render on each output without UI-owned polling. |
| T4 — Command Deck | todo | Keyboard/mouse application and action search satisfies the interaction specification. |
| T5 — System Rail and OSDs | todo | Audio, mic, brightness, network, battery/power, and session confirmation work or degrade safely. |
| T6 — Notifications and Event Log | todo | ctOS owns notification delivery, toast behavior, history, and do-not-disturb. |
| T7 — Greeter packaging and documentation | todo | Existing greeter is opt-in packageable and docs describe Nix activation/recovery without changing auth behavior. |
| T8 — V1 acceptance | todo | All validation gates pass in the northstar NixOS/Hyprland configuration. |

## T1 — Nix package and module

- [ ] Create a flake-parts flake exporting a ctOS package and `homeManagerModules.default`.
- [ ] Define the initial `programs.ctOS` option skeleton from the Nix integration design.
- [ ] Package QML, resources, wallpapers, and generated runtime settings with stable install paths.
- [ ] Add a systemd user service for the desktop shell with bounded restart behavior.
- [ ] Add a minimal `shell.qml` smoke entry that starts without greeter imports.
- [ ] Record `nix flake check` and Home Manager evaluation evidence in the validation log.

## T2 — Shell foundation

- [ ] Create the `desktop/core`, `desktop/services`, `desktop/surfaces`, and `desktop/adapters/hyprland` boundaries.
- [ ] Move or recreate generic design tokens without a greeter import.
- [ ] Implement generated-settings loading and feature toggles.
- [ ] Implement OverlayController ownership, focus handoff, `Escape`, and background-close behavior.
- [ ] Implement per-output window creation and output-removal cleanup.

## T3 — Hyprland ambient bar

- [ ] Implement reactive Hyprland workspace and focused-window adapter state.
- [ ] Implement per-output ambient bar layout and unavailable-state handling.
- [ ] Implement audio, network, battery, time, and ambient MPRIS indicators.
- [ ] Preserve wheel volume adjustment with safe bounds and mute behavior.
- [ ] Remove desktop dependency on the prototype CPU/RAM polling loops.

## T4 — Command Deck

- [ ] Implement shared action registry and launch contract.
- [ ] Load/search desktop applications and built-in actions with specified ranking/grouping.
- [ ] Implement keyboard focus, arrows, Enter, Escape, and equivalent mouse behavior.
- [ ] Route destructive session results to confirmation instead of direct execution.

## T5 — System Rail and OSDs

- [ ] Implement right-rail routing for system controls and Event Log.
- [ ] Implement PipeWire output/mic controls and compact volume OSD.
- [ ] Implement brightness adapter/control/OSD with unavailable fallback.
- [ ] Implement NetworkManager status/network selection without storing secrets.
- [ ] Implement battery and power-profile state with unavailable fallback.
- [ ] Implement lock and confirmed logout/reboot/power-off actions.

## T6 — Notifications and Event Log

- [ ] Claim/configure native notification ownership only when the feature is enabled.
- [ ] Implement urgency-aware non-blocking toasts.
- [ ] Implement session-local Event Log, dismiss-one, clear-all, and do-not-disturb.
- [ ] Verify no duplicate notification daemon owns the session bus name.

## T7–T8 — Release readiness

- [ ] Package the preserved greeter only behind its opt-in feature.
- [ ] Update user-facing README/install guidance after the Nix path is proven.
- [ ] Exercise all manual acceptance scenarios in the validation strategy.
- [ ] Record known limitations and deferred features for the first usable release.
