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
        id: hostSimulation
        width: 360
        implicitWidth: 360
        implicitHeight: toastStack.implicitHeight

        NotificationToasts {
            id: toastStack
            width: 340
            anchors.horizontalCenter: parent.horizontalCenter
        }
    }

    Item {
        id: eventLogHost
        width: 360
        height: 800

        EventLog {
            id: eventLogSurface
            anchors.fill: parent
        }
    }

    Timer {
        interval: 15
        running: true
        repeat: false

        onTriggered: {
            console.log("=== BEGIN ADVERSARIAL STRESS SUITE FOR Shell Wiring & IPC ===");
            NotificationService.clearAll();
            OverlayController.close();

            // -------------------------------------------------------------
            // TEST 1: Rapid Toggle Stress (50 toggleEventLog cycles)
            // -------------------------------------------------------------
            try {
                console.log("-> Running Test 1: Rapid 50 toggleEventLog cycles...");
                for (let i = 0; i < 50; ++i) {
                    OverlayController.toggleEventLog();
                    const expectedState = (i % 2 === 0)
                        ? OverlayController.Surface.EventLog
                        : OverlayController.Surface.None;
                    if (OverlayController.activeSurface !== expectedState) {
                        recordFailure("Toggle_State_Cycle_" + i,
                            "Expected surface " + expectedState + ", got " + OverlayController.activeSurface);
                        break;
                    }
                }
                OverlayController.close();
            } catch (e) {
                recordFailure("Toggle_Exception", e.toString());
            }

            // -------------------------------------------------------------
            // TEST 2: Multi-Surface Exclusive Switching
            // -------------------------------------------------------------
            try {
                console.log("-> Running Test 2: Multi-Surface Exclusive Switching...");
                // Open CommandDeck
                OverlayController.toggleCommandDeck();
                if (OverlayController.activeSurface !== OverlayController.Surface.CommandDeck) {
                    recordFailure("Switch_CommandDeck", "Expected CommandDeck");
                }

                // Switch directly to EventLog
                OverlayController.toggleEventLog();
                if (OverlayController.activeSurface !== OverlayController.Surface.EventLog) {
                    recordFailure("Switch_Direct_EventLog", "Expected EventLog active, got " + OverlayController.activeSurface);
                }

                // Switch directly to SystemRail
                OverlayController.toggleSystemRail();
                if (OverlayController.activeSurface !== OverlayController.Surface.SystemRail) {
                    recordFailure("Switch_Direct_SystemRail", "Expected SystemRail active, got " + OverlayController.activeSurface);
                }

                // Switch back to EventLog
                OverlayController.toggleEventLog();
                if (OverlayController.activeSurface !== OverlayController.Surface.EventLog) {
                    recordFailure("Switch_Back_EventLog", "Expected EventLog active, got " + OverlayController.activeSurface);
                }

                // Close
                OverlayController.close();
                if (OverlayController.activeSurface !== OverlayController.Surface.None) {
                    recordFailure("Switch_Close", "Expected None, got " + OverlayController.activeSurface);
                }
            } catch (e) {
                recordFailure("MultiSurface_Exception", e.toString());
            }

            // -------------------------------------------------------------
            // TEST 3: Concurrent Notification Flood during EventLog Overlay Open
            // -------------------------------------------------------------
            try {
                console.log("-> Running Test 3: Concurrent Notification Flood while EventLog open...");
                OverlayController.openEventLog();
                for (let n = 1; n <= 30; ++n) {
                    NotificationService._handleNotification({
                        id: 9000 + n,
                        appName: "WiringStressDaemon",
                        summary: "Stress Notice #" + n,
                        body: "Validating non-blocking toast host synchronization while eventLog is open.",
                        urgency: n % 3
                    });
                }

                // Active toasts capped at 3
                if (NotificationService.activeToasts.count !== 3) {
                    recordFailure("ActiveToast_Cap", "Expected max 3 active toasts, got " + NotificationService.activeToasts.count);
                }

                // History has 30 items
                if (NotificationService.history.count !== 30) {
                    recordFailure("History_Count", "Expected 30 history items, got " + NotificationService.history.count);
                }

                // Host visibility condition must be true
                const isHostVisible = (NotificationService.activeToasts.count > 0);
                if (!isHostVisible) {
                    recordFailure("Host_Visibility", "Toast host should be visible when toasts > 0");
                }
            } catch (e) {
                recordFailure("Concurrent_Flood_Exception", e.toString());
            }

            // -------------------------------------------------------------
            // TEST 4: DND Suppression and Toast Host Hidden State
            // -------------------------------------------------------------
            try {
                console.log("-> Running Test 4: DND Suppression and Host Visibility...");
                // Dismiss any remaining active toasts
                while (NotificationService.activeToasts.count > 0) {
                    const topItem = NotificationService.activeToasts.get(0);
                    const tid = (topItem.notifId !== undefined ? topItem.notifId : topItem.id);
                    NotificationService.dismissToast(tid);
                }
                NotificationService.clearAll();

                if (NotificationService.activeToasts.count !== 0) {
                    recordFailure("Clear_Active", "activeToasts count must be 0 after dismissing active toasts");
                }

                NotificationService.toggleDnd(); // DND ON
                if (!NotificationService.doNotDisturb) {
                    recordFailure("Dnd_Toggle_On", "doNotDisturb should be true");
                }

                NotificationService._handleNotification({
                    id: 9999,
                    appName: "DndTest",
                    summary: "Should not show toast",
                    body: "DND active payload",
                    urgency: 1
                });

                // Toast host should remain hidden because DND suppressed it from activeToasts
                const toastVisibleUnderDnd = (NotificationService.activeToasts.count > 0);
                if (toastVisibleUnderDnd) {
                    recordFailure("Dnd_Host_Visible", "Toast host must NOT be visible under DND");
                }

                // But history receives it
                if (NotificationService.history.count !== 1) {
                    recordFailure("Dnd_History_Record", "History must still record under DND, count=" + NotificationService.history.count);
                }

                NotificationService.toggleDnd(); // DND OFF
                NotificationService.clearAll();
                OverlayController.close();
            } catch (e) {
                recordFailure("Dnd_Exception", e.toString());
            }

            // -------------------------------------------------------------
            // Final Assertion Summary
            // -------------------------------------------------------------
            if (failures.length > 0) {
                console.error("ASSERTION_FAILED: " + failures.length + " adversarial stress test(s) failed.");
            } else {
                console.log("=== PASS: T8 Shell Wiring Adversarial Suite ===");
            }
            Qt.quit();
        }
    }
}
