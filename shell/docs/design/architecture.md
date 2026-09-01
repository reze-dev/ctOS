# ctOS v1 architecture

## Runtime shape

The current `bar.qml` prototype is replaced by a desktop `shell.qml` scope. The existing greeter remains a separate entry point and security boundary. They may share palette, typography, and primitive visual components, but desktop code must not depend on greeter authentication or state code.

```text
shell.qml
  ├─ ShellState / OverlayController
  ├─ service adapters
  ├─ per-output AmbientBar windows
  ├─ one CommandDeck surface
  ├─ one SystemRail/EventLog surface
  └─ non-focus-stealing OSD and notification surfaces
```

`OverlayController` is the sole owner of primary-overlay state. Its public operations are `openCommandDeck`, `openSystemRail`, `openEventLog`, and `close`. Opening one primary surface replaces the prior one. OSDs and toasts are independent transient layers.

## Module boundaries

| Boundary | Responsibility |
| --- | --- |
| `common` | Design tokens, reusable frame/input/list primitives, configuration loading, logging, and no desktop-specific policy. |
| `desktop/core` | Shell lifecycle, overlay state, settings, screen selection, keyboard focus, and action registry. |
| `desktop/services` | Normalized read/write state for compositor, audio, network, power, notifications, brightness, and MPRIS. |
| `desktop/surfaces` | Bars, panels, OSDs, and toasts; renders state but does not invoke shell commands directly. |
| `desktop/adapters/hyprland` | Hyprland-specific workspace/focused-window/session behavior behind compositor-neutral service interfaces. |
| `greeter` | Existing greetd/lockd modes and PAM/authentication behavior. |

No UI surface polls shell commands itself. If a backend requires a command-line bridge, its adapter owns lifecycle, parsing, debouncing, error state, and cleanup. UI receives reactive values and named actions only.

## Services and degraded behavior

Services expose `available`, `status`, state values, and named actions. An unavailable optional service never prevents shell startup.

| Service | V1 source | Degraded behavior |
| --- | --- | --- |
| Compositor | Quickshell Hyprland integration | Shell starts; workspace/focused-window widgets hide or show unavailable state. |
| Audio | PipeWire | Audio controls hide; no OSD value is fabricated. |
| Network | NetworkManager | Network segment reports unavailable; System Rail omits network controls. |
| Battery | UPower | Battery segment/control is omitted on desktops or unavailable systems. |
| Brightness | configured brightness backend | Brightness control and OSD are omitted. |
| Power profiles | power-profiles backend | Power profile section is omitted. |
| Notifications | Quickshell notification integration | Feature is disabled with a clear startup diagnostic. |
| MPRIS | Quickshell or a dedicated adapter | Ambient media marker is omitted. |

The action registry gives Command Deck and clickable controls the same action definitions. Session actions use a confirmation state in the UI; adapters only execute a confirmed request.

## Configuration and multi-monitor behavior

Runtime settings are supplied declaratively by the Home Manager module. QML receives a generated, user-readable settings file rather than embedding machine-specific values. Settings cover enabled features, theme/wallpaper selection, reduced motion, and keybinding integration.

Each output receives an ambient bar. Full-screen panels use the focused output at opening time. If the output disappears, the panel closes and focus returns to the remaining desktop; no stale screen reference may keep the shell alive. The shell reload path must preserve no authentication state and may safely restart desktop surfaces.

## Security and reliability constraints

- ctOS does not collect, persist, or log Wi-Fi secrets, notification body data beyond in-memory/current-session history, or authentication credentials.
- Notification history is session-local in v1.
- The desktop shell must not run privileged operations. NixOS services own system privilege boundaries.
- Greeter and lockscreen remain independently launched and retain their current PAM/greetd/lockd security model.
- A failed optional integration is logged once with actionable diagnostics; repeated retries must be bounded.
