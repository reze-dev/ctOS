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

    // Base command: ["niri", "msg", "action", "quit"] (-s appended for non-interactive exit)
    readonly property var logoutCommand: isNiri ? ["niri", "msg", "action", "quit", "-s"] : ["hyprctl", "dispatch", "exit"]

    readonly property bool dryRun: Quickshell.env("CTOS_SESSION_DRY_RUN") === "1"

    property int fallbackStage: 0

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
            root.handleLogoutExit(exitCode);
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
        if (root.dryRun) {
            console.log("[SessionService] DRY-RUN: lock requested, skipping host command");
            root.sessionActionFinished("lock", 0);
            return;
        }
        if (!lockProcess.running) {
            lockProcess.running = true;
        }
    }

    function logout(): void {
        root.sessionActionTriggered("logout");
        if (root.dryRun) {
            console.log("[SessionService] DRY-RUN: logout requested, skipping host command");
            root.sessionActionFinished("logout", 0);
            return;
        }
        if (!logoutProcess.running) {
            if (root.compositorName === "unknown") {
                root.fallbackStage = 1;
                logoutProcess.command = ["niri", "msg", "action", "quit", "-s"];
                logoutProcess.running = true;
            } else {
                root.fallbackStage = 0;
                logoutProcess.command = root.logoutCommand;
                logoutProcess.running = true;
            }
        }
    }

    function handleLogoutExit(exitCode: int): void {
        if (root.fallbackStage === 1) {
            if (exitCode === 0) {
                root.fallbackStage = 0;
                logoutProcess.command = root.logoutCommand;
                root.sessionActionFinished("logout", exitCode);
            } else {
                root.fallbackStage = 2;
                logoutProcess.command = ["hyprctl", "dispatch", "exit"];
                logoutProcess.running = true;
            }
        } else if (root.fallbackStage === 2) {
            if (exitCode === 0) {
                root.fallbackStage = 0;
                logoutProcess.command = root.logoutCommand;
                root.sessionActionFinished("logout", exitCode);
            } else {
                root.fallbackStage = 3;
                logoutProcess.command = ["loginctl", "terminate-session", ""];
                logoutProcess.running = true;
            }
        } else if (root.fallbackStage === 3) {
            root.fallbackStage = 0;
            logoutProcess.command = root.logoutCommand;
            root.sessionActionFinished("logout", exitCode);
        } else {
            root.sessionActionFinished("logout", exitCode);
        }
    }

    function reboot(): void {
        root.sessionActionTriggered("reboot");
        if (root.dryRun) {
            console.log("[SessionService] DRY-RUN: reboot requested, skipping host command");
            root.sessionActionFinished("reboot", 0);
            return;
        }
        if (!rebootProcess.running) {
            rebootProcess.running = true;
        }
    }

    function poweroff(): void {
        root.sessionActionTriggered("poweroff");
        if (root.dryRun) {
            console.log("[SessionService] DRY-RUN: poweroff requested, skipping host command");
            root.sessionActionFinished("poweroff", 0);
            return;
        }
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
