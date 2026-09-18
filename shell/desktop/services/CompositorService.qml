pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "../adapters/hyprland"

Singleton {
    id: root

    // =========================================================================
    // Compositor Detection (Requirements R2, R3)
    // =========================================================================

    readonly property string currentDesktop: (Quickshell.env("XDG_CURRENT_DESKTOP") || "").toLowerCase()
    readonly property bool isNiri: currentDesktop.includes("niri") || Boolean(Quickshell.env("NIRI_SOCKET"))
    readonly property bool isHyprland: currentDesktop.includes("hyprland") || Boolean(Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE"))

    // =========================================================================
    // Underlying Adapter Reference
    // =========================================================================

    // Routes to compositor adapter according to runtime Settings.
    readonly property var _adapter: HyprlandAdapter

    // =========================================================================
    // Public Reactive Properties (Neutral Contract)
    // =========================================================================

    // Availability indicator: true when backend compositor IPC is connected
    readonly property bool available: Boolean((root._adapter && root._adapter.available) || root.isNiri)

    // Internal focused workspace tracking for fallback and Niri operation
    property int _localFocusedWorkspaceId: 1

    // Focused workspace ID (defaults to 1 if available, or -1 when unavailable)
    readonly property int focusedWorkspaceId: {
        if (root._adapter && root._adapter.available && !root.isNiri) {
            if (root._adapter.focusedWorkspaceId !== undefined && root._adapter.focusedWorkspaceId > 0) {
                return root._adapter.focusedWorkspaceId;
            }
        }
        return root._localFocusedWorkspaceId;
    }

    // Reactive list of workspace objects: [{ id: int, name: string, active: bool, focused: bool, urgent: bool }]
    // When _adapter is unavailable or when running under Niri, provides a deterministic list of 5 workspaces (ids 1..5)
    readonly property list<var> workspaces: {
        if (root._adapter && root._adapter.available && !root.isNiri) {
            const list = root._adapter.workspaces;
            if (list && list.length > 0) {
                return list;
            }
        }
        const focusedId = root.focusedWorkspaceId > 0 ? root.focusedWorkspaceId : 1;
        return [
            { id: 1, name: "1", active: (focusedId === 1), focused: (focusedId === 1), urgent: false },
            { id: 2, name: "2", active: (focusedId === 2), focused: (focusedId === 2), urgent: false },
            { id: 3, name: "3", active: (focusedId === 3), focused: (focusedId === 3), urgent: false },
            { id: 4, name: "4", active: (focusedId === 4), focused: (focusedId === 4), urgent: false },
            { id: 5, name: "5", active: (focusedId === 5), focused: (focusedId === 5), urgent: false }
        ];
    }

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
    // Declarative Subprocesses (Niri IPC)
    // =========================================================================

    Process {
        id: niriFocusProcess
        command: ["niri", "msg", "action", "focus-workspace", "1"]
        running: false
    }

    // =========================================================================
    // Public Methods
    // =========================================================================

    // Dispatch workspace switch request to the active compositor adapter
    function switchToWorkspace(id: int): void {
        if (id <= 0 || !Number.isInteger(id)) {
            console.warn("[CompositorService] Invalid workspace ID: " + id + " (must be > 0)");
            return;
        }

        if (root._adapter && root._adapter.available && !root.isNiri) {
            if (typeof root._adapter.switchToWorkspace === "function") {
                root._adapter.switchToWorkspace(id);
            }
        } else if (root.isNiri) {
            niriFocusProcess.command = ["niri", "msg", "action", "focus-workspace", String(id)];
            niriFocusProcess.running = true;
            root._localFocusedWorkspaceId = id;
            root.workspaceChanged(id);
        } else {
            root._localFocusedWorkspaceId = id;
            root.workspaceChanged(id);
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
            root.compositorAvailabilityChanged(root.available);
        }
        function onWorkspaceChanged(workspaceId) {
            if (!root.isNiri) {
                root._localFocusedWorkspaceId = workspaceId;
                root.workspaceChanged(workspaceId);
            }
        }
    }
}
