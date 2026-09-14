import QtQuick
import QtQuick.Layouts
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

    Timer {
        id: testRunner
        interval: 50
        running: true
        repeat: false
        onTriggered: {
            console.log("================================================================");
            console.log("=== EMPIRICAL CHALLENGER VERIFICATION HARNESS (MILESTONE 2) ===");
            console.log("================================================================");

            // 1. Initial State & Geometry Verification
            assertCondition("CHAL.M2.01", "DynamicIsland instantiated successfully",
                testIsland !== null,
                "testIsland object exists");

            assertCondition("CHAL.M2.02", "DynamicIsland compactWidth is 120",
                testIsland.compactWidth === 120,
                "compactWidth=" + testIsland.compactWidth);

            assertCondition("CHAL.M2.03", "DynamicIsland expandedWidth is 300",
                testIsland.expandedWidth === 300,
                "expandedWidth=" + testIsland.expandedWidth);

            assertCondition("CHAL.M2.04", "DynamicIsland initial isExpanded is false",
                testIsland.isExpanded === false,
                "isExpanded=" + testIsland.isExpanded);

            assertCondition("CHAL.M2.05", "DynamicIsland initial width is compactWidth (120)",
                testIsland.width === 120,
                "width=" + testIsland.width);

            assertCondition("CHAL.M2.06", "DynamicIsland height is Theme.barHeight - 6 (30)",
                testIsland.height === (Theme.barHeight - 6),
                "height=" + testIsland.height + " expected=" + (Theme.barHeight - 6));

            assertCondition("CHAL.M2.07", "DynamicIsland radius is Theme.radiusPill",
                testIsland.radius === Theme.radiusPill,
                "radius=" + testIsland.radius);

            assertCondition("CHAL.M2.08", "DynamicIsland color matches Theme.background",
                testIsland.color === Theme.background,
                "color=" + testIsland.color);

            // 2. Notification Reception & Expansion Verification
            NotificationService.clearAll();
            if (NotificationService.doNotDisturb) {
                NotificationService.toggleDnd();
            }

            // Trigger notification via NotificationService
            NotificationService._handleNotification({
                id: 991,
                appName: "SecurityAudit",
                summary: "Breach Detected",
                urgency: 2
            });

            assertCondition("CHAL.M2.09", "DynamicIsland expanded on incoming notification",
                testIsland.isExpanded === true,
                "isExpanded=" + testIsland.isExpanded);

            assertCondition("CHAL.M2.10", "DynamicIsland captured latestAppName",
                testIsland.latestAppName === "SecurityAudit",
                "latestAppName=" + testIsland.latestAppName);

            assertCondition("CHAL.M2.11", "DynamicIsland captured latestSummary",
                testIsland.latestSummary === "Breach Detected",
                "latestSummary=" + testIsland.latestSummary);

            assertCondition("CHAL.M2.12", "DynamicIsland captured latestUrgency",
                testIsland.latestUrgency === 2,
                "latestUrgency=" + testIsland.latestUrgency);

            // 3. Manual / Direct method invocation
            testIsland.showNotification("NetDaemon", "Link Online", 0);
            assertCondition("CHAL.M2.13", "DynamicIsland showNotification direct invocation works",
                testIsland.latestAppName === "NetDaemon" && testIsland.latestSummary === "Link Online",
                "appName=" + testIsland.latestAppName + ", summary=" + testIsland.latestSummary);

            // Reset expansion
            testIsland.isExpanded = false;
            assertCondition("CHAL.M2.14", "DynamicIsland collapses cleanly when isExpanded = false",
                testIsland.isExpanded === false,
                "isExpanded=" + testIsland.isExpanded);

            // 4. DND Suppression Verification
            NotificationService.toggleDnd();
            assertCondition("CHAL.M2.15", "NotificationService DND active",
                NotificationService.doNotDisturb === true,
                "doNotDisturb=" + NotificationService.doNotDisturb);

            // Under DND, incoming notification should NOT trigger expansion
            NotificationService._handleNotification({
                id: 992,
                appName: "SpamApp",
                summary: "Ignored Toast",
                urgency: 0
            });

            assertCondition("CHAL.M2.16", "DynamicIsland suppresses expansion under DND",
                testIsland.isExpanded === false,
                "isExpanded=" + testIsland.isExpanded);

            // Reset DND
            NotificationService.toggleDnd();
            NotificationService.clearAll();

            console.log("================================================================");
            console.log("RESULTS: Passed=" + passCount + ", Failed=" + failCount);
            if (failCount === 0) {
                console.log("=== PASS: EMPIRICAL CHALLENGER M2 VERIFICATION SUCCESSFUL ===");
            } else {
                console.error("=== FAIL: EMPIRICAL CHALLENGER M2 VERIFICATION FAILED ===");
            }
            console.log("================================================================");

            Qt.quit();
        }
    }
}
