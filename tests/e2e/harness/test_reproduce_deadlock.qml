pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import desktop.services
import desktop.surfaces

Scope {
    id: root

    AmbientBar {
        id: bar
    }

    Timer {
        id: step1
        interval: 100
        running: true
        repeat: false
        onTriggered: {
            let rightRow = bar.contentItem.children[2];
            let btSec = rightRow.children[3];
            let btWidget = btSec.children[0];

            console.log("=== STEP 1: INITIAL STATE (Hardware Present) ===");
            console.log("BluetoothService.available:", BluetoothService.available);
            console.log("btWidget.available:", btWidget.available);
            console.log("btWidget.visible:", btWidget.visible);
            console.log("btSec.visible:", btSec.visible);

            console.log("\n=== STEP 2: CONTROLLER DISCONNECTED / MISSING ===");
            BluetoothService._parseShowOutput("No default controller available\n");
            console.log("BluetoothService.available:", BluetoothService.available);
            console.log("btWidget.available:", btWidget.available);
            console.log("btWidget.visible:", btWidget.visible);
            console.log("btSec.visible:", btSec.visible);

            step2.start();
        }
    }

    Timer {
        id: step2
        interval: 100
        running: false
        repeat: false
        onTriggered: {
            console.log("\n=== STEP 3: CONTROLLER RECONNECTED / POWERED ON ===");
            BluetoothService._parseShowOutput("Controller 00:1A:7D:DA:71:13 TestHost\n\tPowered: yes\n");
            let rightRow = bar.contentItem.children[2];
            let btSec = rightRow.children[3];
            let btWidget = btSec.children[0];
            console.log("BluetoothService.available:", BluetoothService.available);
            console.log("btWidget.available:", btWidget.available);
            console.log("btWidget.visible:", btWidget.visible, "<-- EXPECTED: true, ACTUAL:", btWidget.visible);
            console.log("btSec.visible:", btSec.visible, "<-- EXPECTED: true, ACTUAL:", btSec.visible);

            if (!btSec.visible) {
                console.error("\n>>> CRITICAL BUG CONFIRMED: bluetoothSection is DEADLOCKED in invisible state! <<<");
            } else {
                console.log("\n>>> SUCCESS: bluetoothSection recovered visibility cleanly! <<<");
            }

            // Restore live state
            BluetoothService.refresh();
            Qt.quit();
        }
    }
}
