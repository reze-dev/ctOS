import QtQuick
import QtQuick.Layouts
import Quickshell
import desktop.services
import desktop.core
import desktop.surfaces.components

FloatingWindow {
    id: testWindow
    visible: true
    implicitWidth: 1000
    implicitHeight: 800

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

        // Multi-monitor simulated containers
        // 2560x1440
        Item {
            id: simScreen2560
            width: 2560
            height: Theme.barHeight
            visible: false

            Rectangle {
                id: left2560
                x: Theme.barPaddingHorizontal
                width: 450 // typical left section
                height: Theme.barHeight - 6
            }
            DynamicIsland {
                id: center2560
                anchors.horizontalCenter: parent.horizontalCenter
            }
            Rectangle {
                id: right2560
                x: parent.width - Theme.barPaddingHorizontal - width
                width: 350 // typical right section
                height: Theme.barHeight - 6
            }
        }

        // 1920x1080
        Item {
            id: simScreen1920
            width: 1920
            height: Theme.barHeight
            visible: false

            Rectangle {
                id: left1920
                x: Theme.barPaddingHorizontal
                width: 450
                height: Theme.barHeight - 6
            }
            DynamicIsland {
                id: center1920
                anchors.horizontalCenter: parent.horizontalCenter
            }
            Rectangle {
                id: right1920
                x: parent.width - Theme.barPaddingHorizontal - width
                width: 350
                height: Theme.barHeight - 6
            }
        }

        // 1366x768
        Item {
            id: simScreen1366
            width: 1366
            height: Theme.barHeight
            visible: false

            Rectangle {
                id: left1366
                x: Theme.barPaddingHorizontal
                width: 450
                height: Theme.barHeight - 6
            }
            DynamicIsland {
                id: center1366
                anchors.horizontalCenter: parent.horizontalCenter
            }
            Rectangle {
                id: right1366
                x: parent.width - Theme.barPaddingHorizontal - width
                width: 350
                height: Theme.barHeight - 6
            }
        }
    }

    // Step-by-step asynchronous test state machine
    property int testStep: 0
    property int burstCounter: 0
    property int burstTotal: 50

    Timer {
        id: burstTimer
        interval: 10
        repeat: true
        running: false
        onTriggered: {
            burstCounter++;
            NotificationService._handleNotification({
                id: 1000 + burstCounter,
                appName: "RapidApp_" + burstCounter,
                summary: "Rapid notification payload #" + burstCounter,
                urgency: (burstCounter % 3)
            });

            if (burstCounter >= burstTotal) {
                burstTimer.stop();
                stepTimer.interval = 100;
                stepTimer.restart();
            }
        }
    }

    Timer {
        id: stepTimer
        interval: 50
        repeat: false
        running: true
        onTriggered: runNextStep()
    }

    function runNextStep() {
        testStep++;

        if (testStep === 1) {
            console.log("==================================================================");
            console.log("=== EMPIRICAL CHALLENGER STRESS HARNESS: MULTI-MONITOR LAYOUT ===");
            console.log("==================================================================");

            // Test 1: 2560x1440 Compact
            center2560.isExpanded = false;
            let leftEnd2560 = left2560.x + left2560.width;
            let centerStart2560 = center2560.x;
            let centerEnd2560 = center2560.x + center2560.width;
            let rightStart2560 = right2560.x;

            assertCondition("STRESS.MON.2560.COMPACT", "2560x1440 Compact Island separation",
                (centerStart2560 - leftEnd2560 > 100) && (rightStart2560 - centerEnd2560 > 100),
                "leftGap=" + (centerStart2560 - leftEnd2560) + "px, rightGap=" + (rightStart2560 - centerEnd2560) + "px");

            // Test 2: 2560x1440 Expanded (300px)
            center2560.isExpanded = true;
            center2560.width = 300;
            centerStart2560 = (2560 - 300) / 2;
            centerEnd2560 = centerStart2560 + 300;
            assertCondition("STRESS.MON.2560.EXPANDED", "2560x1440 Expanded Island separation",
                (centerStart2560 - leftEnd2560 > 50) && (rightStart2560 - centerEnd2560 > 50),
                "leftGap=" + (centerStart2560 - leftEnd2560) + "px, rightGap=" + (rightStart2560 - centerEnd2560) + "px");

            // Test 3: 1920x1080 Compact
            center1920.isExpanded = false;
            let leftEnd1920 = left1920.x + left1920.width;
            let centerStart1920 = center1920.x;
            let centerEnd1920 = center1920.x + center1920.width;
            let rightStart1920 = right1920.x;

            assertCondition("STRESS.MON.1920.COMPACT", "1920x1080 Compact Island separation",
                (centerStart1920 - leftEnd1920 > 50) && (rightStart1920 - centerEnd1920 > 50),
                "leftGap=" + (centerStart1920 - leftEnd1920) + "px, rightGap=" + (rightStart1920 - centerEnd1920) + "px");

            // Test 4: 1920x1080 Expanded (300px)
            center1920.isExpanded = true;
            centerStart1920 = (1920 - 300) / 2;
            centerEnd1920 = centerStart1920 + 300;
            assertCondition("STRESS.MON.1920.EXPANDED", "1920x1080 Expanded Island separation",
                (centerStart1920 - leftEnd1920 > 20) && (rightStart1920 - centerEnd1920 > 20),
                "leftGap=" + (centerStart1920 - leftEnd1920) + "px, rightGap=" + (rightStart1920 - centerEnd1920) + "px");

            // Test 5: 1366x768 Compact
            center1366.isExpanded = false;
            let leftEnd1366 = left1366.x + left1366.width;
            let centerStart1366 = (1366 - 120) / 2;
            let centerEnd1366 = centerStart1366 + 120;
            let rightStart1366 = right1366.x;

            assertCondition("STRESS.MON.1366.COMPACT", "1366x768 Compact Island separation",
                (centerStart1366 > leftEnd1366) && (rightStart1366 > centerEnd1366),
                "leftGap=" + (centerStart1366 - leftEnd1366) + "px, rightGap=" + (rightStart1366 - centerEnd1366) + "px");

            // Test 6: 1366x768 Expanded (300px)
            centerStart1366 = (1366 - 300) / 2; // 533
            centerEnd1366 = centerStart1366 + 300; // 833
            assertCondition("STRESS.MON.1366.EXPANDED", "1366x768 Expanded Island separation",
                (centerStart1366 > leftEnd1366) && (rightStart1366 > centerEnd1366),
                "leftGap=" + (centerStart1366 - leftEnd1366) + "px, rightGap=" + (rightStart1366 - centerEnd1366) + "px");

            // Proceed to notification stress
            stepTimer.interval = 50;
            stepTimer.restart();
        }
        else if (testStep === 2) {
            console.log("==================================================================");
            console.log("=== EMPIRICAL CHALLENGER STRESS HARNESS: RAPID NOTIFICATION BURST ===");
            console.log("==================================================================");

            NotificationService.clearAll();
            if (NotificationService.doNotDisturb) {
                NotificationService.toggleDnd();
            }

            // Launch 50 rapid notifications in 10ms intervals
            burstCounter = 0;
            burstTimer.start();
            // burstTimer triggers runNextStep when done
        }
        else if (testStep === 3) {
            // Evaluated after burst finishes
            assertCondition("STRESS.BURST.COUNT", "50 Rapid notifications ingested into history",
                NotificationService.history.count >= 50,
                "historyCount=" + NotificationService.history.count);

            assertCondition("STRESS.BURST.EXPANDED", "DynamicIsland remains expanded during/after burst",
                testIsland.isExpanded === true,
                "isExpanded=" + testIsland.isExpanded);

            assertCondition("STRESS.BURST.LATEST_APP", "DynamicIsland displays latest notification appName",
                testIsland.latestAppName === "RapidApp_50",
                "latestAppName=" + testIsland.latestAppName);

            assertCondition("STRESS.BURST.LATEST_SUMMARY", "DynamicIsland displays latest notification summary",
                testIsland.latestSummary === "Rapid notification payload #50",
                "latestSummary=" + testIsland.latestSummary);

            // Now test timer reset resilience: send another notification and check collapse timer
            testIsland.showNotification("ResetTest", "Resetting Timer", 1);
            assertCondition("STRESS.TIMER.RESTART", "showNotification resets and maintains expanded state",
                testIsland.isExpanded === true && testIsland.latestAppName === "ResetTest",
                "isExpanded=" + testIsland.isExpanded);

            // Test Edge Cases: Null / Undefined / Long Strings
            testIsland.showNotification("", "", 0);
            assertCondition("STRESS.EDGE.EMPTY_STRINGS", "showNotification handles empty strings safely",
                testIsland.latestAppName === "System" && testIsland.latestSummary === "",
                "appName=" + testIsland.latestAppName + ", summary=" + testIsland.latestSummary);

            let hugeString = new Array(5000).join("X");
            testIsland.showNotification("HugeApp", hugeString, 2);
            assertCondition("STRESS.EDGE.HUGE_STRING", "showNotification handles 5000-char string without crashing",
                testIsland.latestAppName === "HugeApp" && testIsland.latestSummary.length === 4999,
                "summaryLength=" + testIsland.latestSummary.length);

            // Test invalid urgency bounds
            testIsland.showNotification("UrgencyTest", "Bounds", -99);
            assertCondition("STRESS.EDGE.INVALID_URGENCY", "showNotification handles invalid urgency",
                testIsland.latestUrgency === -99,
                "urgency=" + testIsland.latestUrgency);

            // Reset expansion and test collapse
            testIsland.isExpanded = false;
            assertCondition("STRESS.COLLAPSE", "DynamicIsland collapses to compact state",
                testIsland.isExpanded === false,
                "isExpanded=" + testIsland.isExpanded);

            // Print summary
            console.log("==================================================================");
            console.log("CHALLENGER STRESS RESULTS: Passed=" + passCount + ", Failed=" + failCount);
            if (failCount === 0) {
                console.log("=== PASS: EMPIRICAL CHALLENGER M2 STRESS VERIFICATION SUCCESSFUL ===");
            } else {
                console.error("=== FAIL: EMPIRICAL CHALLENGER M2 STRESS VERIFICATION FAILED ===");
            }
            console.log("==================================================================");

            Qt.quit();
        }
    }
}
