pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import desktop.services

Scope {
    id: root

    property int passCount: 0
    property int failCount: 0
    property var results: []

    // Signal history trackers
    property var triggeredActions: []
    property var finishedActions: []

    function record(testId, desc, condition, details) {
        if (condition) {
            passCount++;
            console.log("[PASS] " + testId + ": " + desc + (details ? " (" + details + ")" : ""));
            results.push({ id: testId, desc: desc, passed: true, details: details });
        } else {
            failCount++;
            console.error("[FAIL] " + testId + ": " + desc + (details ? " (" + details + ")" : ""));
            results.push({ id: testId, desc: desc, passed: false, details: details });
        }
    }

    property bool wasLocking: false
    property bool wasLoggingOut: false

    Connections {
        target: SessionService

        function onSessionActionTriggered(action) {
            console.log("  [SIGNAL] sessionActionTriggered('" + action + "')");
            root.triggeredActions.push(action);
        }

        function onSessionActionFinished(action, exitCode) {
            console.log("  [SIGNAL] sessionActionFinished('" + action + "', " + exitCode + ")");
            root.finishedActions.push({ action: action, exitCode: exitCode });
        }

        function onIsLockingChanged() {
            if (SessionService.isLocking) {
                root.wasLocking = true;
            }
        }

        function onIsLoggingOutChanged() {
            if (SessionService.isLoggingOut) {
                root.wasLoggingOut = true;
            }
        }
    }

    property int step: 0
    property int waitTicks: 0

    Timer {
        id: harnessTimer
        interval: 60
        repeat: true
        running: true

        onTriggered: {
            try {
                switch (root.step) {
                // =============================================================
                // STEP 0: Invariant Inspection & Compositor Contract Validation
                // =============================================================
                case 0:
                    console.log("================================================================");
                    console.log("=== M2 HEADLESS RUNTIME HARNESS: LOGOUT & COMPOSITOR DETECTION ==");
                    console.log("================================================================");

                    // 1. Singleton & Reactive State Invariants
                    root.record("M2.RUNTIME.01", "SessionService singleton instantiated and non-null",
                        SessionService !== null && SessionService !== undefined,
                        "instance=" + SessionService);

                    root.record("M2.RUNTIME.02", "Initial process states are idle",
                        SessionService.isLocking === false &&
                        SessionService.isLoggingOut === false &&
                        SessionService.isRebooting === false &&
                        SessionService.isPoweringOff === false &&
                        SessionService.isBusy === false,
                        "isBusy=" + SessionService.isBusy);

                    // 2. Detection Properties
                    root.record("M2.RUNTIME.03", "currentDesktop is exposed as string",
                        typeof SessionService.currentDesktop === "string",
                        "currentDesktop=" + SessionService.currentDesktop);

                    root.record("M2.RUNTIME.04", "isNiri is boolean",
                        typeof SessionService.isNiri === "boolean",
                        "isNiri=" + SessionService.isNiri);

                    root.record("M2.RUNTIME.05", "isHyprland is boolean",
                        typeof SessionService.isHyprland === "boolean",
                        "isHyprland=" + SessionService.isHyprland);

                    root.record("M2.RUNTIME.06", "compositorName matches detection state",
                        (SessionService.isNiri && SessionService.compositorName === "niri") ||
                        (SessionService.isHyprland && SessionService.compositorName === "hyprland") ||
                        (!SessionService.isNiri && !SessionService.isHyprland && SessionService.compositorName === "unknown"),
                        "compositorName=" + SessionService.compositorName);

                    // 3. Niri Detection & Command Construction with -s
                    if (SessionService.isNiri) {
                        root.record("M2.NIRI.01", "Niri logoutCommand is ['niri', 'msg', 'action', 'quit', '-s']",
                            Array.isArray(SessionService.logoutCommand) &&
                            SessionService.logoutCommand.length === 5 &&
                            SessionService.logoutCommand[0] === "niri" &&
                            SessionService.logoutCommand[1] === "msg" &&
                            SessionService.logoutCommand[2] === "action" &&
                            SessionService.logoutCommand[3] === "quit" &&
                            SessionService.logoutCommand[4] === "-s",
                            "cmd=" + JSON.stringify(SessionService.logoutCommand));

                        root.record("M2.NIRI.02", "Niri logoutCommand includes mandatory -s flag to prevent stdin hang",
                            SessionService.logoutCommand.indexOf("-s") === 4,
                            "index=" + SessionService.logoutCommand.indexOf("-s"));
                    } else if (SessionService.isHyprland) {
                        root.record("M2.HYPR.01", "Hyprland logoutCommand is ['hyprctl', 'dispatch', 'exit']",
                            Array.isArray(SessionService.logoutCommand) &&
                            SessionService.logoutCommand.length === 3 &&
                            SessionService.logoutCommand[0] === "hyprctl" &&
                            SessionService.logoutCommand[1] === "dispatch" &&
                            SessionService.logoutCommand[2] === "exit",
                            "cmd=" + JSON.stringify(SessionService.logoutCommand));
                    } else {
                        // Unknown compositor fallback
                        root.record("M2.FALLBACK.01", "Unknown compositor logoutCommand defaults to hyprctl dispatch exit",
                            Array.isArray(SessionService.logoutCommand) &&
                            SessionService.logoutCommand.length === 3 &&
                            SessionService.logoutCommand[0] === "hyprctl" &&
                            SessionService.logoutCommand[1] === "dispatch" &&
                            SessionService.logoutCommand[2] === "exit",
                            "cmd=" + JSON.stringify(SessionService.logoutCommand));
                    }

                    // 4. Fallback Architecture Properties & Transition Testing
                    root.record("M2.FALLBACK.02", "SessionService declares fallbackStage property initialized to 0",
                        typeof SessionService.fallbackStage === "number" && SessionService.fallbackStage === 0,
                        "fallbackStage=" + SessionService.fallbackStage);

                    // Test fallback state transitions on non-zero exit codes
                    SessionService.fallbackStage = 1;
                    SessionService.handleLogoutExit(1);
                    root.record("M2.FALLBACK.STAGE2", "Stage 1 non-zero failure advances fallbackStage to 2 (hyprctl)",
                        SessionService.fallbackStage === 2, "fallbackStage=" + SessionService.fallbackStage);

                    SessionService.handleLogoutExit(1);
                    root.record("M2.FALLBACK.STAGE3", "Stage 2 non-zero failure advances fallbackStage to 3 (loginctl)",
                        SessionService.fallbackStage === 3, "fallbackStage=" + SessionService.fallbackStage);

                    SessionService.handleLogoutExit(0);
                    root.record("M2.FALLBACK.RESET", "Stage 3 exit resets fallbackStage to 0",
                        SessionService.fallbackStage === 0, "fallbackStage=" + SessionService.fallbackStage);

                    // 5. Malicious / Unknown action rejection
                    SessionService.executeAction("invalid_unknown_action; echo hacked");
                    root.record("M2.SECURITY.01", "Unknown action safely rejected without setting isBusy",
                        SessionService.isBusy === false, "isBusy=" + SessionService.isBusy);
                    root.record("M2.SECURITY.02", "Unknown action did not emit triggered signal",
                        root.triggeredActions.length === 0, "triggeredCount=" + root.triggeredActions.length);

                    root.step = 1;
                    root.waitTicks = 0;
                    break;

                // =============================================================
                // STEP 1: Signal Emission - Lock Action Cycle
                // =============================================================
                case 1:
                    console.log("=== STEP 1: Verifying Lock Action Signal Emission ===");
                    root.triggeredActions = [];
                    root.finishedActions = [];

                    SessionService.lock();

                    root.record("M2.SIGNAL.01", "lock() emitted sessionActionTriggered('lock')",
                        root.triggeredActions.indexOf("lock") !== -1,
                        "triggered=" + JSON.stringify(root.triggeredActions));

                    root.step = 2;
                    root.waitTicks = 0;
                    break;

                case 2:
                    root.waitTicks++;
                    if (root.finishedActions.some(function(f) { return f.action === "lock"; }) || root.waitTicks > 20) {
                        root.record("M2.SIGNAL.02", "lock finished cleanly and emitted sessionActionFinished('lock', 0)",
                            root.finishedActions.some(function(f) { return f.action === "lock" && f.exitCode === 0; }),
                            "finished=" + JSON.stringify(root.finishedActions));

                        root.record("M2.SIGNAL.03", "isLocking and isBusy returned to false after lock finish",
                            SessionService.isLocking === false && SessionService.isBusy === false,
                            "isLocking=" + SessionService.isLocking + ", isBusy=" + SessionService.isBusy);

                        root.step = 3;
                        root.waitTicks = 0;
                    }
                    break;

                // =============================================================
                // STEP 3: Signal Emission - Logout Action Cycle
                // =============================================================
                case 3:
                    console.log("=== STEP 3: Verifying Logout Action Signal Emission ===");
                    root.triggeredActions = [];
                    root.finishedActions = [];

                    SessionService.logout();

                    root.record("M2.SIGNAL.04", "logout() emitted sessionActionTriggered('logout')",
                        root.triggeredActions.indexOf("logout") !== -1,
                        "triggered=" + JSON.stringify(root.triggeredActions));

                    root.step = 4;
                    root.waitTicks = 0;
                    break;

                case 4:
                    root.waitTicks++;
                    if (root.finishedActions.some(function(f) { return f.action === "logout"; }) || root.waitTicks > 20) {
                        root.record("M2.SIGNAL.05", "logout completed cleanly and emitted sessionActionFinished('logout', 0)",
                            root.finishedActions.some(function(f) { return f.action === "logout" && f.exitCode === 0; }),
                            "finished=" + JSON.stringify(root.finishedActions));

                        root.record("M2.SIGNAL.06", "isLoggingOut returned to false after logout finish",
                            SessionService.isLoggingOut === false,
                            "isLoggingOut=" + SessionService.isLoggingOut);

                        root.record("M2.SIGNAL.07", "isBusy returned to false after logout finish",
                            SessionService.isBusy === false,
                            "isBusy=" + SessionService.isBusy);

                        root.record("M2.SIGNAL.08", "fallbackStage returned to 0 after logout completion",
                            SessionService.fallbackStage === 0,
                            "fallbackStage=" + SessionService.fallbackStage);

                        root.step = 5;
                        root.waitTicks = 0;
                    }
                    break;

                // =============================================================
                // STEP 5: Concurrency, Re-entrancy & Aggregated State
                // =============================================================
                case 5:
                    console.log("=== STEP 5: Verifying Concurrency & Aggregation ===");
                    root.triggeredActions = [];
                    root.finishedActions = [];

                    // Trigger reboot and poweroff concurrently
                    SessionService.executeAction("reboot");
                    SessionService.executeAction("poweroff");

                    root.record("M2.CONCURRENCY.01", "Both reboot and poweroff triggered concurrently",
                        root.triggeredActions.indexOf("reboot") !== -1 && root.triggeredActions.indexOf("poweroff") !== -1,
                        "triggered=" + JSON.stringify(root.triggeredActions));

                    root.record("M2.CONCURRENCY.02", "isBusy accurately aggregates concurrent active states",
                        SessionService.isBusy === (SessionService.isLocking || SessionService.isLoggingOut ||
                                                  SessionService.isRebooting || SessionService.isPoweringOff),
                        "isBusy=" + SessionService.isBusy);

                    root.step = 6;
                    root.waitTicks = 0;
                    break;

                case 6:
                    root.waitTicks++;
                    if (root.finishedActions.length >= 2 || root.waitTicks > 25) {
                        root.record("M2.CONCURRENCY.03", "Concurrent actions completed without deadlock",
                            root.finishedActions.length >= 2,
                            "finishedCount=" + root.finishedActions.length);

                        root.record("M2.CONCURRENCY.04", "Final system state is fully idle",
                            SessionService.isBusy === false &&
                            SessionService.isLocking === false &&
                            SessionService.isLoggingOut === false &&
                            SessionService.isRebooting === false &&
                            SessionService.isPoweringOff === false,
                            "isBusy=" + SessionService.isBusy);

                        root.step = 7;
                    }
                    break;

                // =============================================================
                // STEP 7: Final Summary & Termination
                // =============================================================
                case 7:
                    harnessTimer.running = false;
                    console.log("================================================================");
                    console.log("M2 LOGOUT HARNESS RESULTS: Passed=" + root.passCount + ", Failed=" + root.failCount);
                    if (root.failCount === 0 && root.passCount > 0) {
                        console.log("=== PASS: M2 LOGOUT & COMPOSITOR DETECTION HARNESS SUCCESSFUL ===");
                    } else {
                        console.error("=== FAIL: M2 LOGOUT & COMPOSITOR DETECTION HARNESS FAILED ===");
                    }
                    console.log("================================================================");
                    Qt.quit();
                    break;
                }
            } catch (err) {
                console.error("ASSERTION_FAILED: Exception in M2 runtime harness step " + root.step + ": " + err);
                harnessTimer.running = false;
                Qt.quit();
            }
        }
    }
}
