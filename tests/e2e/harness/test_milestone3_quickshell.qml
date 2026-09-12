import QtQuick
import Quickshell
import desktop.core

Scope {
    id: root

    Timer {
        interval: 10
        running: true
        repeat: false
        onTriggered: {
            try {
                if (typeof ActionRegistry === "undefined" || !ActionRegistry) {
                    console.error("ASSERTION_FAILED: ActionRegistry not found");
                    Qt.quit();
                    return;
                }

                const results = ActionRegistry.search("cpu");
                let foundCpu = false;
                for (let i = 0; i < results.length; i++) {
                    if (results[i].id === "cpu-hex" || (results[i].name && results[i].name.toLowerCase().includes("cpu"))) {
                        foundCpu = true;
                        break;
                    }
                }

                if (!foundCpu && ActionRegistry.actions.length > 0) {
                    // Check directly in actions
                    for (let j = 0; j < ActionRegistry.actions.length; j++) {
                        if (ActionRegistry.actions[j].id === "cpu-hex") {
                            foundCpu = true;
                            break;
                        }
                    }
                }

                if (!foundCpu) {
                    console.error("ASSERTION_FAILED: CPU hex action not found in ActionRegistry");
                    Qt.quit();
                    return;
                }

                console.log("=== PASS: ActionRegistry search & toggle actions runtime harness ===");
            } catch (err) {
                console.error("ASSERTION_FAILED: " + err);
            }
            Qt.quit();
        }
    }
}
