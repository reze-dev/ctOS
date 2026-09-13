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
            console.log("=== EMPIRICAL PROBE: UINT ID AUTO-EXPIRY ===");
            NotificationService.clearAll();
            while (NotificationService.activeToasts.count > 0) {
                NotificationService.activeToasts.remove(0);
            }

            const uintId = 3000000000;
            NotificationService._handleNotification({
                id: uintId,
                appName: "UintDaemon",
                summary: "Uint Expiry Test",
                body: "Will it expire?",
                urgency: 1,
                expireTimeout: 100
            });

            console.log("activeToasts count before expiry: " + NotificationService.activeToasts.count);
            expiryWaitTimer.start();
        }
    }

    Timer {
        id: expiryWaitTimer
        interval: 300
        running: false
        repeat: false
        onTriggered: {
            console.log("activeToasts count after 300ms (expected 0): " + NotificationService.activeToasts.count);
            if (NotificationService.activeToasts.count > 0) {
                console.error("CRITICAL BUG: Toast with uint ID > 2147483647 NEVER EXPIRES! It is permanently stuck on desktop!");
            } else {
                console.log("Toast successfully auto-expired.");
            }
            Qt.quit();
        }
    }
}
