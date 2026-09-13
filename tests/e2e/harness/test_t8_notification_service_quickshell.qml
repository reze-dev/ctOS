import QtQuick
import Quickshell
import desktop.services
import desktop.core

Scope {
    id: root

    Timer {
        interval: 10
        running: true
        repeat: false
        onTriggered: {
            try {
                // 1. Singleton Resolution
                if (typeof NotificationService === "undefined" || !NotificationService) {
                    console.error("ASSERTION_FAILED: NotificationService singleton not resolved");
                    Qt.quit();
                    return;
                }

                // 2. Initial state
                if (!NotificationService.available) {
                    console.error("ASSERTION_FAILED: NotificationService.available should be true");
                    Qt.quit();
                    return;
                }
                if (NotificationService.doNotDisturb !== false) {
                    console.error("ASSERTION_FAILED: NotificationService.doNotDisturb should initially be false");
                    Qt.quit();
                    return;
                }
                if (NotificationService.unreadCount !== 0 || NotificationService.history.count !== 0) {
                    console.error("ASSERTION_FAILED: NotificationService.unreadCount/history.count should initially be 0");
                    Qt.quit();
                    return;
                }
                if (NotificationService.activeToasts.count !== 0) {
                    console.error("ASSERTION_FAILED: NotificationService.activeToasts.count should initially be 0");
                    Qt.quit();
                    return;
                }

                // 3. DND Toggle
                NotificationService.toggleDnd();
                if (NotificationService.doNotDisturb !== true) {
                    console.error("ASSERTION_FAILED: toggleDnd did not set doNotDisturb to true");
                    Qt.quit();
                    return;
                }
                NotificationService.toggleDnd();
                if (NotificationService.doNotDisturb !== false) {
                    console.error("ASSERTION_FAILED: toggleDnd did not toggle back to false");
                    Qt.quit();
                    return;
                }

                // 4. Notification Reception & Schema Verification
                NotificationService._handleNotification({
                    id: 201,
                    appName: "Security",
                    summary: "Firewall Alert",
                    body: "Unauthorized packet blocked",
                    urgency: 2,
                    expireTimeout: 8000,
                    actions: [
                        { identifier: "details", text: "View Details" }
                    ]
                });

                if (NotificationService.unreadCount !== 1 || NotificationService.activeToasts.count !== 1) {
                    console.error("ASSERTION_FAILED: Expected 1 unread and 1 active toast");
                    Qt.quit();
                    return;
                }

                const toast = NotificationService.activeToasts.get(0);
                if (toast.notifId !== 201 || toast.id !== 201 || toast.appName !== "Security" ||
                    toast.summary !== "Firewall Alert" || toast.urgency !== 2) {
                    console.error("ASSERTION_FAILED: Active toast schema mismatch");
                    Qt.quit();
                    return;
                }

                if (!toast.actions || toast.actions.count !== 1 || toast.actions.get(0).text !== "View Details") {
                    console.error("ASSERTION_FAILED: Toast actions mismatch");
                    Qt.quit();
                    return;
                }

                // 5. Timer Pause & Resume
                NotificationService.pauseToastTimer(201);
                NotificationService.resumeToastTimer(201);

                // 6. Max 3 Active Toasts Capacity
                NotificationService._handleNotification({ id: 202, appName: "App2", summary: "S2", body: "B2", urgency: 0 });
                NotificationService._handleNotification({ id: 203, appName: "App3", summary: "S3", body: "B3", urgency: 1 });
                NotificationService._handleNotification({ id: 204, appName: "App4", summary: "S4", body: "B4", urgency: 1 });

                if (NotificationService.activeToasts.count !== 3) {
                    console.error("ASSERTION_FAILED: activeToasts count should be capped at 3, got " + NotificationService.activeToasts.count);
                    Qt.quit();
                    return;
                }

                // Verify oldest (201) was evicted from toasts but retained in history
                let foundOldInToasts = false;
                for (let i = 0; i < NotificationService.activeToasts.count; ++i) {
                    if (NotificationService.activeToasts.get(i).notifId === 201) {
                        foundOldInToasts = true;
                    }
                }
                if (foundOldInToasts) {
                    console.error("ASSERTION_FAILED: Oldest toast 201 should have been evicted");
                    Qt.quit();
                    return;
                }

                if (NotificationService.history.count !== 4) {
                    console.error("ASSERTION_FAILED: history should retain all 4 notifications");
                    Qt.quit();
                    return;
                }

                // 7. DND Mode Suppresses Toasts
                NotificationService.toggleDnd();
                NotificationService._handleNotification({ id: 205, appName: "App5", summary: "S5", body: "B5", urgency: 1 });
                if (NotificationService.history.count !== 5) {
                    console.error("ASSERTION_FAILED: history should have 5 items with DND on");
                    Qt.quit();
                    return;
                }
                if (NotificationService.activeToasts.count !== 3) {
                    console.error("ASSERTION_FAILED: active toasts should remain 3 with DND on");
                    Qt.quit();
                    return;
                }
                NotificationService.toggleDnd();

                // 8. Dismiss individual toast
                NotificationService.dismissToast(204);
                if (NotificationService.activeToasts.count !== 2) {
                    console.error("ASSERTION_FAILED: active toasts should decrease to 2 after dismissing 204");
                    Qt.quit();
                    return;
                }
                if (NotificationService.history.count !== 5) {
                    console.error("ASSERTION_FAILED: dismissToast must not remove from history");
                    Qt.quit();
                    return;
                }

                // 9. Dismiss individual history item
                NotificationService.dismissHistoryItem(0);
                if (NotificationService.history.count !== 4 || NotificationService.unreadCount !== 4) {
                    console.error("ASSERTION_FAILED: history.count/unreadCount should be 4 after dismissHistoryItem(0)");
                    Qt.quit();
                    return;
                }

                // 10. Clear All
                NotificationService.clearAll();
                if (NotificationService.history.count !== 0 || NotificationService.unreadCount !== 0) {
                    console.error("ASSERTION_FAILED: history.count and unreadCount should be 0 after clearAll()");
                    Qt.quit();
                    return;
                }

                console.log("=== PASS: T8 NotificationService Runtime Suite ===");
            } catch (err) {
                console.error("ASSERTION_FAILED: " + err);
            }
            Qt.quit();
        }
    }
}
