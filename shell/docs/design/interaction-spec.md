# ctOS v1 interaction specification

## Global behavior

ctOS has one primary overlay at a time. Opening the Command Deck, System Rail, or Event Log closes another primary overlay first. A click on the desktop background or `Escape` closes the active overlay. Closing never discards a completed action or notification history.

The bar exists on each active output. Workspace and focused-window data correspond to that output where Hyprland exposes it; otherwise ctOS shows global focused state without fabricating per-monitor data.

Suggested default bindings are part of the Home Manager module and remain overridable:

| Action | Default binding |
| --- | --- |
| Toggle Command Deck | `Super` |
| Toggle System Rail | `Super+Space` |
| Toggle Event Log | `Super+N` |
| Lock session | `Super+L` |

The module must avoid silently replacing a user binding; documented overrides and disabling generated bindings are supported.

## Ambient bar

The bar is a thin, low-contrast per-output panel. It shows:

- workspace state and the focused workspace;
- focused application identity when it adds context;
- compact network, output-volume, battery, and time state;
- an active-media marker when an MPRIS player is playing.

CPU, RAM, expanded network names, and detailed media controls do not remain visible. Clicking an actionable state opens its corresponding utility surface; scroll on the volume indicator adjusts output volume. Missing state is omitted or represented by an unambiguous unavailable indicator, never invented sample data.

## Command Deck

The centered Command Deck opens with focus already in its query field. It is a hybrid command palette:

- normal text searches installed desktop applications;
- built-in actions include opening ctOS surfaces, lock, and session actions;
- arrow keys change selection, `Enter` activates it, and `Escape` closes the deck;
- mouse selection and activation match keyboard behavior;
- results are grouped as Applications and Actions, ordered by exact/prefix match then stable desktop-entry order;
- no files, clipboard records, shell execution, or arbitrary command evaluation occur in v1.

Launching an application or completing an action closes the Deck. Destructive session actions are routed to the System Rail confirmation step rather than executing directly from a search result.

## System Rail and session safety

The right-side System Rail contains output volume/mute, microphone volume/mute, brightness, Wi-Fi state and available networks, battery state, power profile, do-not-disturb, and session actions. It is a focused control surface, not a telemetry dashboard.

- Audio and microphone support click mute and wheel/slider adjustment.
- Brightness supports slider and hardware-key OSD adjustment where a brightness backend exists.
- Wi-Fi shows its connected state and requests a connection only through the configured NetworkManager backend; secrets are never displayed or stored by ctOS.
- Power-profile controls appear only when a power-profile backend is available.
- **Lock** executes immediately.
- **Logout**, **reboot**, and **power off** replace the action list with an explicit in-panel confirmation state. `Escape` or Cancel returns safely; Confirm executes the selected action.

## Notifications, OSDs, and media

ctOS is the sole notification server when its notifications feature is enabled. Incoming notifications create a brief, non-blocking toast and an Event Log record. The Event Log opens in the right rail, supports dismiss-one and clear-all, and visually distinguishes urgency. Do-not-disturb suppresses toasts but retains history.

Volume and brightness changes show compact, short-lived OSDs. OSDs never steal keyboard focus and are suppressed or simplified under reduced motion.

When a player is actively playing, the bar shows an ambient title/player marker. V1 does not provide playback controls or a media panel.
