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
        id: testContainer
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
            console.log("=== BEGIN ADVERSARIAL STRESS SUITE FOR EventLog Surface ===");
            NotificationService.clearAll();

            // -------------------------------------------------------------
            // TEST 1: Rapid 50 Notifications & Rendering Stability
            // -------------------------------------------------------------
            try {
                console.log("-> Running Test 1: Rapid 50 Notifications & Scrolling...");
                for (let i = 1; i <= 50; ++i) {
                    NotificationService._handleNotification({
                        id: 500 + i,
                        appName: "Daemon" + i,
                        summary: "Service alert sequence " + i,
                        body: "Telemetry payload data stream status index " + i + " active.",
                        urgency: i % 3
                    });
                }

                if (NotificationService.history.count !== 50) {
                    recordFailure("Batch_Insert", "Expected 50 items in history, got " + NotificationService.history.count);
                }
            } catch (e) {
                recordFailure("Batch_Insert_Exception", e.toString());
            }

            // -------------------------------------------------------------
            // TEST 2: Boundary Dismissals (Out-of-bounds index safety)
            // -------------------------------------------------------------
            try {
                console.log("-> Running Test 2: Boundary Dismissals (-1, 999)...");
                NotificationService.dismissHistoryItem(-1);
                NotificationService.dismissHistoryItem(999);
                if (NotificationService.history.count !== 50) {
                    recordFailure("OutOfBounds_Dismiss", "Invalid dismissal modified history count: " + NotificationService.history.count);
                }
            } catch (e) {
                recordFailure("OutOfBounds_Exception", e.toString());
            }

            // -------------------------------------------------------------
            // TEST 3: Extreme Content (Cyber glyphs, long texts, HTML tags)
            // -------------------------------------------------------------
            try {
                console.log("-> Running Test 3: Extreme Content Stress...");
                NotificationService._handleNotification({
                    id: 777,
                    appName: "SYSTEM//OVERFLOW_LONG_APP_NAME_EXCEEDING_STANDARD_WIDTH_LIMITS",
                    summary: "VERY_LONG_UNBROKEN_STRING_AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA",
                    body: "Line 1: ░▒▓█ CYBERPUNK GLYPHS █▓▒░\nLine 2: <b>Markup</b> <script>alert(1)</script> &amp; entity\nLine 3: Third line of text\nLine 4: This fourth line should be clamped by maximumLineCount: 3",
                    urgency: 2
                });

                if (NotificationService.history.count !== 51) {
                    recordFailure("Extreme_Content", "Failed to insert extreme content notification");
                }
            } catch (e) {
                recordFailure("Extreme_Content_Exception", e.toString());
            }

            // -------------------------------------------------------------
            // TEST 4: Rapid DND Toggling Under High Notification Load
            // -------------------------------------------------------------
            try {
                console.log("-> Running Test 4: Rapid DND Toggling...");
                for (let k = 0; k < 20; ++k) {
                    NotificationService.toggleDnd();
                }
                if (NotificationService.doNotDisturb !== false) {
                    recordFailure("DND_Parity", "Expected DND to return to false after 20 toggles");
                }
            } catch (e) {
                recordFailure("DND_Exception", e.toString());
            }

            // -------------------------------------------------------------
            // TEST 5: Bulk Sequential Dismissal down to 0
            // -------------------------------------------------------------
            try {
                console.log("-> Running Test 5: Bulk Sequential Dismissals...");
                while (NotificationService.history.count > 0) {
                    NotificationService.dismissHistoryItem(0);
                }
                if (NotificationService.history.count !== 0) {
                    recordFailure("Sequential_Dismiss", "Expected 0 items after emptying history, got " + NotificationService.history.count);
                }
            } catch (e) {
                recordFailure("Sequential_Dismiss_Exception", e.toString());
            }

            // -------------------------------------------------------------
            // TEST 6: Clear All on already empty history
            // -------------------------------------------------------------
            try {
                console.log("-> Running Test 6: Idempotent ClearAll...");
                NotificationService.clearAll();
                NotificationService.clearAll();
                if (NotificationService.history.count !== 0) {
                    recordFailure("Idempotent_ClearAll", "Count should remain 0 after multiple clearAll calls");
                }
            } catch (e) {
                recordFailure("ClearAll_Exception", e.toString());
            }

            // Final Evaluation
            if (failures.length === 0) {
                console.log("=== PASS: T8 EventLog Surface Adversarial Suite ===");
            } else {
                console.error("=== FAIL: " + failures.length + " ADVERSARIAL CHECKS FAILED ===");
                for (let f = 0; f < failures.length; ++f) {
                    console.error("  FAIL [" + failures[f].test + "]: " + failures[f].reason);
                }
            }
            Qt.quit();
        }
    }
}
