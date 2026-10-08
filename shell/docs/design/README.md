# ctOS design package

Product and structural intent for the desktop shell.

**The visual and behavioural target is [`../target/`](../target/README.md).**
Where these documents and the target disagree, the target is correct.

| Document | Purpose |
| --- | --- |
| [Target specification](../target/README.md) | Authoritative design: images, geometry, colour, behaviour, implementation order. |
| [Vision](vision.md) | Product identity, visual grammar, scope. |
| [Interaction specification](interaction-spec.md) | Input routing, state machines, session safety. |
| [Architecture](architecture.md) | Runtime boundaries, single-surface hosting, service contract. |
| [Nix integration](nix-module.md) | Flake/Home Manager packaging and configuration contract. |

Implementation-facing material lives in the sibling [technical package](../technical/README.md).

## Locked decisions

- ctOS is a personal, NixOS-first Quickshell rice.
- Hyprland is the only supported compositor in v1.
- **The notch is the only top-edge surface.** No tray, no second bar.
- The CCC is the notch unfolding, hosted in the notch's own window — not a
  separate panel or popup.
- The shell ships two palettes, `ctos-pine` (default) and `ctos-dark`, both
  defined as 22 named slots in
  [`../desktop/core/palettes/`](../desktop/core/palettes) and documented in
  [`../target/colors.md`](../target/colors.md). The active palette is a user
  setting, switchable from the radial's appearance panel without a restart.
  Dynamic *wallpaper-derived* theming remains out of scope.
- The greeter and lockscreen are preserved and packaged, not redesigned.
- The primary public integration is a Home Manager module exported from a
  flake-parts-organized flake.

## Known divergences

Tracked so they are not mistaken for oversights:

- `programs.ctOS` exposes only `enable`. The contract in
  [nix-module.md](nix-module.md) is unimplemented, and no module generates
  `settings.json`.
- `Theme.barHeight` (36) and `Settings.barHeight` (32) disagree. Being
  reconciled.
- The shipped keybinding for `Super+Space` opens the Command Deck, not the CCC.
- Brightness and power-profile services described in earlier revisions of the
  architecture document do not exist and are not in scope.
