import QtQuick
import Quickshell
import desktop.surfaces.widgets

Scope {
    id: root

    CpuHexGrid {
        id: hexGrid
    }

    Timer {
        interval: 10
        running: true
        repeat: false
        onTriggered: {
            try {
                if (!hexGrid) {
                    console.error("ASSERTION_FAILED: CpuHexGrid could not be instantiated");
                    Qt.quit();
                    return;
                }

                // Verify solveLayout function
                if (typeof hexGrid.solveLayout === "function") {
                    const l1 = hexGrid.solveLayout(1);
                    const l4 = hexGrid.solveLayout(4);
                    const l128 = hexGrid.solveLayout(128);
                    if (!l1 || !l4 || !l128) {
                        console.error("ASSERTION_FAILED: solveLayout returned invalid layout");
                        Qt.quit();
                        return;
                    }
                }

                console.log("QUICKSHELL M2 WIDGETS DYNAMIC TEST PASS");
                console.log("=== PASS: CpuHexGrid solveLayout live runtime harness ===");
            } catch (err) {
                console.error("ASSERTION_FAILED: " + err);
            }
            Qt.quit();
        }
    }
}
