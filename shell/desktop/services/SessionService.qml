pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // =========================================================================
    // Compositor Detection (Requirements R2, R3)
    // =========================================================================
    readonly property string currentDesktop: (Quickshell.env("XDG_CURRENT_DESKTOP") || "").toLowerCase()
    readonly property bool isNiri: currentDesktop.includes("niri") || Boolean(Quickshell.env("NIRI_SOCKET"))
    readonly property bool isHyprland: currentDesktop.includes("hyprland") || Boolean(Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE"))
    readonly property string compositorName: isNiri ? "niri" : (isHyprland ? "hyprland" : "unknown")

    readonly property var logoutCommand: isNiri ? ["niri", "msg", "action", "quit"] : ["hyprctl", "dispatch", "exit"]

    // =========================================================================
    // Reactive Process States
    // =========================================================================
    readonly property bool isLocking: lockProcess.running
    readonly property bool isLoggingOut: logoutProcess.running
    readonly property bool isRebooting: rebootProcess.running
    readonly property bool isPoweringOff: poweroffProcess.running
    readonly property bool isBusy: isLocking || isLoggingOut || isRebooting || isPoweringOff

    // =========================================================================
    // Signals
    // =========================================================================
    signal sessionActionTriggered(string action)
    signal sessionActionFinished(string action, int exitCode)

    // =========================================================================
    // Persistent Subprocesses
    // =========================================================================
    Process {
        id: lockProcess
        command: ["loginctl", "lock-session"]
        running: false

        onExited: function(exitCode) {
            root.sessionActionFinished("lock", exitCode);
        }
    }

    Process {
        id: logoutProcess
        command: root.logoutCommand
        running: false

        onExited: function(exitCode) {
            root.sessionActionFinished("logout", exitCode);
        }
    }

    Process {
        id: rebootProcess
        command: ["systemctl", "reboot"]
        running: false

        onExited: function(exitCode) {
            root.sessionActionFinished("reboot", exitCode);
        }
    }

    Process {
        id: poweroffProcess
        command: ["systemctl", "poweroff"]
        running: false

        onExited: function(exitCode) {
            root.sessionActionFinished("poweroff", exitCode);
        }
    }

    // =========================================================================
    // Public Action Invocations
    // =========================================================================
    function lock(): void {
        root.sessionActionTriggered("lock");
        if (!lockProcess.running) {
            lockProcess.running = true;
        }
    }

    function logout(): void {
        root.sessionActionTriggered("logout");
        if (!logoutProcess.running) {
            logoutProcess.running = true;
        }
    }

    function reboot(): void {
        root.sessionActionTriggered("reboot");
        if (!rebootProcess.running) {
            rebootProcess.running = true;
        }
    }

    function poweroff(): void {
        root.sessionActionTriggered("poweroff");
        if (!poweroffProcess.running) {
            poweroffProcess.running = true;
        }
    }

    function executeAction(action: string): void {
        if (action === "lock") {
            root.lock();
        } else if (action === "logout") {
            root.logout();
        } else if (action === "reboot") {
            root.reboot();
        } else if (action === "poweroff") {
            root.poweroff();
        } else {
            console.warn("[SessionService] Rejected unknown or invalid session action: " + action);
        }
    }
}
