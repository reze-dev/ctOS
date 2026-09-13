import QtQuick
import Quickshell
import desktop.services
import desktop.core
import desktop.surfaces

Scope {
    id: root

    // Container for EventLog surface under test
    Item {
        id: container
        width: 360
        height: 800

        EventLog {
            id: eventLogSurface
            anchors.fill: parent
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
                if (!eventLogSurface) {
                    console.error("ASSERTION_FAILED: EventLog surface component failed to instantiate");
                    Qt.quit();
                    return;
                }
                if (eventLogSurface.width !== 360 || eventLogSurface.implicitWidth !== 360) {
                    console.error("ASSERTION_FAILED: EventLog root width must be 360");
                    Qt.quit();
                    return;
                }

                // 2. Initial Empty State
                NotificationService.clearAll();
                if (NotificationService.history.count !== 0) {
                    console.error("ASSERTION_FAILED: NotificationService.history must be empty initially");
                    Qt.quit();
                    return;
                }

                // 3. DND Button & Toggle State
                if (NotificationService.doNotDisturb !== false) {
                    console.error("ASSERTION_FAILED: NotificationService.doNotDisturb should initially be false");
                    Qt.quit();
                    return;
                }
                NotificationService.toggleDnd();
                if (NotificationService.doNotDisturb !== true) {
                    console.error("ASSERTION_FAILED: DND toggle failed to activate DND");
                    Qt.quit();
                    return;
                }
                NotificationService.toggleDnd();
                if (NotificationService.doNotDisturb !== false) {
                    console.error("ASSERTION_FAILED: DND toggle failed to deactivate DND");
                    Qt.quit();
                    return;
                }

                // 4. Inject Notifications of Differing Urgencies
                // Critical urgency (2)
                NotificationService._handleNotification({
                    id: 301,
                    appName: "SecuritySubsystem",
                    summary: "Kernel Integrity Violation",
                    body: "Unauthorized memory modification detected in sector 7",
                    urgency: 2
                });

                // Normal urgency (1)
                NotificationService._handleNotification({
                    id: 302,
                    appName: "AudioService",
                    summary: "Sink Route Updated",
                    body: "Default audio output switched to cyber-dac-0",
                    urgency: 1
                });

                // Low urgency (0)
                NotificationService._handleNotification({
                    id: 303,
                    appName: "NetworkTracer",
                    summary: "Ping Complete",
                    body: "Gateway latency 0.42ms",
                    urgency: 0
                });

                if (NotificationService.history.count !== 3) {
                    console.error("ASSERTION_FAILED: Expected 3 notifications in history, got " + NotificationService.history.count);
                    Qt.quit();
                    return;
                }

                // 5. Verify Individual Dismissal
                NotificationService.dismissHistoryItem(1);
                if (NotificationService.history.count !== 2) {
                    console.error("ASSERTION_FAILED: Expected 2 notifications after dismissing index 1, got " + NotificationService.history.count);
                    Qt.quit();
                    return;
                }

                // 6. Verify Escape Key / Dismissal Contract
                OverlayController.openEventLog();
                if (OverlayController.activeSurface !== OverlayController.Surface.EventLog) {
                    console.error("ASSERTION_FAILED: OverlayController.activeSurface should be EventLog");
                    Qt.quit();
                    return;
                }

                // Simulate ESC key handler invocation
                OverlayController.close();
                if (OverlayController.activeSurface !== OverlayController.Surface.None) {
                    console.error("ASSERTION_FAILED: OverlayController should be closed after ESC");
                    Qt.quit();
                    return;
                }

                // 7. Clear All
                NotificationService.clearAll();
                if (NotificationService.history.count !== 0) {
                    console.error("ASSERTION_FAILED: Expected 0 notifications after clearAll(), got " + NotificationService.history.count);
                    Qt.quit();
                    return;
                }

                console.log("=== PASS: T8 EventLog Surface Runtime Suite ===");
            } catch (err) {
                console.error("ASSERTION_FAILED: Unexpected error: " + err);
            }
            Qt.quit();
        }
    }
}
