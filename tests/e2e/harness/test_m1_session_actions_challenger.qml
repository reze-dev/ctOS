import QtQuick
import Quickshell
import desktop.services
import desktop.core

Scope {
    id: root

    property int passCount: 0
    property int failCount: 0
    property var results: []

    function assertCondition(id, desc, cond, details) {
        if (cond) {
            passCount++;
            console.log("[PASS] " + id + ": " + desc + (details ? " (" + details + ")" : ""));
            results.push({ id: id, desc: desc, passed: true });
        } else {
            failCount++;
            console.error("[FAIL] " + id + ": " + desc + (details ? " (" + details + ")" : ""));
            results.push({ id: id, desc: desc, passed: false, details: details });
        }
    }

    Item {
        id: container
        width: 360
        height: 800

        Loader {
            id: railLoader
            anchors.fill: parent
            source: "file:///home/reze/Projects/ctOS/shell/desktop/surfaces/SystemRail.qml"
        }
    }

    function findItem(rootItem, predicate) {
        if (!rootItem) return null;
        if (predicate(rootItem)) return rootItem;
        if (rootItem.children) {
            for (let i = 0; i < rootItem.children.length; i++) {
                const res = findItem(rootItem.children[i], predicate);
                if (res) return res;
            }
        }
        return null;
    }

    function findMouseAreaForText(railSurface, textMatch) {
        const textItem = findItem(railSurface, (o) => o.text === textMatch);
        if (!textItem) return null;
        let curr = textItem.parent;
        while (curr && curr !== railSurface) {
            const ma = findItem(curr, (o) => o.toString().indexOf("QQuickMouseArea") !== -1);
            if (ma) return ma;
            curr = curr.parent;
        }
        return null;
    }

    property var lockProc: null
    property var logoutProc: null
    property var rebootProc: null
    property var poweroffProc: null

    property int currentStep: 0

    Timer {
        id: stepTimer
        interval: 120
        repeat: true
        running: true

        onTriggered: {
            const rail = railLoader.item;
            if (!rail) {
                console.error("SystemRail not loaded yet");
                return;
            }

            try {
                if (currentStep === 0) {
                    console.log("=== STEP 0: Invariant Inspection of SystemRail & Process Nodes ===");
                    assertCondition("CHAL.M1.01", "SystemRail root width is 360", rail.width === 360, "width=" + rail.width);
                    assertCondition("CHAL.M1.02", "Initial confirmationAction is empty string", rail.confirmationAction === "", "action=" + rail.confirmationAction);
                    assertCondition("CHAL.M1.03", "Initial isConfirming is false", rail.isConfirming === false, "isConfirming=" + rail.isConfirming);

                    // Inspect resources for declarative Process nodes
                    const res = rail.resources;
                    assertCondition("CHAL.M1.04", "SystemRail defines resources", res && res.length >= 4, "count=" + (res ? res.length : 0));

                    for (let i = 0; i < res.length; i++) {
                        const item = res[i];
                        if (item && item.command && item.command.length !== undefined) {
                            const cmd = item.command;
                            if (cmd.length === 2 && cmd[0] === "loginctl" && cmd[1] === "lock-session") {
                                lockProc = item;
                            } else if (cmd.length === 3 && cmd[0] === "hyprctl" && cmd[1] === "dispatch" && cmd[2] === "exit") {
                                logoutProc = item;
                            } else if (cmd.length === 2 && cmd[0] === "systemctl" && cmd[1] === "reboot") {
                                rebootProc = item;
                            } else if (cmd.length === 2 && cmd[0] === "systemctl" && cmd[1] === "poweroff") {
                                poweroffProc = item;
                            }
                        }
                    }

                    assertCondition("CHAL.M1.05", "lockProcess identified with ['loginctl', 'lock-session']", lockProc !== null, "found=" + (lockProc !== null));
                    assertCondition("CHAL.M1.06", "logoutProcess identified with ['hyprctl', 'dispatch', 'exit']", logoutProc !== null, "found=" + (logoutProc !== null));
                    assertCondition("CHAL.M1.07", "rebootProcess identified with ['systemctl', 'reboot']", rebootProc !== null, "found=" + (rebootProc !== null));
                    assertCondition("CHAL.M1.08", "poweroffProcess identified with ['systemctl', 'poweroff']", poweroffProc !== null, "found=" + (poweroffProc !== null));

                    assertCondition("CHAL.M1.09", "lockProcess initializes with running === false", lockProc && lockProc.running === false, "running=" + (lockProc ? lockProc.running : "n/a"));
                    assertCondition("CHAL.M1.10", "logoutProcess initializes with running === false", logoutProc && logoutProc.running === false, "running=" + (logoutProc ? logoutProc.running : "n/a"));
                    assertCondition("CHAL.M1.11", "rebootProcess initializes with running === false", rebootProc && rebootProc.running === false, "running=" + (rebootProc ? rebootProc.running : "n/a"));
                    assertCondition("CHAL.M1.12", "poweroffProcess initializes with running === false", poweroffProc && poweroffProc.running === false, "running=" + (poweroffProc ? poweroffProc.running : "n/a"));

                } else if (currentStep === 1) {
                    console.log("=== STEP 1: Lock Session Action Flow ===");
                    // Activate SystemRail overlay
                    OverlayController.toggle(OverlayController.Surface.SystemRail);
                    assertCondition("CHAL.M1.13", "Overlay is active prior to lock", OverlayController.isOverlayActive === true, "active=" + OverlayController.isOverlayActive);

                    const lockMA = findMouseAreaForText(rail, "LOCK SESSION");
                    assertCondition("CHAL.M1.14", "lockMouseArea found via visual tree search", lockMA !== null, "found=" + (lockMA !== null));

                    if (lockMA) {
                        lockMA.clicked(null);
                    }

                    assertCondition("CHAL.M1.15", "Lock session immediately closes OverlayController", OverlayController.isOverlayActive === false, "active=" + OverlayController.isOverlayActive);
                    assertCondition("CHAL.M1.16", "Lock session triggers lockProcess (running === true)", lockProc.running === true, "running=" + lockProc.running);
                    assertCondition("CHAL.M1.17", "Lock session does NOT trigger logoutProcess", logoutProc.running === false, "running=" + logoutProc.running);
                    assertCondition("CHAL.M1.18", "Lock session does NOT trigger rebootProcess", rebootProc.running === false, "running=" + rebootProc.running);
                    assertCondition("CHAL.M1.19", "Lock session does NOT trigger poweroffProcess", poweroffProc.running === false, "running=" + poweroffProc.running);
                    assertCondition("CHAL.M1.20", "Lock session bypasses confirmation dialog (confirmationAction === '')", rail.confirmationAction === "", "action=" + rail.confirmationAction);

                } else if (currentStep === 2) {
                    console.log("=== STEP 2: Lock Process Execution Completion ===");
                    assertCondition("CHAL.M1.21", "lockProcess returns to running === false after execution", lockProc.running === false, "running=" + lockProc.running);

                } else if (currentStep === 3) {
                    console.log("=== STEP 3: Logout Confirmation & Safe Cancel Flow ===");
                    OverlayController.toggle(OverlayController.Surface.SystemRail);
                    const logoutMA = findMouseAreaForText(rail, "LOGOUT");
                    assertCondition("CHAL.M1.22", "logoutMouseArea found via visual tree search", logoutMA !== null, "found=" + (logoutMA !== null));

                    if (logoutMA) {
                        logoutMA.clicked(null);
                    }

                    assertCondition("CHAL.M1.23", "Logout tile click sets confirmationAction to 'logout'", rail.confirmationAction === "logout", "action=" + rail.confirmationAction);
                    assertCondition("CHAL.M1.24", "Logout tile click sets isConfirming to true", rail.isConfirming === true, "isConfirming=" + rail.isConfirming);
                    assertCondition("CHAL.M1.25", "Logout tile click does NOT trigger logoutProcess prematurely", logoutProc.running === false, "running=" + logoutProc.running);
                    assertCondition("CHAL.M1.26", "OverlayController remains active during confirmation", OverlayController.isOverlayActive === true, "active=" + OverlayController.isOverlayActive);

                    // Cancel confirmation via Cancel button click
                    const cancelMA = findMouseAreaForText(rail, "[ ESC ] CANCEL");
                    assertCondition("CHAL.M1.27", "cancelMouseArea found via visual tree search", cancelMA !== null, "found=" + (cancelMA !== null));

                    if (cancelMA) {
                        cancelMA.clicked(null);
                    }

                    assertCondition("CHAL.M1.28", "Cancel button resets confirmationAction to empty string", rail.confirmationAction === "", "action=" + rail.confirmationAction);
                    assertCondition("CHAL.M1.29", "Cancel button resets isConfirming to false", rail.isConfirming === false, "isConfirming=" + rail.isConfirming);
                    assertCondition("CHAL.M1.30", "Cancel button does NOT trigger logoutProcess", logoutProc.running === false, "running=" + logoutProc.running);
                    assertCondition("CHAL.M1.31", "OverlayController remains open after cancel", OverlayController.isOverlayActive === true, "active=" + OverlayController.isOverlayActive);

                } else if (currentStep === 4) {
                    console.log("=== STEP 4: Tiered Escape Trapping during Confirmation ===");
                    rail.triggerConfirmation("logout");
                    assertCondition("CHAL.M1.32", "triggerConfirmation('logout') sets isConfirming", rail.isConfirming === true, "isConfirming=" + rail.isConfirming);

                    // First Escape: must trap and cancel confirmation, NOT close overlay
                    rail.handleEscape();
                    assertCondition("CHAL.M1.33", "First Escape cancels confirmation (isConfirming === false)", rail.isConfirming === false, "isConfirming=" + rail.isConfirming);
                    assertCondition("CHAL.M1.34", "First Escape traps and keeps overlay open", OverlayController.isOverlayActive === true, "active=" + OverlayController.isOverlayActive);
                    assertCondition("CHAL.M1.35", "First Escape does NOT trigger logoutProcess", logoutProc.running === false, "running=" + logoutProc.running);

                    // Second Escape: now in main view without confirmation, must close overlay
                    rail.handleEscape();
                    assertCondition("CHAL.M1.36", "Second Escape closes overlay (isOverlayActive === false)", OverlayController.isOverlayActive === false, "active=" + OverlayController.isOverlayActive);

                } else if (currentStep === 5) {
                    console.log("=== STEP 5: Logout Confirmation Execution Flow ===");
                    OverlayController.toggle(OverlayController.Surface.SystemRail);
                    rail.triggerConfirmation("logout");

                    const confirmMA = findMouseAreaForText(rail, "CONFIRM // EXECUTE");
                    assertCondition("CHAL.M1.37", "confirmMouseArea found via visual tree search", confirmMA !== null, "found=" + (confirmMA !== null));

                    if (confirmMA) {
                        confirmMA.clicked(null);
                    }

                    assertCondition("CHAL.M1.38", "Execute confirmation closes OverlayController immediately", OverlayController.isOverlayActive === false, "active=" + OverlayController.isOverlayActive);
                    assertCondition("CHAL.M1.39", "Execute confirmation resets confirmationAction to empty", rail.confirmationAction === "", "action=" + rail.confirmationAction);
                    assertCondition("CHAL.M1.40", "Execute confirmation triggers logoutProcess (running === true)", logoutProc.running === true, "running=" + logoutProc.running);
                    assertCondition("CHAL.M1.41", "logout execution does NOT trigger rebootProcess", rebootProc.running === false, "running=" + rebootProc.running);
                    assertCondition("CHAL.M1.42", "logout execution does NOT trigger poweroffProcess", poweroffProc.running === false, "running=" + poweroffProc.running);

                } else if (currentStep === 6) {
                    console.log("=== STEP 6: Reboot Confirmation Execution Flow ===");
                    assertCondition("CHAL.M1.43", "logoutProcess returned to idle", logoutProc.running === false, "running=" + logoutProc.running);

                    OverlayController.toggle(OverlayController.Surface.SystemRail);
                    const rebootMA = findMouseAreaForText(rail, "REBOOT");
                    if (rebootMA) rebootMA.clicked(null);

                    assertCondition("CHAL.M1.44", "Reboot tile sets confirmationAction to 'reboot'", rail.confirmationAction === "reboot", "action=" + rail.confirmationAction);
                    assertCondition("CHAL.M1.45", "Reboot process not triggered before confirm", rebootProc.running === false, "running=" + rebootProc.running);

                    const confirmMA = findMouseAreaForText(rail, "CONFIRM // EXECUTE");
                    if (confirmMA) confirmMA.clicked(null);

                    assertCondition("CHAL.M1.46", "Reboot confirmation closes OverlayController", OverlayController.isOverlayActive === false, "active=" + OverlayController.isOverlayActive);
                    assertCondition("CHAL.M1.47", "Reboot confirmation triggers rebootProcess", rebootProc.running === true, "running=" + rebootProc.running);
                    assertCondition("CHAL.M1.48", "Reboot confirmation does NOT trigger logoutProcess", logoutProc.running === false, "running=" + logoutProc.running);
                    assertCondition("CHAL.M1.49", "Reboot confirmation does NOT trigger poweroffProcess", poweroffProc.running === false, "running=" + poweroffProc.running);

                } else if (currentStep === 7) {
                    console.log("=== STEP 7: Power Off Confirmation Execution Flow ===");
                    assertCondition("CHAL.M1.50", "rebootProcess returned to idle", rebootProc.running === false, "running=" + rebootProc.running);

                    OverlayController.toggle(OverlayController.Surface.SystemRail);
                    const powerMA = findMouseAreaForText(rail, "POWER");
                    if (powerMA) powerMA.clicked(null);

                    assertCondition("CHAL.M1.51", "Power tile sets confirmationAction to 'poweroff'", rail.confirmationAction === "poweroff", "action=" + rail.confirmationAction);
                    assertCondition("CHAL.M1.52", "Power process not triggered before confirm", poweroffProc.running === false, "running=" + poweroffProc.running);

                    const confirmMA = findMouseAreaForText(rail, "CONFIRM // EXECUTE");
                    if (confirmMA) confirmMA.clicked(null);

                    assertCondition("CHAL.M1.53", "Power confirmation closes OverlayController", OverlayController.isOverlayActive === false, "active=" + OverlayController.isOverlayActive);
                    assertCondition("CHAL.M1.54", "Power confirmation triggers poweroffProcess", poweroffProc.running === true, "running=" + poweroffProc.running);
                    assertCondition("CHAL.M1.55", "Power confirmation does NOT trigger rebootProcess", rebootProc.running === false, "running=" + rebootProc.running);

                } else if (currentStep === 8) {
                    console.log("=== STEP 8: Adversarial Checks (Injection & Re-entrancy) ===");
                    assertCondition("CHAL.M1.56", "poweroffProcess returned to idle", poweroffProc.running === false, "running=" + poweroffProc.running);

                    OverlayController.toggle(OverlayController.Surface.SystemRail);

                    // Adversarial 1: Malicious action injection
                    rail.triggerConfirmation("inject; rm -rf /");
                    assertCondition("CHAL.M1.57", "Arbitrary action accepted by state machine", rail.confirmationAction === "inject; rm -rf /", "action=" + rail.confirmationAction);
                    rail.executeConfirmation();
                    assertCondition("CHAL.M1.58", "Arbitrary action does NOT trigger lockProcess", lockProc.running === false, "running=" + lockProc.running);
                    assertCondition("CHAL.M1.59", "Arbitrary action does NOT trigger logoutProcess", logoutProc.running === false, "running=" + logoutProc.running);
                    assertCondition("CHAL.M1.60", "Arbitrary action does NOT trigger rebootProcess", rebootProc.running === false, "running=" + rebootProc.running);
                    assertCondition("CHAL.M1.61", "Arbitrary action does NOT trigger poweroffProcess", poweroffProc.running === false, "running=" + poweroffProc.running);
                    assertCondition("CHAL.M1.62", "confirmationAction safely cleared after invalid action execution", rail.confirmationAction === "", "action=" + rail.confirmationAction);

                    // Adversarial 2: Rapid action overwrite
                    rail.triggerConfirmation("logout");
                    rail.triggerConfirmation("reboot");
                    assertCondition("CHAL.M1.63", "Sequential trigger overwrites confirmationAction to latest", rail.confirmationAction === "reboot", "action=" + rail.confirmationAction);

                    // Adversarial 3: Cancel then execute race
                    rail.cancelConfirmation();
                    rail.executeConfirmation(); // confirmationAction is "", should do nothing
                    assertCondition("CHAL.M1.64", "executeConfirmation on empty confirmationAction does NOT trigger reboot", rebootProc.running === false, "running=" + rebootProc.running);

                    // Adversarial 4: Pending action synchronization from OverlayController
                    OverlayController.pendingSessionAction = "logout";
                    assertCondition("CHAL.M1.65", "OverlayController.pendingSessionAction syncs to root.confirmationAction", rail.confirmationAction === "logout", "action=" + rail.confirmationAction);
                    assertCondition("CHAL.M1.66", "OverlayController.pendingSessionAction is consumed (cleared)", OverlayController.pendingSessionAction === "", "pending=" + OverlayController.pendingSessionAction);
                    rail.cancelConfirmation();

                } else if (currentStep === 9) {
                    console.log("=== FINAL REPORT ===");
                    console.log("Total Assertions Tested: " + (passCount + failCount));
                    console.log("Passed: " + passCount + " | Failed: " + failCount);
                    stepTimer.running = false;

                    if (failCount === 0 && passCount > 0) {
                        console.log("=== PASS: M1 SYSTEM RAIL SESSION ACTIONS RUNTIME HARNESS ===");
                    } else {
                        console.error("=== FAIL: M1 SYSTEM RAIL SESSION ACTIONS RUNTIME HARNESS ===");
                    }
                    Qt.quit();
                }

                currentStep++;
            } catch (err) {
                console.error("ASSERTION_FAILED: Exception during step " + currentStep + ": " + err);
                stepTimer.running = false;
                Qt.quit();
            }
        }
    }
}
