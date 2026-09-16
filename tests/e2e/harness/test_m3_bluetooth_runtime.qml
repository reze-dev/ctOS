pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import desktop.services
import desktop.core
import desktop.surfaces
import desktop.surfaces.components

Scope {
    id: root

    AmbientBar {
        id: bar
    }

    Timer {
        id: testTimer
        interval: 150
        running: Boolean(true)
        repeat: false

        onTriggered: {
            let passCount = 0;
            let failCount = 0;

            function assertCondition(idStr, desc, condition, details) {
                if (condition) {
                    passCount++;
                    console.log("[PASS] " + idStr + ": " + desc + (details ? " (" + details + ")" : ""));
                } else {
                    failCount++;
                    console.error("[FAIL] " + idStr + ": " + desc + (details ? " (" + details + ")" : ""));
                }
            }

            console.log("================================================================");
            console.log("=== EMPIRICAL RUNTIME: BLUETOOTH HARNESS (M3) ===");
            console.log("================================================================");

            // 1. BluetoothService Singleton Contract
            assertCondition("M3.RUN.01", "BluetoothService singleton is instantiated",
                BluetoothService !== null && BluetoothService !== undefined,
                "BluetoothService=" + BluetoothService);

            assertCondition("M3.RUN.02", "BluetoothService has boolean available property",
                typeof BluetoothService.available === "boolean",
                "available=" + BluetoothService.available);

            assertCondition("M3.RUN.03", "BluetoothService has boolean powered property",
                typeof BluetoothService.powered === "boolean",
                "powered=" + BluetoothService.powered);

            assertCondition("M3.RUN.04", "BluetoothService has boolean isConnected property",
                typeof BluetoothService.isConnected === "boolean",
                "isConnected=" + BluetoothService.isConnected);

            assertCondition("M3.RUN.05", "BluetoothService has string deviceName property",
                typeof BluetoothService.deviceName === "string",
                "deviceName=" + BluetoothService.deviceName);

            assertCondition("M3.RUN.06", "BluetoothService has callable togglePower method",
                typeof BluetoothService.togglePower === "function",
                "typeof=" + typeof BluetoothService.togglePower);

            assertCondition("M3.RUN.07", "BluetoothService has callable refresh method",
                typeof BluetoothService.refresh === "function",
                "typeof=" + typeof BluetoothService.refresh);

            // 2. Synthetic Parser Tests
            BluetoothService._parseShowOutput("Powered: yes\nPowerState: on\n");
            assertCondition("M3.RUN.08", "Parser handles Powered: yes correctly",
                BluetoothService.available === true && BluetoothService.powered === true,
                "available=" + BluetoothService.available + ", powered=" + BluetoothService.powered);

            BluetoothService._parseShowOutput("Powered: no\nPowerState: off\n");
            assertCondition("M3.RUN.09", "Parser handles Powered: no correctly",
                BluetoothService.available === true && BluetoothService.powered === false,
                "available=" + BluetoothService.available + ", powered=" + BluetoothService.powered);

            BluetoothService._parseShowOutput("No default controller available\n");
            assertCondition("M3.RUN.10", "Parser handles No default controller available",
                BluetoothService.available === false && BluetoothService.powered === false,
                "available=" + BluetoothService.available + ", powered=" + BluetoothService.powered);

            // Reset to powered for connected device parser tests
            BluetoothService._parseShowOutput("Powered: yes\n");
            BluetoothService._parseConnectedOutput("Device E4:07:69:41:63:01 Toad 8\n");
            assertCondition("M3.RUN.11", "Parser extracts connected device name",
                BluetoothService.isConnected === true && BluetoothService.deviceName === "Toad 8",
                "isConnected=" + BluetoothService.isConnected + ", deviceName=" + BluetoothService.deviceName);

            BluetoothService._parseConnectedOutput("");
            assertCondition("M3.RUN.12", "Parser handles empty connected output",
                BluetoothService.isConnected === false && BluetoothService.deviceName === "",
                "isConnected=" + BluetoothService.isConnected + ", deviceName=" + BluetoothService.deviceName);

            BluetoothService._parseConnectedOutput("Device 11:22:33:44:55:66 🎧 Sony WH-1000XM4 & \"Bass\"\n");
            assertCondition("M3.RUN.13", "Parser handles unicode / special characters in device name",
                BluetoothService.isConnected === true && BluetoothService.deviceName.indexOf("Sony WH-1000XM4") !== -1,
                "isConnected=" + BluetoothService.isConnected + ", deviceName=" + BluetoothService.deviceName);

            // 3. AmbientBar Geometry and Integration
            let rightRow = bar.contentItem.children[2];
            let rightChildren = rightRow.children;
            assertCondition("M3.RUN.14", "rightSections contains 6 section containers",
                rightChildren.length === 6,
                "rightChildrenCount=" + rightChildren.length);

            let btSec = rightChildren[3];
            assertCondition("M3.RUN.15", "bluetoothSection slot is at index 3 in rightSections",
                btSec !== null && btSec !== undefined,
                "btSec=" + btSec);

            assertCondition("M3.RUN.16", "bluetoothSection height is 34",
                btSec.height === 34,
                "height=" + btSec.height);

            assertCondition("M3.RUN.17", "bluetoothSection radius is Theme.radiusMedium (8)",
                btSec.radius === Theme.radiusMedium && btSec.radius === 8,
                "radius=" + btSec.radius);

            let btWidget = btSec.children[0];
            assertCondition("M3.RUN.18", "bluetoothSection contains BluetoothWidget child",
                btWidget !== null && btWidget !== undefined,
                "btWidget=" + btWidget);

            assertCondition("M3.RUN.19", "BluetoothWidget defines isHovered property",
                typeof btWidget.isHovered === "boolean",
                "isHovered=" + btWidget.isHovered);

            // Restore live state
            BluetoothService.refresh();

            console.log("================================================================");
            console.log("M3 RUNTIME RESULTS: Passed=" + passCount + ", Failed=" + failCount);
            if (failCount === 0) {
                console.log("=== PASS: M3 BLUETOOTH RUNTIME HARNESS SUCCESSFUL ===");
            } else {
                console.error("=== FAIL: M3 BLUETOOTH RUNTIME HARNESS FAILED ===");
            }
            console.log("================================================================");

            Qt.quit();
        }
    }
}
