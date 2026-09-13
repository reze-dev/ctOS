import QtQuick
import Quickshell
import desktop.services
import desktop.core
import desktop.surfaces

Scope {
    id: root

    property var failures: []

    function recordFailure(testName, reason) {
        console.error("ADVERSARIAL_FAILURE: [" + testName + "] " + reason);
        failures.push({ test: testName, reason: reason });
    }

    Item {
        id: testContainer
        width: 360
        height: 800

        NotificationToasts {
            id: toastSurface
            anchors.horizontalCenter: parent.horizontalCenter
        }
    }

    Timer {
        interval: 15
        running: true
        repeat: false

        onTriggered: {
            console.log("=== BEGIN ADVERSARIAL STRESS SUITE FOR NotificationToasts ===");
            function clearActiveToasts() {
                while (NotificationService.activeToasts.count > 0) {
                    const t = NotificationService.activeToasts.get(0);
                    NotificationService.dismissToast(t.notifId);
                }
            }
            clearActiveToasts();
            NotificationService.clearAll();

            // -------------------------------------------------------------
            // TEST 1: Rapid Flood of 50 Notifications & Active Toast Cap (max 3)
            // -------------------------------------------------------------
            try {
                console.log("-> Running Test 1: Rapid 50 Notifications flood...");
                for (let i = 1; i <= 50; ++i) {
                    NotificationService._handleNotification({
                        id: 600 + i,
                        appName: "FloodDaemon" + i,
                        summary: "Stream burst packet #" + i,
                        body: "Payload stream stress test active sequence " + i,
                        urgency: i % 3
                    });
                }

                if (NotificationService.activeToasts.count > 3) {
                    recordFailure("ActiveToast_Cap", "Active toasts exceeded maximum limit of 3: " + NotificationService.activeToasts.count);
                }
            } catch (e) {
                recordFailure("Flood_Exception", e.toString());
            }

            // -------------------------------------------------------------
            // TEST 2: Boundary Dismissals (Non-existent IDs)
            // -------------------------------------------------------------
            try {
                console.log("-> Running Test 2: Boundary dismissals (invalid IDs)...");
                NotificationService.dismissToast(-1);
                NotificationService.dismissToast(999999);
                NotificationService.dismissToast(0);

                if (NotificationService.activeToasts.count !== 3) {
                    recordFailure("Boundary_Dismiss", "Invalid dismiss modified activeToasts count: " + NotificationService.activeToasts.count);
                }
            } catch (e) {
                recordFailure("Boundary_Exception", e.toString());
            }

            // -------------------------------------------------------------
            // TEST 3: Extreme Content Stress
            // -------------------------------------------------------------
            try {
                console.log("-> Running Test 3: Extreme Content Stress...");
                NotificationService._handleNotification({
                    id: 888,
                    appName: "OVERFLOW_TITLE_VERY_LONG_STRING_THAT_SHOULD_BE_ELIDED_SAFELY_IN_HEADER",
                    summary: "UNBROKEN_STRING_AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA",
                    body: "Line 1: ░▒▓█ CTOS GLYPH MATRIX █▓▒░\nLine 2: <b>Markup</b> &amp; entities\nLine 3: Third line clamp\nLine 4: Overflow line",
                    urgency: 2
                });

                if (NotificationService.activeToasts.count > 3) {
                    recordFailure("Extreme_Content_Cap", "Active toasts exceeded 3 after extreme content insertion");
                }
            } catch (e) {
                recordFailure("Extreme_Content_Exception", e.toString());
            }

            // -------------------------------------------------------------
            // TEST 4: Rapid Hover Pause & Resume Cycles
            // -------------------------------------------------------------
            try {
                console.log("-> Running Test 4: Rapid Hover Pause/Resume cycles...");
                const topToast = NotificationService.activeToasts.get(NotificationService.activeToasts.count - 1);
                if (topToast) {
                    for (let c = 0; c < 30; ++c) {
                        NotificationService.pauseToastTimer(topToast.notifId);
                        NotificationService.resumeToastTimer(topToast.notifId);
                    }
                }
            } catch (e) {
                recordFailure("Hover_Stress_Exception", e.toString());
            }

            // -------------------------------------------------------------
            // TEST 5: Multiple Actions Stress
            // -------------------------------------------------------------
            try {
                console.log("-> Running Test 5: Multiple Actions Array Stress...");
                let invokedCount = 0;
                let actionsList = [];
                for (let a = 1; a <= 5; ++a) {
                    actionsList.push({
                        identifier: "action_" + a,
                        text: "BTN_" + a,
                        invoke: function () {
                            invokedCount++;
                        }
                    });
                }

                NotificationService._handleNotification({
                    id: 999,
                    appName: "MultiActionDaemon",
                    summary: "Multiple Actions Test",
                    body: "Five action buttons attached",
                    urgency: 1,
                    actions: actionsList
                });

                // Trigger action 0
                actionsList[0].invoke();
                if (invokedCount !== 1) {
                    recordFailure("MultiAction_Invoke", "Action invoke failed, invokedCount = " + invokedCount);
                }
            } catch (e) {
                recordFailure("MultiAction_Exception", e.toString());
            }

            // -------------------------------------------------------------
            // TEST 6: Clear All Under Heavy Load
            // -------------------------------------------------------------
            try {
                console.log("-> Running Test 6: Clear All Reset...");
                clearActiveToasts();
                NotificationService.clearAll();
                if (NotificationService.activeToasts.count !== 0) {
                    recordFailure("ClearAll_Reset", "activeToasts not 0 after clearActiveToasts: " + NotificationService.activeToasts.count);
                }
                if (NotificationService.history.count !== 0) {
                    recordFailure("History_Reset", "history not 0 after clearAll: " + NotificationService.history.count);
                }
            } catch (e) {
                recordFailure("ClearAll_Exception", e.toString());
            }

            // Final Evaluation
            if (failures.length === 0) {
                console.log("=== PASS: T8 NotificationToasts Adversarial Suite ===");
            } else {
                console.error("=== FAIL: " + failures.length + " ADVERSARIAL CHECKS FAILED ===");
                for (let f = 0; f < failures.length; ++f) {
                    console.error("  FAIL [" + failures[f].test + "]: " + failures[f].reason);
                }
            }
            Qt.quit();
        }
    }
}
