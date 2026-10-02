pragma Singleton

import QtQuick
import Quickshell

Singleton {
    id: root

    // Secondary alias enum for semantic clarity / compatibility
    enum OverlayType {
        None,
        CommandDeck,
        SystemRail,
        CommandCenter,
        RadialSettings
    }

    // Primary Overlay State Enum
    enum Surface {
        None,
        CommandDeck,
        SystemRail,
        CommandCenter,
        RadialSettings
    }

    property var _focusTargets: ({})

    // Internal State
    property int _previousSurface: OverlayController.Surface.None
    readonly property int activeOverlay: activeSurface

    // Public State Properties
    property int activeSurface: OverlayController.Surface.None
    readonly property bool isOverlayActive: activeSurface !== OverlayController.Surface.None
    readonly property int surfaceCommandDeck: 1
    readonly property int surfaceSystemRail: 2
    readonly property int surfaceCommandCenter: 3
    readonly property int surfaceRadialSettings: 4

    // Explicit constants for zero-ambiguity access
    readonly property int surfaceNone: 0

    // Output the active overlay belongs to, captured when it opens.
    //
    // Per-output surfaces need this to decide whether they are the host. The CCC
    // used to live in its own PanelWindow in shell.qml which read overlayHost's
    // screen directly; now it is a child of the notch's window, and each output
    // has its own notch, so exactly one of them must claim it.
    property var hostScreen: null

    readonly property string hostScreenName: (hostScreen && hostScreen.name) ? hostScreen.name : ""

    function setHostScreen(screen: var): void {
        root.hostScreen = screen;
    }

    property string pendingSessionAction: ""
    property string pendingRailView: ""
    property alias pendingRailSubmenu: root.pendingRailView

    signal focusReleased
    signal focusRequested(int activeSurface)

    // Public Signals
    signal overlayChanged(int activeSurface)
    signal overlayClosed(int previousSurface)
    signal overlayOpened(int activeSurface)

    // Internal Transition Logic

    function _isValidSurface(surface: int): bool {
        if (surface < 0 || surface > OverlayController.Surface.RadialSettings) {
            return false;
        }
        return true;
    }
    function _setSurface(targetSurface: int): void {
        if (!_isValidSurface(targetSurface)) {
            console.warn("OverlayController: Invalid surface requested: " + targetSurface + ", defaulting to None");
            targetSurface = OverlayController.Surface.None;
        }

        if (activeSurface === targetSurface) {
            if (targetSurface !== OverlayController.Surface.None) {
                // Re-assert focus on already open overlay
                requestFocus(targetSurface);
            }
            return;
        }

        const prior = activeSurface;
        _previousSurface = prior;
        activeSurface = targetSurface;

        if (prior !== OverlayController.Surface.None) {
            overlayClosed(prior);
        }

        if (targetSurface !== OverlayController.Surface.None) {
            overlayOpened(targetSurface);
            requestFocus(targetSurface);
        } else {
            hostScreen = null;
            releaseFocus();
        }

        overlayChanged(targetSurface);
    }
    function close(): void {
        _setSurface(OverlayController.Surface.None);
    }
    function dismiss(): void {
        close();
    }

    // Scrim backdrop and outside-click dismissal support:
    // When an overlay is active, the overlay host scrim / backdrop MouseArea consumes
    // outside clicks and invokes handleBackdropClick() or close(). Clicks inside the
    // overlay panel set propagateComposedEvents or are consumed by panel MouseArea / TapHandler.
    function handleBackdropClick(): bool {
        if (isOverlayActive) {
            close();
            return true;
        }
        return false;
    }

    // Dismissal Contract Handlers:
    // Escape key press and outside scrim click dismiss the active primary overlay.

    function handleEscape(): bool {
        if (isOverlayActive) {
            close();
            return true;
        }
        return false;
    }

    // Public State Manipulation Methods

    function openCommandDeck(): void {
        _setSurface(OverlayController.Surface.CommandDeck);
    }
    
    function openCommandCenter(): void {
        _setSurface(OverlayController.Surface.CommandCenter);
    }
    function openRadialSettings(): void {
        _setSurface(OverlayController.Surface.RadialSettings);
    }
    
    function openSystemRailWithAction(action: string): void {
        pendingSessionAction = action;
        openCommandCenter();
    }
    function openWifiSubmenu(): void {
        pendingRailView = "wifi";
        openCommandCenter();
    }
    function openSystemRailWithSubmenu(submenu: string): void {
        pendingRailView = submenu;
        openCommandCenter();
    }

    // Keyboard Focus Management Contract:
    // Surfaces route activeFocus using focusScope or registerFocusTarget(), which calls forceActiveFocus().
    // When an overlay opens, keyboard focus is routed to the active overlay; on close, releaseFocus() is called.

    function registerFocusTarget(surface: int, targetItem: var): void {
        _focusTargets[surface] = targetItem;
    }
    function releaseFocus(): void {
        focusReleased();
    }
    function requestFocus(surface: int): void {
        const target = _focusTargets[surface];
        if (target && typeof target.forceActiveFocus === "function") {
            target.forceActiveFocus();
        }
        focusRequested(surface);
    }
    function toggle(surface: int): void {
        if (activeSurface === surface) {
            close();
        } else {
            _setSurface(surface);
        }
    }
    function toggleCommandDeck(): void {
        toggle(OverlayController.Surface.CommandDeck);
    }
    
    function toggleCommandCenter(): void {
        toggle(OverlayController.Surface.CommandCenter);
    }
    function toggleRadialSettings(): void {
        toggle(OverlayController.Surface.RadialSettings);
    }
    
    function unregisterFocusTarget(surface: int): void {
        delete _focusTargets[surface];
    }

    // Declarative Dismissal Bindings:
    // Escape key shortcut dismisses active primary overlay cleanly.
    // Declarative Dismissal Bindings:
    // Escape key handling is delegated to the active surfaces via Keys.onEscapePressed.

}
