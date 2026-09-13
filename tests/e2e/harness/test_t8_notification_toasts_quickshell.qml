import QtQuick
import Quickshell
import desktop.services
import desktop.core
import desktop.surfaces

Scope {
    id: root

    Item {
        id: container
        width: 360
        height: 600

        NotificationToasts {
            id: toastStack
            anchors.horizontalCenter: parent.horizontalCenter
        }
    }

    Timer {
        id: testTimer
        interval: 20
        running: true
        repeat: false

        onTriggered: {
            try {
                // 1. Root Component Verification
                if (!toastStack) {
                    console.error("ASSERTION_FAILED: NotificationToasts component failed to instantiate");
                    Qt.quit();
                    return;
                }
                if (toastStack.width !== 340 || toastStack.implicitWidth !== 340) {
                    console.error("ASSERTION_FAILED: NotificationToasts root width must be 340, got " + toastStack.width);
                    Qt.quit();
                    return;
                }

                // Helper function to dismiss all active toasts
                function clearActiveToasts() {
                    while (NotificationService.activeToasts.count > 0) {
                        const t = NotificationService.activeToasts.get(0);
                        NotificationService.dismissToast(t.notifId);
                    }
                }

                // 2. Initial Empty State
                clearActiveToasts();
                NotificationService.clearAll();
                if (NotificationService.activeToasts.count !== 0) {
                    console.error("ASSERTION_FAILED: NotificationService.activeToasts must be empty initially");
                    Qt.quit();
                    return;
                }

                // 3. Inject Critical Notification (urgency: 2)
                NotificationService._handleNotification({
                    id: 101,
                    appName: "SecuritySubsystem",
                    summary: "Threat Detected",
                    body: "Unauthorized intrusion vector intercepted",
                    urgency: 2
                });

                if (NotificationService.activeToasts.count !== 1) {
                    console.error("ASSERTION_FAILED: Expected 1 active toast, got " + NotificationService.activeToasts.count);
                    Qt.quit();
                    return;
                }

                const toast1 = NotificationService.activeToasts.get(0);
                if (!toast1 || toast1.notifId !== 101 || toast1.urgency !== 2) {
                    console.error("ASSERTION_FAILED: Toast 1 data mismatch");
                    Qt.quit();
                    return;
                }

                // 4. Inject Normal Notification (urgency: 1)
                NotificationService._handleNotification({
                    id: 102,
                    appName: "NetworkService",
                    summary: "Link Established",
                    body: "Connected to gateway on interface eth0",
                    urgency: 1
                });

                if (NotificationService.activeToasts.count !== 2) {
                    console.error("ASSERTION_FAILED: Expected 2 active toasts, got " + NotificationService.activeToasts.count);
                    Qt.quit();
                    return;
                }

                // 5. Inject Low Notification (urgency: 0)
                NotificationService._handleNotification({
                    id: 103,
                    appName: "AudioService",
                    summary: "Volume Changed",
                    body: "Volume set to 65%",
                    urgency: 0
                });

                if (NotificationService.activeToasts.count !== 3) {
                    console.error("ASSERTION_FAILED: Expected 3 active toasts, got " + NotificationService.activeToasts.count);
                    Qt.quit();
                    return;
                }

                // 6. Max 3 Toasts Cap Verification
                NotificationService._handleNotification({
                    id: 104,
                    appName: "PowerService",
                    summary: "AC Connected",
                    body: "Switched to line power",
                    urgency: 1
                });

                if (NotificationService.activeToasts.count !== 3) {
                    console.error("ASSERTION_FAILED: Expected activeToasts count capped at 3, got " + NotificationService.activeToasts.count);
                    Qt.quit();
                    return;
                }

                // 7. Hover Pause & Resume Verification
                const activeId = NotificationService.activeToasts.get(0).notifId;
                const timerObj = NotificationService._toastTimers[activeId];
                if (!timerObj) {
                    console.error("ASSERTION_FAILED: Expiry timer missing for toast " + activeId);
                    Qt.quit();
                    return;
                }
                if (!timerObj.running) {
                    console.error("ASSERTION_FAILED: Expiry timer should be initially running");
                    Qt.quit();
                    return;
                }

                NotificationService.pauseToastTimer(activeId);
                if (timerObj.running) {
                    console.error("ASSERTION_FAILED: Expiry timer should be paused after pauseToastTimer");
                    Qt.quit();
                    return;
                }

                NotificationService.resumeToastTimer(activeId);
                if (!timerObj.running) {
                    console.error("ASSERTION_FAILED: Expiry timer should be resumed after resumeToastTimer");
                    Qt.quit();
                    return;
                }

                // 8. Action Buttons Invocation Verification
                let actionTriggered = false;
                const mockAction = {
                    identifier: "act_test",
                    text: "ACKNOWLEDGE",
                    invoke: function () {
                        actionTriggered = true;
                    }
                };

                NotificationService._handleNotification({
                    id: 201,
                    appName: "DiagnosticDaemon",
                    summary: "Sensor Calibrated",
                    body: "Telemetry ready",
                    urgency: 1,
                    actions: [mockAction]
                });

                let foundActionToast = false;
                for (let i = 0; i < NotificationService.activeToasts.count; ++i) {
                    const item = NotificationService.activeToasts.get(i);
                    if (item && item.notifId === 201) {
                        foundActionToast = true;
                        break;
                    }
                }
                if (!foundActionToast) {
                    console.error("ASSERTION_FAILED: Action toast 201 not found in activeToasts");
                    Qt.quit();
                    return;
                }

                // Invoke action directly to verify contract
                mockAction.invoke();
                if (!actionTriggered) {
                    console.error("ASSERTION_FAILED: Action invoke did not execute callback");
                    Qt.quit();
                    return;
                }

                // 9. Click Dismissal Verification
                NotificationService.dismissToast(201);
                for (let j = 0; j < NotificationService.activeToasts.count; ++j) {
                    const remaining = NotificationService.activeToasts.get(j);
                    if (remaining && remaining.notifId === 201) {
                        console.error("ASSERTION_FAILED: Toast 201 still present after dismissal");
                        Qt.quit();
                        return;
                    }
                }

                // 10. Clear All Active Toasts
                clearActiveToasts();
                NotificationService.clearAll();
                if (NotificationService.activeToasts.count !== 0) {
                    console.error("ASSERTION_FAILED: activeToasts not empty after clearActiveToasts");
                    Qt.quit();
                    return;
                }

                console.log("=== PASS: T8 NotificationToasts Runtime Suite ===");
            } catch (err) {
                console.error("ASSERTION_FAILED: Unexpected error: " + err);
            }
            Qt.quit();
        }
    }
}
