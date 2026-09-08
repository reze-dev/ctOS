pragma Singleton

import QtQuick
import Quickshell
import "../adapters/hyprland"

Singleton {
    id: root

    // =========================================================================
    // Underlying Adapter Reference
    // =========================================================================

    // Routes to compositor adapter according to runtime Settings.
    // In v1, Hyprland is the sole supported compositor (TD-003).
    readonly property var _adapter: HyprlandAdapter

    // =========================================================================
    // Public Reactive Properties (Neutral Contract)
    // =========================================================================

    // Availability indicator: true when backend compositor IPC is connected
    readonly property bool available: Boolean(root._adapter && root._adapter.available)

    // Reactive list of workspace objects: [{ id: int, name: string, active: bool, focused: bool, urgent: bool }]
    readonly property list<var> workspaces: (root._adapter && root._adapter.workspaces) ? root._adapter.workspaces : []

    // Focused workspace ID (defaults to 1 if available, or -1 when unavailable)
    readonly property int focusedWorkspaceId: (root._adapter && root._adapter.focusedWorkspaceId !== undefined) ? root._adapter.focusedWorkspaceId : -1

    // Address handle of the currently focused window ("" when none focused)
    readonly property string activeWindowAddress: (root._adapter && root._adapter.activeWindowAddress) ? root._adapter.activeWindowAddress : ""

    // Title of the currently focused window ("" when none focused; sanitized single-line)
    readonly property string activeWindowTitle: (root._adapter && root._adapter.activeWindowTitle) ? root._adapter.activeWindowTitle : ""

    // Application class / appId of the currently focused window ("" when none focused)
    readonly property string activeWindowClass: (root._adapter && root._adapter.activeWindowClass) ? root._adapter.activeWindowClass : ""

    // =========================================================================
    // Public Signals
    // =========================================================================

    signal activeWindowChanged(string address, string title, string appClass)
    signal compositorAvailabilityChanged(bool available)
    signal workspaceChanged(int workspaceId)

    // =========================================================================
    // Public Methods
    // =========================================================================

    // Dispatch workspace switch request to the active compositor adapter
    function switchToWorkspace(id: int): void {
        if (!root.available) {
            console.warn("[CompositorService] Cannot switch workspace: compositor unavailable");
            return;
        }
        if (id <= 0 || !Number.isInteger(id)) {
            console.warn("[CompositorService] Invalid workspace ID: " + id + " (must be > 0)");
            return;
        }
        if (root._adapter && typeof root._adapter.switchToWorkspace === "function") {
            root._adapter.switchToWorkspace(id);
        }
    }

    // =========================================================================
    // Reactive Event Forwarding
    // =========================================================================

    Connections {
        target: root._adapter

        function onActiveWindowChanged(address, title, appClass) {
            root.activeWindowChanged(address, title, appClass);
        }
        function onCompositorAvailabilityChanged(available) {
            root.compositorAvailabilityChanged(available);
        }
        function onWorkspaceChanged(workspaceId) {
            root.workspaceChanged(workspaceId);
        }
    }
}
