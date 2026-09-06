pragma Singleton

import QtQuick
import QtQml
import Quickshell
import Quickshell.Hyprland

Singleton {
    id: root

    // =========================================================================
    // IPC Availability State
    // =========================================================================

    // True when running inside an active Hyprland session and IPC request socket is connected
    readonly property bool available: {
        const sig = Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE");
        return Boolean(sig && sig.length > 0 && Hyprland.requestSocketPath && Hyprland.requestSocketPath.length > 0);
    }

    // =========================================================================
    // Public Reactive Properties
    // =========================================================================

    // Address handle of the currently focused window ("" when none focused)
    readonly property string activeWindowAddress: {
        if (!root.available || !Hyprland.activeToplevel) {
            return "";
        }
        return Hyprland.activeToplevel.address || "";
    }

    // Class / appId of the currently focused window ("" when none focused; calm fallback)
    readonly property string activeWindowClass: {
        if (!root.available || !Hyprland.activeToplevel) {
            return "";
        }
        const toplevel = Hyprland.activeToplevel;
        const lastIpc = toplevel.lastIpcObject;
        if (lastIpc && lastIpc.class) {
            return String(lastIpc.class).trim();
        }
        return "";
    }

    // Title of the currently focused window ("" when none focused; calm fallback, sanitized)
    readonly property string activeWindowTitle: {
        if (!root.available || !Hyprland.activeToplevel) {
            return "";
        }
        const toplevel = Hyprland.activeToplevel;
        const rawTitle = toplevel.title || (toplevel.lastIpcObject && toplevel.lastIpcObject.title ? toplevel.lastIpcObject.title : "");
        return root.sanitizeTitle(rawTitle);
    }

    // Focused workspace ID (defaults to active focused workspace, or 1 if empty, or -1 if unavailable)
    readonly property int focusedWorkspaceId: {
        if (!root.available) {
            return -1;
        }
        if (Hyprland.focusedWorkspace && Hyprland.focusedWorkspace.id > 0) {
            return Hyprland.focusedWorkspace.id;
        }
        return 1;
    }

    // Reactive list of normalized workspace objects:
    // [{ id: int, name: string, active: bool, focused: bool, urgent: bool }]
    // Safely handles empty workspaces list and disconnected state without crashing.
    readonly property list<var> workspaces: {
        if (!root.available || !Hyprland.workspaces || !Hyprland.workspaces.values) {
            return [];
        }
        const rawList = Hyprland.workspaces.values;
        if (!rawList || rawList.length === 0) {
            return [];
        }

        const result = [];
        for (let i = 0; i < rawList.length; ++i) {
            const ws = rawList[i];
            if (ws && ws.id > 0) {
                result.push({
                    "id": ws.id,
                    "name": ws.name ? ws.name : String(ws.id),
                    "active": Boolean(ws.active),
                    "focused": Boolean(ws.focused || (ws.id === root.focusedWorkspaceId)),
                    "urgent": Boolean(ws.urgent)
                });
            }
        }

        // Sort by ID ascending for stable, deterministic ordering
        result.sort((a, b) => a.id - b.id);
        return result;
    }

    // =========================================================================
    // Public Signals
    // =========================================================================

    signal activeWindowChanged(string address, string title, string appClass)
    signal compositorAvailabilityChanged(bool available)
    signal workspaceChanged(int workspaceId)

    // =========================================================================
    // Dispatch & Navigation Methods
    // =========================================================================

    // Dispatch workspace switch to Hyprland.
    // Rejects negative or non-integer workspace IDs safely (T2.05.2).
    // Dispatches arbitrary positive IDs safely without UI crash (T2.05.3).
    function switchToWorkspace(id: int): void {
        if (!root.available) {
            console.warn("[HyprlandAdapter] Cannot switch workspace: Hyprland IPC is unavailable");
            return;
        }

        // Guard against non-positive workspace IDs
        if (id <= 0 || !Number.isInteger(id)) {
            console.warn("[HyprlandAdapter] Invalid workspace ID: " + id + "; workspace id must be > 0");
            return;
        }

        // Dispatch Hyprland compositor command via native IPC
        Hyprland.dispatch("workspace " + id);
    }

    // =========================================================================
    // Multi-Monitor Support Helpers
    // =========================================================================

    // Resolve HyprlandMonitor for a given QuickshellScreenInfo
    function monitorFor(screen: var): var {
        if (!root.available || !screen) {
            return null;
        }
        return Hyprland.monitorFor(screen);
    }

    // Filter workspaces belonging to a specific monitor name
    function workspacesForMonitor(monitorName: string): list<var> {
        if (!root.available || !monitorName || root.workspaces.length === 0) {
            return root.workspaces;
        }

        const filtered = [];
        const rawList = Hyprland.workspaces ? Hyprland.workspaces.values : [];
        for (let i = 0; i < rawList.length; ++i) {
            const ws = rawList[i];
            if (ws && ws.monitor && ws.monitor.name === monitorName && ws.id > 0) {
                filtered.push({
                    "id": ws.id,
                    "name": ws.name ? ws.name : String(ws.id),
                    "active": Boolean(ws.active),
                    "focused": Boolean(ws.focused || (ws.id === root.focusedWorkspaceId)),
                    "urgent": Boolean(ws.urgent)
                });
            }
        }
        filtered.sort((a, b) => a.id - b.id);
        return filtered.length > 0 ? filtered : root.workspaces;
    }

    // =========================================================================
    // Text Sanitization & Safety Helpers
    // =========================================================================

    // Sanitizes window title: removes newlines, control characters, and limits length.
    // UI consumers (WindowTitleWidget) apply layout elision:
    // elide: Text.ElideRight, maximumLineCount: 1, clip: true, wrapMode: Text.NoWrap
    function sanitizeTitle(rawText: string): string {
        if (!rawText || rawText.length === 0) {
            return "";
        }
        // Replace newlines/tabs with space and strip non-printable ASCII control characters
        let clean = rawText.replace(/[\r\n\t]+/g, " ").replace(/[\x00-\x1F\x7F]/g, "").trim();
        if (clean.length > 512) {
            clean = clean.substring(0, 512);
        }
        return clean;
    }

    // =========================================================================
    // Reactive Event Connections
    // =========================================================================

    Connections {
        target: Hyprland

        function onActiveToplevelChanged(): void {
            root.activeWindowChanged(root.activeWindowAddress, root.activeWindowTitle, root.activeWindowClass);
        }
        function onFocusedWorkspaceChanged(): void {
            if (root.focusedWorkspaceId > 0) {
                root.workspaceChanged(root.focusedWorkspaceId);
            }
        }
        function onRawEvent(event: var): void {
            if (!event || !event.name) {
                return;
            }
            const ev = event.name;
            if (ev === "activewindow" || ev === "activewindowv2") {
                root.activeWindowChanged(root.activeWindowAddress, root.activeWindowTitle, root.activeWindowClass);
            } else if (ev === "workspace" || ev === "focusedmon") {
                if (root.focusedWorkspaceId > 0) {
                    root.workspaceChanged(root.focusedWorkspaceId);
                }
            }
        }
    }
}
