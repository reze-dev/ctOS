# ctOS shell — architecture

Visual and behavioural target lives in [`../target/`](../target/README.md). This
document covers only the structural rules that target cannot express.

## Runtime shape

`shell.qml` is a Quickshell `Scope` that owns **every** `PanelWindow` in the
desktop shell. Surfaces are `Item`s hosted by it; only `AmbientBar` is itself a
`PanelWindow`, because it is instantiated per output via `Variants`.

```
shell.qml  (Scope)
├─ IpcHandler { target: "ctos" }        external control surface
├─ per-output AmbientBar   × N           the notch and, when open, the CCC
├─ per-output telemetry windows × N      optional desktop widgets
└─ host windows                           overlay, toasts, packet analyzer
```

The CCC is **not** a separate host window. See below.

## Single-surface hosting

The target requires that the CCC read as the notch unfolding — same border, same
glow, no seam. Two independently positioned layer-shell surfaces cannot do this:
the compositor separates them and no border can wrap continuously across the join.

Therefore the CCC is a child of `AmbientBar`, positioned directly beneath the
notch pill, and `AmbientBar`'s window grows downward to contain it. Consequences
that must be respected:

- `AmbientBar` must stay `ExclusionMode.Ignore` and must never grow its
  exclusive zone.
- The input region must be recomputed whenever the notch or CCC changes size.
  `flushWaylandMask()` (`AmbientBar.qml`) exists for exactly this and must be
  extended to cover the CCC bounds, not just the pill.
- `AmbientBar` is per-output, so the CCC is per-output. That is correct — the CCC
  belongs on the output that was focused when it opened.
- Anything that must sit *above* the CCC (toasts) keeps its own host window on a
  higher layer.

## Module boundaries

| Boundary | Responsibility |
| --- | --- |
| `desktop/core` | Shell lifecycle, overlay state, settings, design tokens, action registry. |
| `desktop/services` | Normalised read/write state. Exposes `available` plus named actions. |
| `desktop/surfaces` | Rendering only. Never spawns a process. |
| `desktop/adapters/hyprland` | Hyprland specifics behind compositor-neutral service interfaces. |
| `greeter` | Separate entry point and security boundary. Desktop code must never import it. |

**The rule that keeps breaking:** no surface may spawn a process. `CommandCenter`
currently violates this for session actions; that is being removed. Command-line
bridges belong in `desktop/adapters/`, not in services and never in surfaces.

## Overlay ownership

`OverlayController` is the sole owner of primary-overlay state. Nothing outside
it may write `activeSurface`, and it should be made `readonly` with a private
setter to enforce that. Popup state for calendar, Bluetooth and network is held
in `shell.qml` and is mutually exclusive with the primary overlay.

Screens that disappear must close whatever was hosted on them. `onScreensChanged`
in `shell.qml` implements this; the same check must cover the per-output CCC.

## Service contract

Every service exposes `available` and a set of named actions, and every read
property is guarded so a missing backend yields a defined value rather than
`undefined` or a fabricated one. A service that is unavailable must not prevent
startup, and it must not be retried without bound.

`available` must be a real probe of the backend, not a copy of a user setting and
not a hardcoded `true`. Optional services should log once on degrade.

Command-line-backed services must capture `stderr` and handle `exited`, so a
failed integration is observable rather than silent.

## Configuration

Runtime settings are read from `~/.config/ctos/settings.json` by `Settings.qml`,
overridable via `CTOS_SETTINGS_PATH`. The Home Manager module should generate
this file; today it does not, so the file is hand-maintained.

`Theme.qml` is the only source of colour. New colours become tokens. The navy
ramp and neon palette are defined in [`../target/colors.md`](../target/colors.md).

## Scaling

`Theme` currently has no scale factor and the shell contains roughly 2,400
absolute `Theme.*` references plus hundreds of literal pixel values. Nothing is
DPI-aware. A scale token is required before the CCC's larger geometry is tuned;
see the target spec's implementation order.

## Security and reliability

- The shell runs unprivileged. Privileged operations belong to NixOS services.
- Wi-Fi secrets are never logged or persisted, and must not be passed as process
  arguments where they become visible in `/proc`.
- Notification history is session-local.
- The greeter retains its own PAM/greetd model and is launched independently.
