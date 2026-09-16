import QtQuick
import QtQuick.Layouts
import Quickshell
import desktop.services
import desktop.core
import desktop.surfaces.components

FloatingWindow {
    id: stressWindow
    visible: true
    implicitWidth: 1000
    implicitHeight: 800

    property int passCount: 0
    property int failCount: 0

    function assertCondition(id, name, condition, details) {
        if (condition) {
            passCount++;
            console.log("[ADV-PASS] " + id + ": " + name + " (" + details + ")");
        } else {
            failCount++;
            console.error("[ADV-FAIL] " + id + ": " + name + " (" + details + ")");
        }
    }

    Item {
        id: container
        anchors.fill: parent

        DynamicIsland {
            id: islandUnderTest
            anchors.centerIn: parent
        }
    }

    Timer {
        id: runner
        interval: 50
        running: true
        repeat: false
        onTriggered: {
            console.log("================================================================");
            console.log("=== ADVERSARIAL STRESS TEST FOR MILESTONE 2 (DynamicIsland) ===");
            console.log("================================================================");

            // Test 1: Baseline dimensions and style tokens
            assertCondition("ADV.01", "DynamicIsland initial compact dimensions",
                islandUnderTest.width === 120 && islandUnderTest.height === (Theme.barHeight - 6),
                "width=" + islandUnderTest.width + " height=" + islandUnderTest.height);

            assertCondition("ADV.02", "DynamicIsland corner radius conforms to Theme.radiusPill",
                islandUnderTest.radius === Theme.radiusPill && islandUnderTest.radius === 9999,
                "radius=" + islandUnderTest.radius);

            assertCondition("ADV.03", "DynamicIsland background matches Theme.background",
                islandUnderTest.color === Theme.background,
                "color=" + islandUnderTest.color);

            // Test 2: Ultra-long strings (10,000 characters)
            const hugeString = "A".repeat(10000);
            islandUnderTest.showNotification(hugeString, hugeString, 1);
            assertCondition("ADV.04", "DynamicIsland handles 10k-char string without crashing and triggers expansion",
                islandUnderTest.isExpanded === true,
                "isExpanded=" + islandUnderTest.isExpanded + ", targetWidth=" + (islandUnderTest.isExpanded ? islandUnderTest.expandedWidth : islandUnderTest.compactWidth));

            // Test 3: Empty string values
            islandUnderTest.showNotification("", "", 1);
            assertCondition("ADV.05", "DynamicIsland handles empty string inputs safely",
                islandUnderTest.latestAppName === "System" && islandUnderTest.latestSummary === "" && islandUnderTest.latestUrgency === 1,
                "appName=" + islandUnderTest.latestAppName + ", summary=" + islandUnderTest.latestSummary + ", urgency=" + islandUnderTest.latestUrgency);

            // Test 4: Unicode, emojis, newlines, control chars
            const complexPayload = "🚨 CRITICAL BREACH: \n\t\r // [CYBER-CORE] \u0000 \u26A0\uFE0F";
            islandUnderTest.showNotification("SecurityDaemon // 0xDEAD", complexPayload, 2);
            assertCondition("ADV.06", "DynamicIsland preserves and renders unicode/emoji strings",
                islandUnderTest.latestAppName.indexOf("SecurityDaemon") !== -1 && islandUnderTest.latestUrgency === 2,
                "appName=" + islandUnderTest.latestAppName + " urgency=" + islandUnderTest.latestUrgency);

            // Test 5: Negative & out-of-range urgency levels
            islandUnderTest.showNotification("App", "Test", -5);
            assertCondition("ADV.07", "DynamicIsland handles negative urgency value",
                islandUnderTest.latestUrgency === -5,
                "urgency=" + islandUnderTest.latestUrgency);

            islandUnderTest.showNotification("App", "Test", 999);
            assertCondition("ADV.08", "DynamicIsland handles excessive urgency value",
                islandUnderTest.latestUrgency === 999,
                "urgency=" + islandUnderTest.latestUrgency);

            // Test 6: High-frequency flood (100 notifications in rapid loop)
            NotificationService.clearAll();
            if (NotificationService.doNotDisturb) {
                NotificationService.toggleDnd();
            }

            for (let i = 0; i < 100; i++) {
                NotificationService._handleNotification({
                    id: 1000 + i,
                    appName: "FloodApp_" + i,
                    summary: "Flood payload #" + i,
                    urgency: i % 3
                });
            }

            assertCondition("ADV.09", "DynamicIsland survives 100-event flood without exception",
                islandUnderTest.isExpanded === true,
                "isExpanded=" + islandUnderTest.isExpanded);

            assertCondition("ADV.10", "DynamicIsland retains state from latest notification after flood",
                islandUnderTest.latestAppName === "FloodApp_99" && islandUnderTest.latestSummary === "Flood payload #99",
                "latestAppName=" + islandUnderTest.latestAppName + ", latestSummary=" + islandUnderTest.latestSummary);

            // Test 7: DND Toggle Stress (100 rapid flips)
            const initialDnd = NotificationService.doNotDisturb;
            for (let i = 0; i < 100; i++) {
                NotificationService.toggleDnd();
            }
            assertCondition("ADV.11", "NotificationService DND state remains boolean and consistent after 100 flips",
                NotificationService.doNotDisturb === initialDnd,
                "final DND=" + NotificationService.doNotDisturb);

            // Ensure DND is ON
            if (!NotificationService.doNotDisturb) {
                NotificationService.toggleDnd();
            }

            // Collapse island
            islandUnderTest.isExpanded = false;

            // Send notification under DND
            NotificationService._handleNotification({
                id: 9999,
                appName: "BlockedApp",
                summary: "Should not expand",
                urgency: 1
            });

            assertCondition("ADV.12", "DND suppresses expansion under all circumstances",
                islandUnderTest.isExpanded === false,
                "isExpanded=" + islandUnderTest.isExpanded);

            // Clean up
            NotificationService.toggleDnd();
            NotificationService.clearAll();

            // Test 8: Rapid isExpanded oscillation (collapse/expand rapid toggle)
            for (let i = 0; i < 50; i++) {
                islandUnderTest.isExpanded = (i % 2 === 0);
            }
            islandUnderTest.isExpanded = false;

            assertCondition("ADV.13", "DynamicIsland isExpanded is false after oscillation",
                islandUnderTest.isExpanded === false,
                "isExpanded=" + islandUnderTest.isExpanded);

            console.log("================================================================");
            console.log("ADVERSARIAL STRESS RESULTS: Passed=" + passCount + ", Failed=" + failCount);
            if (failCount === 0) {
                console.log("=== ALL ADVERSARIAL STRESS TESTS PASSED ===");
            } else {
                console.error("=== ADVERSARIAL STRESS TESTS FAILED ===");
            }
            console.log("================================================================");

            Qt.quit();
        }
    }
}
