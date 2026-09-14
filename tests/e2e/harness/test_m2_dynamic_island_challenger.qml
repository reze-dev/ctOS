pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtTest
import Quickshell
import desktop.services
import desktop.core
import desktop.surfaces.components

FloatingWindow {
    id: testWindow
    visible: true
    implicitWidth: 800
    implicitHeight: 600

    property var results: []
    property int passCount: 0
    property int failCount: 0

    function assertCondition(id, name, condition, details) {
        if (condition) {
            passCount++;
            console.log("[PASS] " + id + ": " + name + " (" + details + ")");
            results.push({ id: id, name: name, passed: true, details: details });
        } else {
            failCount++;
            console.error("[FAIL] " + id + ": " + name + " (" + details + ")");
            results.push({ id: id, name: name, passed: false, details: details });
        }
    }

    Item {
        id: testContainer
        anchors.fill: parent

        DynamicIsland {
            id: testIsland
            anchors.centerIn: parent
        }
    }

    TestCase {
        id: tc
        name: "DynamicIslandTestHelper"
        when: false
    }

    // Sequencer for multi-step empirical tests
    property int currentPhase: 0

    Timer {
        id: phaseTimer
        interval: 50
        running: true
        repeat: false
        onTriggered: runPhase()
    }

    function scheduleNext(delayMs, phaseNumber) {
        currentPhase = phaseNumber;
        phaseTimer.interval = delayMs;
        phaseTimer.restart();
    }

    function runPhase() {
        switch (currentPhase) {
            case 0:
                console.log("================================================================");
                console.log("=== EMPIRICAL CHALLENGER: DYNAMIC ISLAND STRESS HARNESS ===");
                console.log("================================================================");
                console.log("--- PHASE 1: Compact Width & State Visual Verification ---");

                // Reset state
                NotificationService.clearAll();
                if (NotificationService.doNotDisturb) {
                    NotificationService.toggleDnd();
                }
                OverlayController.close();

                // Test 1.1: Idle state
                assertCondition("CHAL.M2.DI.01", "DynamicIsland initial width is compactWidth (120)",
                    testIsland.width === 120 && testIsland.compactWidth === 120,
                    "width=" + testIsland.width + ", compactWidth=" + testIsland.compactWidth);

                assertCondition("CHAL.M2.DI.02", "DynamicIsland initial height is Theme.barHeight - 6 (30)",
                    testIsland.height === (Theme.barHeight - 6),
                    "height=" + testIsland.height + ", expected=" + (Theme.barHeight - 6));

                assertCondition("CHAL.M2.DI.03", "DynamicIsland radius is Theme.radiusPill (9999)",
                    testIsland.radius === Theme.radiusPill,
                    "radius=" + testIsland.radius);

                assertCondition("CHAL.M2.DI.04", "DynamicIsland idle state unreadCount is 0",
                    NotificationService.unreadCount === 0,
                    "unreadCount=" + NotificationService.unreadCount);

                // Test 1.2: Unread notifications state
                NotificationService._handleNotification({
                    id: 101,
                    appName: "Audit",
                    summary: "Unread item 1",
                    urgency: 1
                });
                // Manually collapse immediately to test compact state with unreadCount > 0
                testIsland.isExpanded = false;

                assertCondition("CHAL.M2.DI.05", "DynamicIsland compact width maintained with unread notifications",
                    testIsland.compactWidth === 120,
                    "compactWidth=" + testIsland.compactWidth + ", unreadCount=" + NotificationService.unreadCount);

                assertCondition("CHAL.M2.DI.06", "NotificationService unreadCount is 1",
                    NotificationService.unreadCount === 1,
                    "unreadCount=" + NotificationService.unreadCount);

                // Test 1.3: DND state
                NotificationService.toggleDnd();
                assertCondition("CHAL.M2.DI.07", "DynamicIsland compact width maintained under DND",
                    testIsland.compactWidth === 120 && NotificationService.doNotDisturb === true,
                    "compactWidth=" + testIsland.compactWidth + ", DND=" + NotificationService.doNotDisturb);

                // Reset for Phase 2
                NotificationService.toggleDnd();
                NotificationService.clearAll();
                testIsland.isExpanded = false;

                // Move to Phase 2: Notification arrival and expansion animation
                scheduleNext(100, 1);
                break;

            case 1:
                console.log("--- PHASE 2: Notification Arrival & Expansion to 300px ---");

                assertCondition("CHAL.M2.DI.08", "Pre-notification state is collapsed",
                    testIsland.isExpanded === false && testIsland.width === 120,
                    "isExpanded=" + testIsland.isExpanded + ", width=" + testIsland.width);

                // Incoming notification
                NotificationService._handleNotification({
                    id: 201,
                    appName: "SecuritySubsystem",
                    summary: "Kernel Memory Integrity Verified",
                    urgency: 2
                });

                assertCondition("CHAL.M2.DI.09", "isExpanded immediately becomes true on notification",
                    testIsland.isExpanded === true,
                    "isExpanded=" + testIsland.isExpanded);

                assertCondition("CHAL.M2.DI.10", "latestAppName correctly captured",
                    testIsland.latestAppName === "SecuritySubsystem",
                    "latestAppName=" + testIsland.latestAppName);

                assertCondition("CHAL.M2.DI.11", "latestSummary correctly captured",
                    testIsland.latestSummary === "Kernel Memory Integrity Verified",
                    "latestSummary=" + testIsland.latestSummary);

                assertCondition("CHAL.M2.DI.12", "latestUrgency correctly captured",
                    testIsland.latestUrgency === 2,
                    "latestUrgency=" + testIsland.latestUrgency);

                // Wait 400ms for width animation (durationSlow = 300ms) to complete
                scheduleNext(400, 2);
                break;

            case 2:
                console.log("--- PHASE 3: Verify Expanded Width Reaches 300px ---");

                assertCondition("CHAL.M2.DI.13", "DynamicIsland animated width reached expandedWidth (300px)",
                    Math.round(testIsland.width) === 300,
                    "width=" + testIsland.width + ", expected=300");

                // Check midpoint of 4000ms auto-collapse timer (at t ≈ 2000ms after notif)
                // We are already at ~500ms since notif, wait 1500ms more (to reach ~2000ms)
                scheduleNext(1500, 3);
                break;

            case 3:
                console.log("--- PHASE 4: Midpoint of Auto-Collapse Timer (~2000ms) ---");

                assertCondition("CHAL.M2.DI.14", "DynamicIsland remains expanded at midpoint (t ≈ 2000ms)",
                    testIsland.isExpanded === true && Math.round(testIsland.width) === 300,
                    "isExpanded=" + testIsland.isExpanded + ", width=" + testIsland.width);

                // Wait until t ≈ 4300ms after notification (wait 2300ms) to allow 4000ms timer to fire
                scheduleNext(2300, 4);
                break;

            case 4:
                console.log("--- PHASE 5: Auto-Collapse Expiration (t > 4000ms) ---");

                assertCondition("CHAL.M2.DI.15", "DynamicIsland auto-collapses after 4000ms (isExpanded == false)",
                    testIsland.isExpanded === false,
                    "isExpanded=" + testIsland.isExpanded);

                // Wait 400ms for collapse animation to settle back to 120px
                scheduleNext(400, 5);
                break;

            case 5:
                console.log("--- PHASE 6: Verify Settled Compact Width (120px) After Collapse ---");

                assertCondition("CHAL.M2.DI.16", "DynamicIsland width settled back to compactWidth (120px)",
                    Math.round(testIsland.width) === 120,
                    "width=" + testIsland.width + ", expected=120");

                // Test Phase 7: Consecutive Notifications & Timer Reset
                console.log("--- PHASE 7: Consecutive Notifications & Timer Reset Test ---");
                NotificationService._handleNotification({
                    id: 301,
                    appName: "AlphaService",
                    summary: "Message One",
                    urgency: 1
                });

                assertCondition("CHAL.M2.DI.17", "First notification triggers expansion",
                    testIsland.isExpanded === true && testIsland.latestAppName === "AlphaService",
                    "isExpanded=" + testIsland.isExpanded + ", app=" + testIsland.latestAppName);

                // Wait 2000ms, then fire second notification
                scheduleNext(2000, 6);
                break;

            case 6:
                // Fire second notification at t = 2000ms
                NotificationService._handleNotification({
                    id: 302,
                    appName: "BetaService",
                    summary: "Message Two Extended",
                    urgency: 2
                });

                assertCondition("CHAL.M2.DI.18", "Second notification updates summary while expanded",
                    testIsland.isExpanded === true && testIsland.latestAppName === "BetaService" && testIsland.latestSummary === "Message Two Extended",
                    "app=" + testIsland.latestAppName + ", summary=" + testIsland.latestSummary);

                // At t = 2200ms after second notification (t = 4200ms after first notif):
                // If timer did not reset, it would have collapsed. With reset, it must still be expanded!
                scheduleNext(2200, 7);
                break;

            case 7:
                assertCondition("CHAL.M2.DI.19", "Timer reset prevents premature collapse (still expanded at t = 2200ms post-notif-2)",
                    testIsland.isExpanded === true,
                    "isExpanded=" + testIsland.isExpanded);

                // Wait 2200ms more (t = 4400ms after second notification) -> should now be collapsed
                scheduleNext(2200, 8);
                break;

            case 8:
                assertCondition("CHAL.M2.DI.20", "DynamicIsland collapsed after reset timer expired (t > 4000ms post-notif-2)",
                    testIsland.isExpanded === false,
                    "isExpanded=" + testIsland.isExpanded);

                // Phase 9: Click Handling & Event Log Routing
                scheduleNext(100, 9);
                break;

            case 9:
                console.log("--- PHASE 8: Click Handling & Event Log Overlay Routing ---");
                OverlayController.close();

                // Find mouseArea inside testIsland
                let mouseArea = null;
                for (let i = 0; i < testIsland.children.length; i++) {
                    if (testIsland.children[i].toString().indexOf("QQuickMouseArea") !== -1) {
                        mouseArea = testIsland.children[i];
                        break;
                    }
                }

                assertCondition("CHAL.M2.DI.21", "DynamicIsland MouseArea exists and is enabled",
                    mouseArea !== null && mouseArea.enabled === true,
                    "mouseArea=" + mouseArea);

                // Test 9.1: Left Click when collapsed toggles EventLog
                assertCondition("CHAL.M2.DI.22", "Overlay initially None",
                    OverlayController.activeSurface === OverlayController.Surface.None,
                    "activeSurface=" + OverlayController.activeSurface);

                tc.mouseClick(testIsland, testIsland.width / 2, testIsland.height / 2, Qt.LeftButton);

                assertCondition("CHAL.M2.DI.23", "Left click when compact opened EventLog overlay (surface 3)",
                    OverlayController.activeSurface === OverlayController.Surface.EventLog,
                    "activeSurface=" + OverlayController.activeSurface + " (EventLog=3)");

                // Test 9.2: Left Click when already open closes/toggles
                tc.mouseClick(testIsland, testIsland.width / 2, testIsland.height / 2, Qt.LeftButton);

                assertCondition("CHAL.M2.DI.24", "Second left click toggled EventLog off (surface None)",
                    OverlayController.activeSurface === OverlayController.Surface.None,
                    "activeSurface=" + OverlayController.activeSurface);

                // Test 9.3: Left Click during expanded state opens EventLog and collapses island
                testIsland.showNotification("UrgentAlert", "System Error", 2);
                assertCondition("CHAL.M2.DI.25", "DynamicIsland expanded prior to click",
                    testIsland.isExpanded === true,
                    "isExpanded=" + testIsland.isExpanded);

                tc.mouseClick(testIsland, testIsland.width / 2, testIsland.height / 2, Qt.LeftButton);

                assertCondition("CHAL.M2.DI.26", "Click while expanded opened EventLog (surface 3)",
                    OverlayController.activeSurface === OverlayController.Surface.EventLog,
                    "activeSurface=" + OverlayController.activeSurface);

                assertCondition("CHAL.M2.DI.27", "Click while expanded immediately collapses island",
                    testIsland.isExpanded === false,
                    "isExpanded=" + testIsland.isExpanded);

                OverlayController.close();

                // Test 9.4: Right click toggles DND
                let dndBefore = NotificationService.doNotDisturb;
                tc.mouseClick(testIsland, testIsland.width / 2, testIsland.height / 2, Qt.RightButton);
                assertCondition("CHAL.M2.DI.28", "Right click toggled DND to opposite state",
                    NotificationService.doNotDisturb === !dndBefore,
                    "dndBefore=" + dndBefore + ", dndAfter=" + NotificationService.doNotDisturb);

                // Toggle back
                tc.mouseClick(testIsland, testIsland.width / 2, testIsland.height / 2, Qt.RightButton);
                assertCondition("CHAL.M2.DI.29", "Right click restored DND to false",
                    NotificationService.doNotDisturb === false,
                    "DND=" + NotificationService.doNotDisturb);

                // Phase 10: Adversarial Edge Cases
                scheduleNext(100, 10);
                break;

            case 10:
                console.log("--- PHASE 9: Adversarial Edge Cases ---");

                // Adversarial 1: Empty / Null Strings
                testIsland.showNotification("", "", 0);
                assertCondition("CHAL.M2.DI.30", "Handles empty appName and summary gracefully",
                    testIsland.isExpanded === true && testIsland.latestAppName === "System" && testIsland.latestSummary === "",
                    "appName=" + testIsland.latestAppName + ", summary=" + testIsland.latestSummary);

                // Adversarial 2: Extremely long string (10,000 chars)
                let longStr = "A".repeat(10000);
                testIsland.showNotification("HugeApp", longStr, 1);
                assertCondition("CHAL.M2.DI.31", "Handles 10,000 char summary without expanding beyond 300px",
                    testIsland.expandedWidth === 300 && testIsland.latestSummary.length === 10000,
                    "expandedWidth=" + testIsland.expandedWidth + ", summaryLen=" + testIsland.latestSummary.length);

                // Adversarial 3: DND suppresses expansion
                testIsland.isExpanded = false;
                NotificationService.toggleDnd();
                NotificationService._handleNotification({
                    id: 401,
                    appName: "SpamBot",
                    summary: "Under DND - Should NOT expand",
                    urgency: 1
                });
                assertCondition("CHAL.M2.DI.32", "DynamicIsland suppresses expansion under DND",
                    testIsland.isExpanded === false,
                    "isExpanded=" + testIsland.isExpanded + ", DND=" + NotificationService.doNotDisturb);

                NotificationService.toggleDnd();

                // Adversarial 4: Burst spam of 50 notifications in rapid loop
                for (let b = 500; b < 550; b++) {
                    NotificationService._handleNotification({
                        id: b,
                        appName: "BurstApp" + b,
                        summary: "Burst notification payload " + b,
                        urgency: (b % 3)
                    });
                }
                assertCondition("CHAL.M2.DI.33", "Survives rapid 50-notification burst",
                    testIsland.isExpanded === true && testIsland.latestAppName === "BurstApp549",
                    "latestAppName=" + testIsland.latestAppName + ", historyCount=" + NotificationService.history.count);

                // Clean up
                NotificationService.clearAll();
                testIsland.isExpanded = false;
                OverlayController.close();

                console.log("================================================================");
                console.log("RESULTS: Passed=" + passCount + ", Failed=" + failCount);
                if (failCount === 0) {
                    console.log("=== PASS: DYNAMIC ISLAND EMPIRICAL STRESS TEST SUCCESSFUL ===");
                } else {
                    console.error("=== FAIL: DYNAMIC ISLAND EMPIRICAL STRESS TEST FAILED ===");
                }
                console.log("================================================================");

                Qt.quit();
                break;
        }
    }
}
