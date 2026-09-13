import QtQuick
import Quickshell
import desktop.services
import desktop.core
import desktop.surfaces

Scope {
    id: root

    // Test EventLog surface component
    Item {
        id: eventLogContainer
        width: 360
        height: 800

        EventLog {
            id: eventLogSurface
            anchors.fill: parent
        }
    }

    // Test NotificationToasts instantiation & layout
    Item {
        id: toastContainer
        width: 360
        implicitWidth: 360
        implicitHeight: toastStack.implicitHeight

        NotificationToasts {
            id: toastStack
            width: 340
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
                // 1. Initial State Checks
                if (OverlayController.activeSurface !== OverlayController.Surface.None) {
                    OverlayController.close();
                }
                NotificationService.clearAll();

                // 2. Verify EventLog component instantiated
                if (!eventLogSurface) {
                    console.error("ASSERTION_FAILED: EventLog component failed to instantiate");
                    Qt.quit();
                    return;
                }
                if (eventLogSurface.width !== 360 || eventLogSurface.implicitWidth !== 360) {
                    console.error("ASSERTION_FAILED: EventLog surface width should be 360, got " + eventLogSurface.width);
                    Qt.quit();
                    return;
                }

                // 3. Verify IPC toggleEventLog method contract on OverlayController
                if (typeof OverlayController.toggleEventLog !== "function") {
                    console.error("ASSERTION_FAILED: OverlayController.toggleEventLog is not a function");
                    Qt.quit();
                    return;
                }

                // Toggle EventLog open
                OverlayController.toggleEventLog();
                if (OverlayController.activeSurface !== OverlayController.Surface.EventLog) {
                    console.error("ASSERTION_FAILED: activeSurface after toggleEventLog should be EventLog (3), got " + OverlayController.activeSurface);
                    Qt.quit();
                    return;
                }
                if (!OverlayController.isOverlayActive) {
                    console.error("ASSERTION_FAILED: isOverlayActive should be true when EventLog is open");
                    Qt.quit();
                    return;
                }

                // Toggle EventLog closed
                OverlayController.toggleEventLog();
                if (OverlayController.activeSurface !== OverlayController.Surface.None) {
                    console.error("ASSERTION_FAILED: activeSurface after second toggleEventLog should be None (0), got " + OverlayController.activeSurface);
                    Qt.quit();
                    return;
                }
                if (OverlayController.isOverlayActive) {
                    console.error("ASSERTION_FAILED: isOverlayActive should be false when EventLog is closed");
                    Qt.quit();
                    return;
                }

                // 4. Verify NotificationToasts container & toast stack
                if (!toastStack) {
                    console.error("ASSERTION_FAILED: NotificationToasts toastStack failed to instantiate");
                    Qt.quit();
                    return;
                }
                if (toastStack.width !== 340 || toastStack.implicitWidth !== 340) {
                    console.error("ASSERTION_FAILED: toastStack width/implicitWidth must be 340, got " + toastStack.width);
                    Qt.quit();
                    return;
                }

                // Verify toast host visibility binding logic
                const initialVisible = NotificationService.activeToasts.count > 0;
                if (initialVisible) {
                    console.error("ASSERTION_FAILED: NotificationToastHost visibility condition must be false initially");
                    Qt.quit();
                    return;
                }

                // Inject a test notification
                NotificationService._handleNotification({
                    id: 888,
                    appName: "ShellWiringTest",
                    summary: "Toast Host Test",
                    body: "Verifying toast host visibility and dimensions",
                    urgency: 1
                });

                const activeVisible = NotificationService.activeToasts.count > 0;
                if (!activeVisible) {
                    console.error("ASSERTION_FAILED: NotificationToastHost visibility condition must be true after notification");
                    Qt.quit();
                    return;
                }

                // Dismiss toast
                NotificationService.dismissToast(888);
                const finalVisible = NotificationService.activeToasts.count > 0;
                if (finalVisible) {
                    console.error("ASSERTION_FAILED: NotificationToastHost visibility condition must return to false after dismiss");
                    Qt.quit();
                    return;
                }

                NotificationService.clearAll();

                console.log("=== PASS: T8 Shell Wiring Runtime Suite ===");
            } catch (err) {
                console.error("ASSERTION_FAILED: Unexpected error: " + err);
            }
            Qt.quit();
        }
    }
}
