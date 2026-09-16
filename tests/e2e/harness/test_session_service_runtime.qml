pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import desktop.core
import desktop.services
import desktop.surfaces

Scope {
    id: root

    property int passCount: 0
    property int failCount: 0
    property var results: []

    // Signal history trackers
    property var triggeredActions: []
    property var finishedActions: []

    function assertCondition(testId, desc, condition, details) {
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
    }

    Item {
        id: testContainer
        width: 360
        height: 800

        Loader {
            id: railLoader
            anchors.fill: parent
            active: false
            source: "file://" + (Quickshell.env("PROJECT_ROOT") || "/home/reze/Projects/ctOS") + "/shell/desktop/surfaces/SystemRail.qml"
        }
    }

    property int step: 0
    property int waitTicks: 0

    Timer {
        id: runnerTimer
        interval: 60
        repeat: true
        running: true

        onTriggered: {
            try {
                switch (root.step) {
                // =============================================================
                // STEP 0: Invariant Inspection of SessionService Singleton
                // =============================================================
                case 0:
                    console.log("================================================================");
                    console.log("=== M4 HEADLESS RUNTIME HARNESS: SESSION SERVICE VERIFICATION ==");
                    console.log("================================================================");

                    assertCondition("M4.RUNTIME.01", "SessionService singleton instantiated",
                        SessionService !== null && SessionService !== undefined,
                        "instance=" + SessionService);

                    assertCondition("M4.RUNTIME.02", "Initial isLocking is false",
                        SessionService.isLocking === false, "isLocking=" + SessionService.isLocking);
                    assertCondition("M4.RUNTIME.03", "Initial isLoggingOut is false",
                        SessionService.isLoggingOut === false, "isLoggingOut=" + SessionService.isLoggingOut);
                    assertCondition("M4.RUNTIME.04", "Initial isRebooting is false",
                        SessionService.isRebooting === false, "isRebooting=" + SessionService.isRebooting);
                    assertCondition("M4.RUNTIME.05", "Initial isPoweringOff is false",
                        SessionService.isPoweringOff === false, "isPoweringOff=" + SessionService.isPoweringOff);
                    assertCondition("M4.RUNTIME.06", "Initial isBusy is false",
                        SessionService.isBusy === false, "isBusy=" + SessionService.isBusy);

                    // Compositor detection inspection
                    assertCondition("M4.RUNTIME.07", "currentDesktop is exposed as string",
                        typeof SessionService.currentDesktop === "string", "desktop=" + SessionService.currentDesktop);
                    assertCondition("M4.RUNTIME.08", "isNiri is boolean",
                        typeof SessionService.isNiri === "boolean", "isNiri=" + SessionService.isNiri);
                    assertCondition("M4.RUNTIME.09", "isHyprland is boolean",
                        typeof SessionService.isHyprland === "boolean", "isHyprland=" + SessionService.isHyprland);
                    assertCondition("M4.RUNTIME.10", "compositorName matches detection state",
                        (SessionService.isNiri && SessionService.compositorName === "niri") ||
                        (SessionService.isHyprland && SessionService.compositorName === "hyprland") ||
                        (!SessionService.isNiri && !SessionService.isHyprland && SessionService.compositorName === "unknown"),
                        "compositorName=" + SessionService.compositorName);

                    assertCondition("M4.RUNTIME.11", "logoutCommand is array with valid arguments",
                        Array.isArray(SessionService.logoutCommand) && SessionService.logoutCommand.length >= 3,
                        "logoutCommand=" + JSON.stringify(SessionService.logoutCommand));

                    if (SessionService.isNiri) {
                        assertCondition("M4.RUNTIME.12", "Niri logoutCommand is ['niri', 'msg', 'action', 'quit']",
                            SessionService.logoutCommand.length === 4 &&
                            SessionService.logoutCommand[0] === "niri" &&
                            SessionService.logoutCommand[1] === "msg" &&
                            SessionService.logoutCommand[2] === "action" &&
                            SessionService.logoutCommand[3] === "quit",
                            "command=" + JSON.stringify(SessionService.logoutCommand));
                    } else {
                        assertCondition("M4.RUNTIME.12", "Hyprland logoutCommand is ['hyprctl', 'dispatch', 'exit']",
                            SessionService.logoutCommand.length === 3 &&
                            SessionService.logoutCommand[0] === "hyprctl" &&
                            SessionService.logoutCommand[1] === "dispatch" &&
                            SessionService.logoutCommand[2] === "exit",
                            "command=" + JSON.stringify(SessionService.logoutCommand));
                    }

                    // Unknown action handling
                    SessionService.executeAction("malicious_or_unknown_action_payload; rm -rf /");
                    assertCondition("M4.RUNTIME.13", "Unknown action rejected without setting isBusy",
                        SessionService.isBusy === false, "isBusy=" + SessionService.isBusy);
                    assertCondition("M4.RUNTIME.14", "Unknown action did not trigger any signal",
                        root.triggeredActions.length === 0, "triggered=" + root.triggeredActions.length);

                    root.step = 1;
                    break;

                // =============================================================
                // STEP 1: Direct Action Invocations & Signal Verification
                // =============================================================
                case 1:
                    console.log("=== STEP 1: Direct Session Action (Lock) Verification ===");
                    root.triggeredActions = [];
                    root.finishedActions = [];

                    SessionService.lock();

                    assertCondition("M4.RUNTIME.15", "lock() emitted sessionActionTriggered('lock')",
                        root.triggeredActions.indexOf("lock") !== -1,
                        "triggered=" + JSON.stringify(root.triggeredActions));

                    root.step = 2;
                    root.waitTicks = 0;
                    break;

                // Wait for lock process to finish
                case 2:
                    root.waitTicks++;
                    if (root.finishedActions.some(function(f) { return f.action === "lock"; }) || root.waitTicks > 15) {
                        assertCondition("M4.RUNTIME.16", "lock process finished cleanly with exitCode 0",
                            root.finishedActions.some(function(f) { return f.action === "lock" && f.exitCode === 0; }),
                            "finished=" + JSON.stringify(root.finishedActions));

                        assertCondition("M4.RUNTIME.17", "isLocking returned to false after finish",
                            SessionService.isLocking === false, "isLocking=" + SessionService.isLocking);
                        assertCondition("M4.RUNTIME.18", "isBusy returned to false after finish",
                            SessionService.isBusy === false, "isBusy=" + SessionService.isBusy);

                        root.step = 3;
                    }
                    break;

                // =============================================================
                // STEP 3: UI Destruction Survival - SystemRail Logout Flow
                // =============================================================
                case 3:
                    console.log("=== STEP 3: UI Destruction Survival - Logout Flow ===");
                    railLoader.active = true;
                    root.step = 4;
                    root.waitTicks = 0;
                    break;

                case 4:
                    root.waitTicks++;
                    if (railLoader.item !== null) {
                        assertCondition("M4.RUNTIME.19", "SystemRail mounted within Loader",
                            railLoader.item !== null, "item=" + railLoader.item);

                        root.triggeredActions = [];
                        root.finishedActions = [];

                        // Configure confirmation action on SystemRail and execute
                        railLoader.item.confirmationAction = "logout";
                        railLoader.item.executeConfirmation();

                        // IMMEDIATELY unmount and destroy SystemRail while action is in-flight!
                        railLoader.active = false;

                        assertCondition("M4.RUNTIME.20", "SystemRail item destroyed immediately upon active=false",
                            railLoader.item === null, "item=" + railLoader.item);

                        assertCondition("M4.RUNTIME.21", "SessionService remains alive and intact following UI destruction",
                            SessionService !== null && SessionService !== undefined,
                            "instance=" + SessionService);

                        assertCondition("M4.RUNTIME.22", "sessionActionTriggered('logout') dispatched despite UI destruction",
                            root.triggeredActions.indexOf("logout") !== -1,
                            "triggered=" + JSON.stringify(root.triggeredActions));

                        root.step = 5;
                        root.waitTicks = 0;
                    } else if (root.waitTicks > 10) {
                        assertCondition("M4.RUNTIME.19", "SystemRail mounted within Loader", false, "timeout loading");
                        root.step = 5;
                    }
                    break;

                case 5:
                    root.waitTicks++;
                    if (root.finishedActions.some(function(f) { return f.action === "logout"; }) || root.waitTicks > 15) {
                        assertCondition("M4.RUNTIME.23", "logout completed safely with exitCode 0 after UI destruction",
                            root.finishedActions.some(function(f) { return f.action === "logout" && f.exitCode === 0; }),
                            "finished=" + JSON.stringify(root.finishedActions));

                        assertCondition("M4.RUNTIME.24", "isLoggingOut returned to false after finish",
                            SessionService.isLoggingOut === false, "isLoggingOut=" + SessionService.isLoggingOut);
                        assertCondition("M4.RUNTIME.25", "isBusy returned to false after finish",
                            SessionService.isBusy === false, "isBusy=" + SessionService.isBusy);

                        root.step = 6;
                    }
                    break;

                // =============================================================
                // STEP 6: UI Destruction Survival - SystemRail Reboot Flow
                // =============================================================
                case 6:
                    console.log("=== STEP 6: UI Destruction Survival - Reboot Flow ===");
                    railLoader.active = true;
                    root.step = 7;
                    root.waitTicks = 0;
                    break;

                case 7:
                    root.waitTicks++;
                    if (railLoader.item !== null) {
                        root.triggeredActions = [];
                        root.finishedActions = [];

                        railLoader.item.confirmationAction = "reboot";
                        railLoader.item.executeConfirmation();

                        // Immediate destruction
                        railLoader.active = false;

                        assertCondition("M4.RUNTIME.26", "SystemRail destroyed immediately during reboot trigger",
                            railLoader.item === null, "item=" + railLoader.item);

                        assertCondition("M4.RUNTIME.27", "sessionActionTriggered('reboot') dispatched",
                            root.triggeredActions.indexOf("reboot") !== -1,
                            "triggered=" + JSON.stringify(root.triggeredActions));

                        root.step = 8;
                        root.waitTicks = 0;
                    } else if (root.waitTicks > 10) {
                        assertCondition("M4.RUNTIME.26", "SystemRail mounted for reboot", false, "timeout");
                        root.step = 8;
                    }
                    break;

                case 8:
                    root.waitTicks++;
                    if (root.finishedActions.some(function(f) { return f.action === "reboot"; }) || root.waitTicks > 15) {
                        assertCondition("M4.RUNTIME.28", "reboot completed safely with exitCode 0 after UI destruction",
                            root.finishedActions.some(function(f) { return f.action === "reboot" && f.exitCode === 0; }),
                            "finished=" + JSON.stringify(root.finishedActions));

                        assertCondition("M4.RUNTIME.29", "isRebooting returned to false",
                            SessionService.isRebooting === false, "isRebooting=" + SessionService.isRebooting);

                        root.step = 9;
                    }
                    break;

                // =============================================================
                // STEP 9: UI Destruction Survival - SystemRail Poweroff Flow
                // =============================================================
                case 9:
                    console.log("=== STEP 9: UI Destruction Survival - Poweroff Flow ===");
                    railLoader.active = true;
                    root.step = 10;
                    root.waitTicks = 0;
                    break;

                case 10:
                    root.waitTicks++;
                    if (railLoader.item !== null) {
                        root.triggeredActions = [];
                        root.finishedActions = [];

                        railLoader.item.confirmationAction = "poweroff";
                        railLoader.item.executeConfirmation();

                        // Immediate destruction
                        railLoader.active = false;

                        assertCondition("M4.RUNTIME.30", "SystemRail destroyed immediately during poweroff trigger",
                            railLoader.item === null, "item=" + railLoader.item);

                        assertCondition("M4.RUNTIME.31", "sessionActionTriggered('poweroff') dispatched",
                            root.triggeredActions.indexOf("poweroff") !== -1,
                            "triggered=" + JSON.stringify(root.triggeredActions));

                        root.step = 11;
                        root.waitTicks = 0;
                    } else if (root.waitTicks > 10) {
                        assertCondition("M4.RUNTIME.30", "SystemRail mounted for poweroff", false, "timeout");
                        root.step = 11;
                    }
                    break;

                case 11:
                    root.waitTicks++;
                    if (root.finishedActions.some(function(f) { return f.action === "poweroff"; }) || root.waitTicks > 15) {
                        assertCondition("M4.RUNTIME.32", "poweroff completed safely with exitCode 0 after UI destruction",
                            root.finishedActions.some(function(f) { return f.action === "poweroff" && f.exitCode === 0; }),
                            "finished=" + JSON.stringify(root.finishedActions));

                        assertCondition("M4.RUNTIME.33", "isPoweringOff returned to false",
                            SessionService.isPoweringOff === false, "isPoweringOff=" + SessionService.isPoweringOff);

                        root.step = 12;
                    }
                    break;

                // =============================================================
                // STEP 12: Concurrency & Rapid Re-entrancy Stress
                // =============================================================
                case 12:
                    console.log("=== STEP 12: Concurrency & Re-entrancy Stress ===");
                    root.triggeredActions = [];
                    root.finishedActions = [];

                    // Rapidly fire multiple actions in immediate succession
                    SessionService.executeAction("lock");
                    SessionService.executeAction("logout");
                    SessionService.executeAction("reboot");
                    SessionService.executeAction("poweroff");

                    assertCondition("M4.RUNTIME.34", "SessionService accepts rapid concurrent invocations",
                        root.triggeredActions.length === 4,
                        "triggeredCount=" + root.triggeredActions.length);

                    assertCondition("M4.RUNTIME.35", "isBusy reflects aggregated in-flight status",
                        SessionService.isBusy === (SessionService.isLocking || SessionService.isLoggingOut ||
                                                  SessionService.isRebooting || SessionService.isPoweringOff),
                        "isBusy=" + SessionService.isBusy);

                    root.step = 13;
                    root.waitTicks = 0;
                    break;

                case 13:
                    root.waitTicks++;
                    if (root.finishedActions.length >= 4 || root.waitTicks > 25) {
                        assertCondition("M4.RUNTIME.36", "All concurrent session actions finished without deadlocks",
                            root.finishedActions.length >= 4,
                            "finishedCount=" + root.finishedActions.length);

                        assertCondition("M4.RUNTIME.37", "Final state is completely idle",
                            SessionService.isBusy === false &&
                            SessionService.isLocking === false &&
                            SessionService.isLoggingOut === false &&
                            SessionService.isRebooting === false &&
                            SessionService.isPoweringOff === false,
                            "isBusy=" + SessionService.isBusy);

                        root.step = 14;
                    }
                    break;

                // =============================================================
                // STEP 14: Final Summary & Report
                // =============================================================
                case 14:
                    runnerTimer.running = false;
                    console.log("================================================================");
                    console.log("M4 RUNTIME HARNESS RESULTS: Passed=" + root.passCount + ", Failed=" + root.failCount);
                    if (root.failCount === 0 && root.passCount > 0) {
                        console.log("=== PASS: SESSION SERVICE RUNTIME HARNESS SUCCESSFUL ===");
                    } else {
                        console.error("=== FAIL: SESSION SERVICE RUNTIME HARNESS FAILED ===");
                    }
                    console.log("================================================================");
                    Qt.quit();
                    break;
                }
            } catch (err) {
                console.error("ASSERTION_FAILED: Exception in runtime harness step " + root.step + ": " + err);
                runnerTimer.running = false;
                Qt.quit();
            }
        }
    }
}
