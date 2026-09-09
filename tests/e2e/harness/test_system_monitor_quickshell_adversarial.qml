import QtQuick
import Quickshell
import desktop.services

Scope {
    id: root

    Timer {
        interval: 10
        running: true
        repeat: false
        onTriggered: {
            try {
                if (typeof SystemMonitorService === "undefined" || !SystemMonitorService) {
                    console.error("ASSERTION_FAILED: SystemMonitorService singleton not loaded");
                    Qt.quit();
                    return;
                }

                // Verify formatBytes
                if (SystemMonitorService.formatBytes(0) !== "0 B") {
                    console.error("ASSERTION_FAILED: formatBytes(0) != 0 B");
                    Qt.quit();
                    return;
                }
                if (SystemMonitorService.formatBytes(2048) !== "2.0 KB") {
                    console.error("ASSERTION_FAILED: formatBytes(2048) != 2.0 KB");
                    Qt.quit();
                    return;
                }

                // Verify public contract properties
                if (typeof SystemMonitorService.available !== "boolean") {
                    console.error("ASSERTION_FAILED: available is not boolean");
                    Qt.quit();
                    return;
                }

                console.log("QUICKSHELL DYNAMIC ADVERSARIAL TEST PASS");
                console.log("=== PASS: SystemMonitorService live runtime harness ===");
            } catch (err) {
                console.error("ASSERTION_FAILED: " + err);
            }
            Qt.quit();
        }
    }
}
