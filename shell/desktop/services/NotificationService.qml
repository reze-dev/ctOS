pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import "../core"

Singleton {
    id: root

    // =========================================================================
    // Service Availability & Configuration
    // =========================================================================

    // Reflects user configuration from Settings
    property bool available: Settings.featuresNotifications

    // Do Not Disturb mode suppresses popup toasts while still recording to history
    property bool doNotDisturb: false

    // Active count of stored history notifications
    readonly property int unreadCount: history.count

    // Session-local notification history model
    readonly property ListModel history: historyModel

    // Currently visible toast notifications model (max 3)
    readonly property ListModel activeToasts: activeToastsModel

    // =========================================================================
    // Internal Models
    // =========================================================================

    ListModel {
        id: historyModel
    }

    ListModel {
        id: activeToastsModel
    }

    // =========================================================================
    // Internal State & Timers
    // =========================================================================

    // Map of notifId -> Timer instance
    property var _toastTimers: ({})

    // Map of notifId -> raw Notification object
    property var _notificationObjects: ({})

    // Component for instantiating per-toast auto-expiry timers
    Component {
        id: toastTimerComponent

        Timer {
            id: toastTimer
            property var notifId: 0
            property int remainingMs: 5000
            property real startTime: 0
            repeat: false

            function pause(): void {
                if (running) {
                    stop();
                    const elapsed = Date.now() - startTime;
                    remainingMs = Math.max(500, remainingMs - elapsed);
                }
            }

            function resume(): void {
                if (!running && remainingMs > 0) {
                    interval = remainingMs;
                    startTime = Date.now();
                    start();
                }
            }

            onTriggered: {
                const notif = root._notificationObjects[notifId];
                if (notif && typeof notif.expire === "function") {
                    try {
                        notif.expire();
                    } catch (e) {}
                }
                root.dismissToast(notifId);
            }
        }
    }

    // =========================================================================
    // Quickshell Notification Server Backend
    // =========================================================================

    NotificationServer {
        id: server
        bodySupported: true
        actionsSupported: true
        imageSupported: true
        bodyMarkupSupported: true

        onNotification: (notification) => {
            root._handleNotification(notification);
        }
    }

    // =========================================================================
    // Internal Helper Methods
    // =========================================================================

    function _createToastTimer(notifId: var, timeoutMs: int): void {
        if (root._toastTimers[notifId]) {
            root._toastTimers[notifId].stop();
            root._toastTimers[notifId].destroy();
            delete root._toastTimers[notifId];
        }

        const timer = toastTimerComponent.createObject(root, {
            notifId: notifId,
            interval: timeoutMs,
            remainingMs: timeoutMs,
            startTime: Date.now()
        });
        if (timer) {
            root._toastTimers[notifId] = timer;
            timer.running = true;
        }
    }

    function _handleNotification(notification: var): void {
        if (!root.available || !notification) {
            return;
        }

        const notifId = Number(notification.id || 0);
        const appName = String(notification.appName || "System");
        const summary = String(notification.summary || "");
        const body = String(notification.body || "");

        let urgencyVal = 1;
        if (notification.urgency !== undefined && notification.urgency !== null) {
            urgencyVal = Number(notification.urgency);
        }
        if (isNaN(urgencyVal) || urgencyVal < 0 || urgencyVal > 2) {
            urgencyVal = 1;
        }

        const image = String(notification.image || notification.appIcon || "");
        const timestamp = Qt.formatTime(new Date(), "hh:mm:ss");

        let actionList = [];
        if (notification.actions && typeof notification.actions.length === "number") {
            for (let i = 0; i < notification.actions.length; ++i) {
                const act = notification.actions[i];
                if (act) {
                    actionList.push({
                        identifier: String(act.identifier || ("action_" + i)),
                        text: String(act.text || act.identifier || "Action")
                    });
                }
            }
        }

        if (notification.tracked !== undefined) {
            notification.tracked = true;
        }
        root._notificationObjects[notifId] = notification;

        if (typeof notification.closed?.connect === "function") {
            try {
                notification.closed.connect(() => {
                    root.dismissToast(notifId);
                });
            } catch (e) {}
        }

        const record = {
            notifId: notifId,
            id: notifId,
            appName: appName,
            summary: summary,
            body: body,
            urgency: urgencyVal,
            image: image,
            timestamp: timestamp,
            actions: actionList
        };

        for (let h = 0; h < historyModel.count; ++h) {
            const existing = historyModel.get(h);
            if (existing && (existing.notifId === notifId || existing.id === notifId)) {
                historyModel.remove(h);
                break;
            }
        }
        historyModel.insert(0, record);

        if (!root.doNotDisturb) {
            for (let t = activeToastsModel.count - 1; t >= 0; --t) {
                const existingToast = activeToastsModel.get(t);
                if (existingToast && (existingToast.notifId === notifId || existingToast.id === notifId)) {
                    activeToastsModel.remove(t);
                }
            }

            while (activeToastsModel.count >= 3) {
                const oldest = activeToastsModel.get(0);
                if (oldest && oldest.notifId !== undefined) {
                    root.dismissToast(oldest.notifId);
                }
                if (activeToastsModel.count >= 3) {
                    activeToastsModel.remove(0);
                }
            }

            activeToastsModel.append(record);

            let timeoutMs = 5000;
            if (urgencyVal === 2) {
                timeoutMs = 10000;
            }
            if (notification.expireTimeout !== undefined && Number(notification.expireTimeout) > 0) {
                timeoutMs = Math.min(Math.round(Number(notification.expireTimeout)), 86400000);
            }

            root._createToastTimer(notifId, timeoutMs);
        }
    }

    // =========================================================================
    // Public Methods
    // =========================================================================

    // Toggles Do Not Disturb mode on/off
    function toggleDnd(): void {
        root.doNotDisturb = !root.doNotDisturb;
    }

    // Dismisses a visible toast popup by its notification ID and tears down its timer
    function dismissToast(notifId: var): void {
        const targetId = Number(notifId);

        const timer = root._toastTimers[targetId];
        if (timer) {
            timer.stop();
            timer.destroy();
            delete root._toastTimers[targetId];
        }

        for (let i = activeToastsModel.count - 1; i >= 0; --i) {
            const item = activeToastsModel.get(i);
            if (item && (item.notifId === targetId || item.id === targetId)) {
                activeToastsModel.remove(i);
            }
        }

        const notif = root._notificationObjects[targetId];
        if (notif) {
            delete root._notificationObjects[targetId];
            if (typeof notif.dismiss === "function") {
                try {
                    notif.dismiss();
                } catch (e) {}
            }
        }
    }

    // Dismisses a single notification entry from history by its index
    function dismissHistoryItem(index: int): void {
        const targetIndex = Number(index);
        if (targetIndex >= 0 && targetIndex < historyModel.count) {
            const item = historyModel.get(targetIndex);
            if (item) {
                const targetId = Number(item.notifId !== undefined ? item.notifId : item.id);
                if (root._notificationObjects[targetId]) {
                    const notif = root._notificationObjects[targetId];
                    delete root._notificationObjects[targetId];
                    if (typeof notif.dismiss === "function") {
                        try {
                            notif.dismiss();
                        } catch (e) {}
                    }
                }
            }
            historyModel.remove(targetIndex);
        }
    }

    // Clears all stored notifications from history
    function clearAll(): void {
        historyModel.clear();
        for (let id in root._notificationObjects) {
            const notif = root._notificationObjects[id];
            if (notif && typeof notif.dismiss === "function") {
                try {
                    notif.dismiss();
                } catch (e) {}
            }
        }
        root._notificationObjects = ({});
    }

    // Pauses auto-expiry countdown for the given toast (e.g. while hovered)
    function pauseToastTimer(notifId: var): void {
        const timer = root._toastTimers[Number(notifId)];
        if (timer && typeof timer.pause === "function") {
            timer.pause();
        }
    }

    // Resumes auto-expiry countdown for the given toast (e.g. on mouse exit)
    function resumeToastTimer(notifId: var): void {
        const timer = root._toastTimers[Number(notifId)];
        if (timer && typeof timer.resume === "function") {
            timer.resume();
        }
    }

    // Invokes a specific action on a tracked notification by action identifier
    function invokeAction(notifId: var, actionIdentifier: string): void {
        const targetId = Number(notifId);
        const notif = root._notificationObjects[targetId];
        if (notif && notif.actions) {
            for (let i = 0; i < notif.actions.length; ++i) {
                const act = notif.actions[i];
                if (act && act.identifier === actionIdentifier) {
                    if (typeof act.invoke === "function") {
                        act.invoke();
                    }
                    break;
                }
            }
        }
    }

    // Returns the native actions array for a notification (if available)
    function getActions(notifId: var): var {
        const targetId = Number(notifId);
        const notif = root._notificationObjects[targetId];
        return (notif && notif.actions) ? notif.actions : [];
    }
}
