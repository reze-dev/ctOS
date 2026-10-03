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

    // Niri's real workspace ids, from `niri msg -j workspaces`.
    property var _niriWorkspaceIds: []
    property string _niriJsonBuffer: ""

    function _applyNiriWorkspaces(text) {
        let parsed;
        try {
            parsed = JSON.parse(text);
        } catch (e) {
            // A partial read, or niri not up yet. The next poll replaces it.
            return false;
        }

        if (!Array.isArray(parsed) || parsed.length === 0) {
            return true;
        }

        const ids = [];
        let focused = -1;

        for (let i = 0; i < parsed.length; ++i) {
            const ws = parsed[i];
            if (!ws) {
                continue;
            }
            if (typeof ws.id === "number") {
                ids.push(ws.id);
            }
            if (ws.is_focused === true) {
                focused = ws.id;
            }
        }

        if (ids.length > 0) {
            ids.sort(function (a, b) { return a - b; });
            root._niriWorkspaceIds = ids;
        }

        // Only trust the shell's own optimistic update once niri has told us
        // something different. Without this the notch kept showing the workspace
        // last clicked in the notch, and ignored every switch made with a
        // keybinding or a gesture.
        if (focused > 0 && focused !== root._localFocusedWorkspaceId) {
            root._localFocusedWorkspaceId = focused;
            root.workspaceChanged(focused);
        }

        return true;
    }

    // Focused workspace ID (defaults to 1 if available, or -1 when unavailable)
    readonly property int focusedWorkspaceId: {
        if (root._adapter && root._adapter.available && !root.isNiri) {
            if (root._adapter.focusedWorkspaceId !== undefined && root._adapter.focusedWorkspaceId > 0) {
                return root._adapter.focusedWorkspaceId;
            }
        }
        return root._localFocusedWorkspaceId;
    }

    // Reactive list of workspace objects or IDs
    //
    // Under Niri this used to be a hardcoded [1,2,3,4,5], which is a guess: niri
    // creates workspaces on demand and their ids are not contiguous, so the
    // notch drew five pills for a session that had two. The real list comes from
    // `niri msg -j workspaces` below, with the fixed list only as a fallback for
    // before the first poll lands.
    readonly property var workspaces: {
        if (root.isNiri && root._niriWorkspaceIds.length > 0) {
            return root._niriWorkspaceIds;
        }
        if (root._adapter && root._adapter.available && !root.isNiri) {
            const list = root._adapter.workspaces;
            if (list && list.length > 0) {
                return list;
            }
        }
        return [1, 2, 3, 4, 5];
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

    // Niri has no D-Bus or socket the shell can subscribe to for workspace
    // changes, so the state is polled. Cheap: one `niri msg -j workspaces` per
    // second, and only while niri is the compositor.
    Process {
        id: niriWorkspacePoll
        command: ["niri", "msg", "-j", "workspaces"]
        running: false

        // niri emits compact JSON on a single line, so one chunk is normally the
        // whole document. Parsed opportunistically: a partial read fails to parse
        // and the buffer keeps filling, and the poll clears it either way.
        //
        // No stream-finished signal to hang this off -- SplitParser in
        // Quickshell 0.3.1 only has onRead, and assigning onStreamFinished fails
        // the whole load with "Cannot assign to non-existent property", which
        // takes every service that imports this one down with it.
        stdout: SplitParser {
            onRead: data => {
                root._niriJsonBuffer += data;
                if (root._applyNiriWorkspaces(root._niriJsonBuffer)) {
                    root._niriJsonBuffer = "";
                }
            }
        }
    }

    Timer {
        interval: 1000
        repeat: true
        running: root.isNiri
        triggeredOnStart: true

        onTriggered: {
            if (!niriWorkspacePoll.running) {
                root._niriJsonBuffer = "";
                niriWorkspacePoll.running = true;
            }
        }
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
            niriFocusProcess.running = false;
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
