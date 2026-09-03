# ctOS delivery tracker

**Status key:** `done` = acceptance evidence exists; `active` = current focus; `todo` = not started; `blocked` = external dependency or decision prevents work.

| Milestone | Status | Exit gate |
| --- | --- | --- |
| T0 — Design baseline | done | Product, interaction, architecture, Nix, audit, technical decisions, and validation documents exist. |
| T1 — Nix package and module | done | Flake evaluates; package builds; Home Manager module installs and starts the shell service. |
| T2 — Shell foundation | todo | `shell.qml`, generated settings, design tokens, OverlayController, and per-output window lifecycle work. |
| T3 — Hyprland ambient bar | todo | Reactive workspace/focused-window state and compact system state render on each output without UI-owned polling. |
| T4 — Command Deck | todo | Keyboard/mouse application and action search satisfies the interaction specification. |
| T5 — System Rail and OSDs | todo | Audio, mic, brightness, network, battery/power, and session confirmation work or degrade safely. |
| T6 — Notifications and Event Log | todo | ctOS owns notification delivery, toast behavior, history, and do-not-disturb. |
| T7 — Greeter packaging and documentation | active | Existing greeter is opt-in packageable and docs describe Nix activation/recovery without changing auth behavior. |
| T8 — V1 acceptance | todo | All validation gates pass in the ctos NixOS/Hyprland configuration. |

## T1 — Nix package and module

- [x] Create a flake-parts flake exporting a ctOS package and `homeManagerModules.default`.
- [x] Define the initial `programs.ctOS` option skeleton from the Nix integration design.
- [x] Package QML and resources with a stable `${package}/share/ctos` install path.
- [x] Add a systemd user service for the desktop shell with bounded restart behavior.
- [x] Add a minimal `shell.qml` smoke entry that starts without greeter imports.
- [x] Record successful `nix flake check --no-build` and `nix build .#ctos-shell` evidence in the validation log.
- [x] Add the declarative `awww` daemon and default bundled wallpaper service to the desktop profile.

T1 evidence (2026-09-02): `nix flake check --no-build` passed, `nix build .#ctos-shell` passed, and the built output contains `share/ctos/shell.qml`. Graphical service startup remains a manual acceptance step on the Hyprland host.

T7 progress (2026-09-02): the Makima host now opts into `ctos.features.greeter.enable`; evaluation confirms Greetd launches Cage and the packaged `greeter.qml`, with `/etc/ctos/greeter.config.json` generated declaratively. Live PAM authentication and Hyprland handoff were verified on the host (2026-09-03); recovery/documentation work remains.

Wallpaper progress (2026-09-03): the desktop profile starts `awww-daemon` and applies the bundled `wallpaper-v1.png` through a retrying user service. The initial systemd ordering cycle was fixed and the units now require a live host acceptance check.

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

- [x] Package the preserved greeter only behind its opt-in feature.
- [ ] Update user-facing README/install guidance after the Nix path is proven.
- [ ] Exercise all manual acceptance scenarios in the validation strategy.
- [ ] Record known limitations and deferred features for the first usable release.
