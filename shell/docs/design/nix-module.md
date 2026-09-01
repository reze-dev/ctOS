# ctOS Nix integration design

## Packaging decision

ctOS is delivered as a flake organized with `flake-parts`. The flake exports a Quickshell package and `homeManagerModules.default`. `flake-parts` is internal flake organization, not a runtime plugin system.

The Home Manager module is the primary public interface because ctOS is a user-session application: it owns Quickshell startup, user configuration, wallpapers/assets, and optional Hyprland bindings. A system-wide NixOS module is deferred. NixOS services such as PipeWire, NetworkManager, UPower, and power-profiles-daemon remain configuration responsibilities of the northstar host and are documented prerequisites.

## Public configuration contract

The module namespace is `programs.ctOS`.

| Option | Default | Meaning |
| --- | --- | --- |
| `enable` | `false` | Installs and starts the desktop shell. |
| `compositor` | `"hyprland"` | V1 accepts only Hyprland. |
| `theme` | `"ctos-dark"` | Selects the bundled fixed theme. |
| `wallpaper` | bundled wallpaper | Path or bundled wallpaper selection used by generated runtime settings. |
| `animation.reducedMotion` | `false` | Removes decorative panel and OSD effects. |
| `features.commandDeck` | `true` | Enables Command Deck. |
| `features.systemRail` | `true` | Enables System Rail and OSDs. |
| `features.notifications` | `true` | Starts ctOS as the notification server. |
| `features.greeter` | `false` | Packages/configures the preserved greeter integration when explicitly enabled. |
| `keybinds.enable` | `true` | Adds ctOS’s documented Hyprland bindings. |
| `keybinds.overrides` | `{}` | Replaces default binding strings by named action. |

When bindings are enabled, defaults are `Super` for Command Deck, `Super+Space` for System Rail, `Super+N` for Event Log, and `Super+L` for lock. The module documents conflict resolution and offers disabling generated bindings; it does not silently overwrite user-owned Hyprland settings.

## Activation behavior

Enabling ctOS:

1. Installs the packaged QML/assets and required user-side tools.
2. Generates runtime settings from `programs.ctOS` options.
3. Creates a systemd user service that starts the ctOS Quickshell entry point after the graphical session is ready and restarts on unexpected exit with bounded backoff.
4. Adds optional Hyprland binding fragments when requested.
5. Emits activation warnings for likely conflicts, including another enabled notification daemon.

The module does not enable privileged system services, edit `/etc`, replace a display manager, or assume a particular hostname. Greeter enablement is opt-in because it involves display-manager/session configuration outside ordinary Home Manager ownership.

## Prerequisites and validation

Expected host capabilities are Hyprland, Quickshell, PipeWire, NetworkManager, UPower, a brightness backend for brightness controls, and a power-profile backend for power-profile controls. ctOS degrades gracefully when an optional service is missing; the documentation lists the corresponding unavailable feature.

Validation for the packaging milestone:

- `nix flake check` evaluates all exported packages and modules.
- A Home Manager evaluation with `programs.ctOS.enable = true` produces a user service and generated settings without requiring host-specific paths.
- A NixOS Hyprland test profile starts the service, opens each documented overlay, and verifies configuration overrides.
- Notification testing verifies that only one notification server owns the session bus name.
