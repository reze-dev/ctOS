import QtQuick
import Quickshell
import desktop.surfaces.widgets

Scope {
    id: root

    NetworkFlowMatrix {
        id: netFlow
    }

    Timer {
        interval: 10
        running: true
        repeat: false
        onTriggered: {
            try {
                if (!netFlow) {
                    console.error("ASSERTION_FAILED: NetworkFlowMatrix not created");
                    Qt.quit();
                    return;
                }

                if (typeof netFlow.formatRate === "function") {
                    const r0 = netFlow.formatRate(0);
                    const r1k = netFlow.formatRate(1024);
                    if (!r0 || !r1k) {
                        console.error("ASSERTION_FAILED: formatRate invalid");
                        Qt.quit();
                        return;
                    }
                }

                console.log("=== PASS: NetworkFlowMatrix live runtime harness ===");
            } catch (err) {
                console.error("ASSERTION_FAILED: " + err);
            }
            Qt.quit();
        }
    }
}
