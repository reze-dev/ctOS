# Dynamic Island & Command Center Event Log Morph Architecture

## 1. Context & Problem Statement

In ctOS v1, notifications and system events are surfaced through the **Dynamic Island** in the top bar (`AmbientBar`), while the **Event Log** was initially conceived as a separate dropdown popup window below the bar.

When attempting to morph the Dynamic Island by enlarging `DynamicIsland.qml` directly inside `AmbientBar.qml`, two critical Wayland compositor and Layer-Shell issues occurred:

1. **Wayland Layer Conflict & Input Interception (`overlayHost` covers `AmbientBar`)**:
   - `AmbientBar` resides on `WlrLayer.Top` (default for panels).
   - When the Event Log overlay opens, `overlayHost` in `shell.qml` becomes visible on `WlrLayer.Overlay`.
   - In the Wayland Layer-Shell specification, `WlrLayer.Overlay` is strictly **above** `WlrLayer.Top`.
   - The full-screen `scrimBackdrop` MouseArea on `WlrLayer.Overlay` intercepts all pointer clicks below the top bar's 40px exclusive zone. Clicks meant for the expanded Event Log hit the scrim instead and close the surface, making only the top 40px strip clickable.

2. **Per-Frame Wayland Surface Reconfiguration & Mask Thrashing**:
   - Animating `implicitHeight` on `AmbientBar` during the 300ms transition forces Quickshell to send `zwlr_layer_surface_v1.set_size` requests to Hyprland on every animation frame.
   - The compositor must negotiate `configure` events and reallocate/render a full-screen-width surface buffer (1920–3840px wide) 60–144 times per second.
   - Concurrently, `centerSection.widthChanged` and `centerSection.heightChanged` triggers `flushWaylandMask()`, thrashing `wl_region` allocations and destroying frame rates.

---

## 2. Architectural Approaches

### Approach A: The Hybrid Takeover (Selected for Implementation)

#### Core Concept
Keep `AmbientBar` lean, static, and performant at a fixed 40px height on `WlrLayer.Top`. The morphing animation and expanded Command Center are delegated to a dedicated window on **`WlrLayer.Overlay`** (`eventLogPopupHost`), positioned at the exact screen coordinates of the Dynamic Island.

```text
Idle State:
[ Left Sections ] -------- [ Dynamic Island (120x34) ] -------- [ Right Sections ]   (AmbientBar on WlrLayer.Top)

Click / Open EventLog:
1. AmbientBar's Dynamic Island pill is hidden / opacity 0.
2. overlayHost scrim fades in on WlrLayer.Overlay.
3. eventLogPopupHost on WlrLayer.Overlay (anchored top-center, margin-top: 3px)
   begins animation from 120x34 down to 360x500px on the GPU.
4. All contents (Event Log tabs, notifications, controls) are 100% interactive.
```

#### Key Architecture Specifications
- **Window Layer**: `WlrLayershell.layer: WlrLayer.Overlay`, `exclusionMode: ExclusionMode.Ignore`.
- **Fixed Canvas Geometry**: The `PanelWindow` has a static transparent canvas (`width: 360, height: 508`, `anchors { top: true; horizontalCenter: true }`, `margins { top: 3 }`).
- **Zero Wayland Resizing**: The Wayland surface size remains completely static. The visual morphing happens entirely within QML via GPU rendering of the inner `Rectangle` (from 120×34 to 360×500).
- **Zero Mask Thrashing**: No dynamic Wayland `Region` mask updates are required during animation.
- **Full Pointer Interactivity**: Because the window lives on `WlrLayer.Overlay` above the scrim, all buttons, tabs, scrollbars, and cards receive pointer events without interference.

---

### Approach B: 100% Standalone Autonomous Island Window

#### Core Concept
Decouple the Dynamic Island from `AmbientBar` completely. The center of `AmbientBar` remains an empty gap, while the Dynamic Island is instantiated as an independent, floating `PanelWindow` on `WlrLayer.Overlay`.

```text
[ AmbientBar: Left Sections ]              (Empty Gap)              [ AmbientBar: Right Sections ]
                                               │
                                  [ Floating Dynamic Island ]  (Autonomous Window on Overlay)
                                               │
                                 (Morphs down to Command Center)
```

#### Key Architecture Specifications
- **True Floating Island**: Sits above all desktop content, full-screen video, and overlays.
- **Multi-State Live Activities**: Can morph between:
  - `Compact Pill` (120×34): Idle status, unread indicator, DND indicator.
  - `Media Pill` (240×34): Mini player with album art, song title, and animated visualizer bars.
  - `Notification Toast` (320×44): Incoming alert banner.
  - `Command Center HUD` (380×520): Multi-tab control center.
- **Wayland Input Considerations**: Requires managing transparent input boundaries via a single, simple `Region` mask or sizing the window dynamically between distinct discrete states when not transitioning.

---

## 3. Decision & Implementation Plan

**Selected Strategy**: **Approach A (Hybrid Takeover)**

### Step-by-Step Execution Plan:
1. **Restore `AmbientBar.qml`**:
   - Revert `implicitHeight` to static `Theme.barHeight` (40px).
   - Keep `centerSection` (Dynamic Island) compact/notification pill inside the bar.
   - When `OverlayController.activeSurface === OverlayController.Surface.EventLog`, hide or synchronize the bar's Dynamic Island pill.

2. **Refactor `DynamicIsland.qml`**:
   - Keep the clean compact (120×34) and notification (300×34) states inside the bar.
   - On click: call `OverlayController.openEventLog()` to trigger the overlay takeover.

3. **Implement Morphing in `EventLog.qml` / `eventLogPopupHost`**:
   - In `shell.qml`, re-enable `eventLogPopupHost` on `WlrLayer.Overlay`.
   - Anchor `eventLogPopupHost` to `top: true, horizontalCenter: true` with `margins { top: 3 }`.
   - Set fixed transparent canvas (`width: 360, height: 508`).
   - In `EventLog.qml`, animate the root container geometry from `width: 120, height: 34` up to `width: 360, height: 500` upon opening (and down upon closing).
   - Cross-fade header, tabs, and content smoothly as the panel reaches its expanded dimensions.
