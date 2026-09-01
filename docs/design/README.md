# ctOS design package

This directory is the source of truth for the ctOS desktop-shell redesign. It describes the intended product before implementation so that feature work can be evaluated against the same decisions.

| Document | Purpose |
| --- | --- |
| [Vision](vision.md) | Product identity, visual grammar, scope, and accessibility rules. |
| [Interaction specification](interaction-spec.md) | Surface behavior, input model, shortcuts, and state transitions. |
| [Architecture](architecture.md) | Runtime boundaries, data flow, services, and failure behavior. |
| [Nix integration](nix-module.md) | Flake/Home Manager packaging and configuration contract. |

Implementation-facing material lives in the sibling [technical package](../technical/README.md).

## Locked v1 decisions

- ctOS is a personal, NixOS-first Quickshell rice.
- Hyprland is the only supported compositor in v1.
- The desktop is minimal by default; ctOS’s rich visual language is reserved for on-demand panels.
- The shell uses a fixed dark ctOS-inspired theme, not dynamic wallpaper theming.
- The current greeter and lockscreen are preserved and packaged, not redesigned.
- The primary public integration is a Home Manager module exported from a flake-parts-organized flake.

Deferred work is intentionally not an implicit v1 commitment: Niri, overview, Bluetooth, file search, clipboard history, calendar, screenshot/recording controls, dynamic theming, and a full media panel.
