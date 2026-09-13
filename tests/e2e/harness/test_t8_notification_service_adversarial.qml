import QtQuick
import Quickshell
import desktop.services
import desktop.core

Scope {
    id: root

    property var failures: []

    function recordFailure(testName, reason) {
        console.error("ADVERSARIAL_FAILURE: [" + testName + "] " + reason);
        failures.push({ test: testName, reason: reason });
    }

    Timer {
        interval: 10
        running: true
        repeat: false
        onTriggered: {
            console.log("=== BEGIN ADVERSARIAL STRESS SUITE FOR NotificationService ===");
            NotificationService.clearAll();

            // -------------------------------------------------------------
            // TEST 1: Rapid Burst (100 notifications)
            // -------------------------------------------------------------
            try {
                console.log("-> Running Test 1: Rapid Burst (100 notifications)...");
                for (let i = 1; i <= 100; ++i) {
                    NotificationService._handleNotification({
                        id: i,
                        appName: "BurstApp" + i,
                        summary: "Burst summary " + i,
                        body: "Burst body " + i,
                        urgency: i % 3,
                        expireTimeout: 5000
                    });
                    if (NotificationService.activeToasts.count > 3) {
                        recordFailure("Burst_Capacity", "activeToasts exceeded max 3 during burst, got " + NotificationService.activeToasts.count + " at iteration " + i);
                    }
                }

                if (NotificationService.activeToasts.count !== 3) {
                    recordFailure("Burst_ActiveCount", "Expected exactly 3 active toasts after 100 burst notifications, got " + NotificationService.activeToasts.count);
                }
                if (NotificationService.history.count !== 100) {
                    recordFailure("Burst_HistoryCount", "Expected 100 history items after burst, got " + NotificationService.history.count);
                }
                if (NotificationService.unreadCount !== 100) {
                    recordFailure("Burst_UnreadCount", "Expected unreadCount == 100, got " + NotificationService.unreadCount);
                }

                // Verify active toasts are the 3 newest (98, 99, 100)
                let ids = [];
                for (let a = 0; a < NotificationService.activeToasts.count; ++a) {
                    ids.push(NotificationService.activeToasts.get(a).notifId);
                }
                if (ids.indexOf(98) === -1 || ids.indexOf(99) === -1 || ids.indexOf(100) === -1) {
                    recordFailure("Burst_OldestEviction", "Active toasts should contain newest notifications 98, 99, 100; got: " + JSON.stringify(ids));
                }

                // Verify timers count in _toastTimers is exactly 3
                let timerKeys = Object.keys(NotificationService._toastTimers || {});
                if (timerKeys.length !== 3) {
                    recordFailure("Burst_TimerLeak", "Expected 3 active timers in _toastTimers, found " + timerKeys.length);
                }
            } catch (e) {
                recordFailure("Burst_Exception", e.toString());
            }

            // Cleanup burst
            NotificationService.clearAll();
            for (let d = 1; d <= 100; ++d) {
                NotificationService.dismissToast(d);
            }

            // -------------------------------------------------------------
            // TEST 2: Duplicate ID / Notification Update Ghost Toast Bug
            // -------------------------------------------------------------
            try {
                console.log("-> Running Test 2: Duplicate ID / Notification Update...");
                NotificationService._handleNotification({
                    id: 301,
                    appName: "MusicPlayer",
                    summary: "Track 1",
                    expireTimeout: 50
                });

                if (NotificationService.activeToasts.count !== 1) {
                    recordFailure("Update_Initial", "Expected 1 active toast, got " + NotificationService.activeToasts.count);
                }

                // Send update for same notification ID 301
                NotificationService._handleNotification({
                    id: 301,
                    appName: "MusicPlayer",
                    summary: "Track 2 (Updated)",
                    expireTimeout: 50
                });

                if (NotificationService.activeToasts.count > 1) {
                    recordFailure("Update_DuplicateToast", "CRITICAL BUG: activeToasts contains " + NotificationService.activeToasts.count +
                                  " toasts for the same notification ID 301. Updating a notification duplicated the toast!");
                }

                if (NotificationService.history.count !== 1) {
                    recordFailure("Update_HistoryDuplicate", "history should only have 1 record for updated notification 301, got " + NotificationService.history.count);
                }
            } catch (e) {
                recordFailure("Update_Exception", e.toString());
            }

            // -------------------------------------------------------------
            // TEST 3: DND Mode and Memory Leak Assessment
            // -------------------------------------------------------------
            try {
                console.log("-> Running Test 3: DND Mode and Object Tracking...");
                NotificationService.toggleDnd();
                if (!NotificationService.doNotDisturb) {
                    recordFailure("DND_Toggle", "doNotDisturb is false after toggleDnd()");
                }

                for (let k = 401; k <= 420; ++k) {
                    NotificationService._handleNotification({
                        id: k,
                        appName: "DndApp",
                        summary: "Dnd alert " + k
                    });
                }

                // Active toasts should not increase from DND notifications
                // Only whatever was left from Test 2 if any
                let dndActiveCount = 0;
                for (let a = 0; a < NotificationService.activeToasts.count; ++a) {
                    if (NotificationService.activeToasts.get(a).notifId >= 401 && NotificationService.activeToasts.get(a).notifId <= 420) {
                        dndActiveCount++;
                    }
                }
                if (dndActiveCount > 0) {
                    recordFailure("DND_Suppression", "DND failed to suppress active toasts; " + dndActiveCount + " DND toasts appeared");
                }

                // History should record all 20
                let dndHistoryCount = 0;
                for (let h = 0; h < NotificationService.history.count; ++h) {
                    if (NotificationService.history.get(h).notifId >= 401 && NotificationService.history.get(h).notifId <= 420) {
                        dndHistoryCount++;
                    }
                }
                if (dndHistoryCount !== 20) {
                    recordFailure("DND_HistoryCapture", "Expected 20 DND notifications in history, found " + dndHistoryCount);
                }

                // Check _notificationObjects leak after clearAll
                NotificationService.clearAll();
                if (NotificationService.history.count !== 0) {
                    recordFailure("ClearAll_History", "history not empty after clearAll");
                }

                let leakedNotifObjs = 0;
                for (let key in (NotificationService._notificationObjects || {})) {
                    leakedNotifObjs++;
                }
                if (leakedNotifObjs >= 20) {
                    recordFailure("DND_MemoryLeak", "MEMORY LEAK: _notificationObjects retained " + leakedNotifObjs + " raw notification objects after clearAll()");
                }

                NotificationService.toggleDnd(); // restore DND = false
            } catch (e) {
                recordFailure("DND_Exception", e.toString());
            }

            // -------------------------------------------------------------
            // TEST 4: Boundary & Malformed Inputs
            // -------------------------------------------------------------
            try {
                console.log("-> Running Test 4: Boundary & Malformed Inputs...");
                // Null summary, empty body, invalid urgencies, negative timeouts
                NotificationService._handleNotification({
                    id: 501,
                    appName: null,
                    summary: null,
                    body: null,
                    urgency: -99,
                    expireTimeout: -500
                });

                const notifRecord = NotificationService.history.get(0);
                if (!notifRecord) {
                    recordFailure("Malformed_Insert", "Notification with null fields failed to insert into history");
                } else {
                    if (typeof notifRecord.summary !== "string") {
                        recordFailure("Malformed_SummaryType", "record.summary should be string, got " + typeof notifRecord.summary);
                    }
                    if (notifRecord.urgency !== 1) {
                        recordFailure("Malformed_UrgencyClamp", "record.urgency should clamp to 1 (Normal) for invalid urgency, got " + notifRecord.urgency);
                    }
                }

                // Extreme expireTimeout > int32 max
                NotificationService._handleNotification({
                    id: 502,
                    summary: "Overflow Timeout",
                    expireTimeout: 3000000000
                });

                const overflowTimer = NotificationService._toastTimers[502];
                if (overflowTimer && overflowTimer.interval < 0) {
                    recordFailure("Timeout_Overflow", "Timer interval overflowed to negative (" + overflowTimer.interval + ") on expireTimeout > INT32_MAX");
                }
            } catch (e) {
                recordFailure("Malformed_Exception", e.toString());
            }

            // -------------------------------------------------------------
            // TEST 5: Method Robustness Under Adversarial Invocations
            // -------------------------------------------------------------
            try {
                console.log("-> Running Test 5: Method Robustness Under Adversarial Invocations...");
                // Double dismiss
                NotificationService.dismissToast(501);
                NotificationService.dismissToast(501);

                // Dismiss non-existent ID
                NotificationService.dismissToast(99999);
                NotificationService.dismissToast(-1);

                // Pause/resume non-existent or dismissed IDs
                NotificationService.pauseToastTimer(99999);
                NotificationService.resumeToastTimer(99999);
                NotificationService.pauseToastTimer(-1);

                // dismissHistoryItem out of bounds
                NotificationService.dismissHistoryItem(-1);
                NotificationService.dismissHistoryItem(99999);

                // clearAll on empty
                NotificationService.clearAll();
                NotificationService.clearAll();

                if (NotificationService.unreadCount !== 0) {
                    recordFailure("MethodRobustness_UnreadCount", "unreadCount should be 0, got " + NotificationService.unreadCount);
                }
            } catch (e) {
                recordFailure("MethodRobustness_Exception", e.toString());
            }

            // -------------------------------------------------------------
            // TEST 6: Timer Pause & Resume Accuracy
            // -------------------------------------------------------------
            try {
                console.log("-> Running Test 6: Timer Pause & Resume Flutter...");
                NotificationService._handleNotification({
                    id: 601,
                    summary: "Flutter Timer",
                    expireTimeout: 2000
                });

                // Rapid flutter
                for (let f = 0; f < 20; ++f) {
                    NotificationService.pauseToastTimer(601);
                    NotificationService.resumeToastTimer(601);
                }

                const flutterTimer = NotificationService._toastTimers[601];
                if (!flutterTimer || !flutterTimer.running) {
                    recordFailure("Flutter_Running", "Timer should be running after resume");
                }
                if (flutterTimer && flutterTimer.remainingMs < 500) {
                    recordFailure("Flutter_RemainingClamp", "Timer remainingMs dropped below 500ms min clamp: " + flutterTimer.remainingMs);
                }

                NotificationService.dismissToast(601);
            } catch (e) {
                recordFailure("Flutter_Exception", e.toString());
            }

            // Finish after small delay
            reportTimer.start();
        }
    }

    Timer {
        id: reportTimer
        interval: 100
        repeat: false
        onTriggered: {
            console.log("\n=======================================================");
            console.log("ADVERSARIAL SUITE SUMMARY");
            console.log("=======================================================");
            console.log("Total Failures Detected: " + root.failures.length);
            for (let i = 0; i < root.failures.length; ++i) {
                console.log("FAILURE " + (i + 1) + ": [" + root.failures[i].test + "] " + root.failures[i].reason);
            }
            console.log("=======================================================");

            if (root.failures.length > 0) {
                console.log("=== ADVERSARIAL CHALLENGE RESULT: FAILURES FOUND ===");
            } else {
                console.log("=== PASS: All Adversarial Tests Passed ===");
            }
            Qt.quit();
        }
    }
}
