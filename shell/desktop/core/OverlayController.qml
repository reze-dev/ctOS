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
        EventLog
    }

    // Primary Overlay State Enum
    enum Surface {
        None,
        CommandDeck,
        SystemRail,
        EventLog
    }

    property var _focusTargets: ({})

    // Internal State
    property int _previousSurface: OverlayController.Surface.None
    readonly property int activeOverlay: activeSurface

    // Public State Properties
    property int activeSurface: OverlayController.Surface.None
    readonly property bool isOverlayActive: activeSurface !== OverlayController.Surface.None
    readonly property int surfaceCommandDeck: 1
    readonly property int surfaceEventLog: 3

    // Explicit constants for zero-ambiguity access
    readonly property int surfaceNone: 0
    readonly property int surfaceSystemRail: 2

    signal focusReleased
    signal focusRequested(int activeSurface)

    // Public Signals
    signal overlayChanged(int activeSurface)
    signal overlayClosed(int previousSurface)
    signal overlayOpened(int activeSurface)

    // Internal Transition Logic

    function _isValidSurface(surface: int): bool {
        if (surface < 0 || surface > OverlayController.Surface.EventLog) {
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
    function openEventLog(): void {
        _setSurface(OverlayController.Surface.EventLog);
    }
    function openSystemRail(): void {
        _setSurface(OverlayController.Surface.SystemRail);
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
    function toggleEventLog(): void {
        toggle(OverlayController.Surface.EventLog);
    }
    function toggleSystemRail(): void {
        toggle(OverlayController.Surface.SystemRail);
    }
    function unregisterFocusTarget(surface: int): void {
        delete _focusTargets[surface];
    }

    // Declarative Dismissal Bindings:
    // Escape key shortcut dismisses active primary overlay cleanly.
    Shortcut {
        enabled: root.isOverlayActive
        sequence: "Escape"

        onActivated: root.close()
    }
}
