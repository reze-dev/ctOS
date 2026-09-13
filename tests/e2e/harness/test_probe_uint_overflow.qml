import QtQuick
import Quickshell
import desktop.services

Scope {
    id: testScope

    Timer {
        interval: 10
        running: true
        repeat: false
        onTriggered: {
            console.log("=== EMPIRICAL PROBE: UINT ID OVERFLOW & GHOST TOAST ===");

            // Clear state
            NotificationService.clearAll();
            while (NotificationService.activeToasts.count > 0) {
                NotificationService.activeToasts.remove(0);
            }

            // Send notification with uint ID > 2147483647 (standard uint32 in freedesktop spec)
            const uintId = 3000000000;
            console.log("TEST: Sending notification with uint id: " + uintId);

            NotificationService._handleNotification({
                id: uintId,
                appName: "UintDaemon",
                summary: "Uint ID Test",
                body: "Testing ID overflow",
                urgency: 1
            });

            console.log("activeToasts count: " + NotificationService.activeToasts.count);
            if (NotificationService.activeToasts.count > 0) {
                const item = NotificationService.activeToasts.get(0);
                console.log("Toast 0 notifId in model: " + item.notifId);
                console.log("Toast 0 id in model: " + item.id);
            }

            console.log("Keys in _toastTimers: " + JSON.stringify(Object.keys(NotificationService._toastTimers)));
            console.log("Keys in _notificationObjects: " + JSON.stringify(Object.keys(NotificationService._notificationObjects)));

            // Now attempt to dismiss the toast by its ID
            console.log("TEST: Calling NotificationService.dismissToast(" + uintId + ")");
            NotificationService.dismissToast(uintId);

            console.log("activeToasts count after dismiss: " + NotificationService.activeToasts.count);
            console.log("Keys in _toastTimers after dismiss: " + JSON.stringify(Object.keys(NotificationService._toastTimers)));

            if (NotificationService.activeToasts.count !== 0) {
                console.error("BUG CONFIRMED: Toast with ID > 2147483647 cannot be dismissed via dismissToast()! activeToasts count=" + NotificationService.activeToasts.count);
            } else {
                console.log("Dismiss succeeded.");
            }

            Qt.quit();
        }
    }
}
