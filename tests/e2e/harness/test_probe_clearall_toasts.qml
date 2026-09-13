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
            console.log("=== EMPIRICAL PROBE: clearAll() vs activeToasts ===");

            // Ensure clean state
            while (NotificationService.activeToasts.count > 0) {
                NotificationService.activeToasts.remove(0);
            }
            NotificationService.clearAll();

            // Send 3 notifications
            for (let i = 1; i <= 3; ++i) {
                NotificationService._handleNotification({
                    id: 100 + i,
                    appName: "App" + i,
                    summary: "Notice " + i,
                    body: "Body " + i,
                    urgency: 1
                });
            }

            console.log("Before clearAll():");
            console.log("  activeToasts.count: " + NotificationService.activeToasts.count);
            console.log("  history.count:      " + NotificationService.history.count);
            console.log("  _toastTimers keys:  " + JSON.stringify(Object.keys(NotificationService._toastTimers)));
            console.log("  _notificationObjects keys: " + JSON.stringify(Object.keys(NotificationService._notificationObjects)));

            // User clicks [CLEAR ALL] in EventLog
            console.log("ACTION: NotificationService.clearAll()");
            NotificationService.clearAll();

            console.log("Immediately After clearAll():");
            console.log("  activeToasts.count: " + NotificationService.activeToasts.count);
            console.log("  history.count:      " + NotificationService.history.count);
            console.log("  _toastTimers keys:  " + JSON.stringify(Object.keys(NotificationService._toastTimers)));
            console.log("  _notificationObjects keys: " + JSON.stringify(Object.keys(NotificationService._notificationObjects)));

            Qt.quit();
        }
    }
}
