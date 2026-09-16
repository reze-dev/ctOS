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
        interval: 200
        running: Boolean(true)
        repeat: false

        onTriggered: {
            let passCount = 0;
            let failCount = 0;

            function assert(idStr, desc, condition, details) {
                if (condition) {
                    passCount++;
                    console.log("[PASS] " + idStr + ": " + desc + (details ? " (" + details + ")" : ""));
                } else {
                    failCount++;
                    console.error("[FAIL] " + idStr + ": " + desc + (details ? " (" + details + ")" : ""));
                }
            }

            console.log("================================================================");
            console.log("=== ADVERSARIAL STRESS TEST: BLUETOOTH RUNTIME & GEOMETRY ===");
            console.log("================================================================");

            // Access rightRow -> bluetoothSection -> bluetoothWidget
            let rightRow = bar.contentItem.children[2];
            let btSec = rightRow.children[3];
            let btWidget = btSec.children[0];

            // Test 1: Baseline Geometry
            assert("ADV.GEO.01", "bluetoothSection height is 34px (Theme.barHeight - 6)",
                btSec.height === 34, "height=" + btSec.height);
            assert("ADV.GEO.02", "bluetoothSection radius is 8px (Theme.radiusMedium)",
                btSec.radius === 8, "radius=" + btSec.radius);

            // Test 2: Missing Controller Transition
            BluetoothService._parseShowOutput("No default controller available\n");
            assert("ADV.STATE.MISSING.01", "available is false on missing controller",
                BluetoothService.available === false, "available=" + BluetoothService.available);
            assert("ADV.STATE.MISSING.02", "powered is false on missing controller",
                BluetoothService.powered === false, "powered=" + BluetoothService.powered);
            assert("ADV.STATE.MISSING.03", "isConnected is false on missing controller",
                BluetoothService.isConnected === false, "isConnected=" + BluetoothService.isConnected);
            assert("ADV.STATE.MISSING.04", "deviceName is empty on missing controller",
                BluetoothService.deviceName === "", "deviceName=" + BluetoothService.deviceName);
            assert("ADV.STATE.MISSING.05", "BluetoothWidget is hidden when available is false",
                btWidget.visible === false, "visible=" + btWidget.visible);
            assert("ADV.STATE.MISSING.06", "bluetoothSection is hidden when available is false",
                btSec.visible === false, "visible=" + btSec.visible);

            // Test 3: Powered Off Transition
            BluetoothService._parseShowOutput("Controller 00:1A:7D:DA:71:13 TestHost\n\tPowered: no\n\tPowerState: off\n");
            assert("ADV.STATE.OFF.01", "available is true on powered off",
                BluetoothService.available === true, "available=" + BluetoothService.available);
            assert("ADV.STATE.OFF.02", "powered is false on powered off",
                BluetoothService.powered === false, "powered=" + BluetoothService.powered);
            assert("ADV.STATE.OFF.03", "isConnected is false on powered off",
                BluetoothService.isConnected === false, "isConnected=" + BluetoothService.isConnected);
            assert("ADV.STATE.OFF.04", "stateText is OFF",
                btWidget.stateText === "OFF", "stateText=" + btWidget.stateText);
            assert("ADV.STATE.OFF.05", "bluetoothSection is visible when powered off",
                btSec.visible === true, "visible=" + btSec.visible);

            // Test 4: Powered On (Idle) Transition
            BluetoothService._parseShowOutput("Controller 00:1A:7D:DA:71:13 TestHost\n\tPowered: yes\n\tPowerState: on\n");
            BluetoothService._parseConnectedOutput("");
            assert("ADV.STATE.ON.01", "available is true on powered on",
                BluetoothService.available === true, "available=" + BluetoothService.available);
            assert("ADV.STATE.ON.02", "powered is true on powered on",
                BluetoothService.powered === true, "powered=" + BluetoothService.powered);
            assert("ADV.STATE.ON.03", "isConnected is false when no devices connected",
                BluetoothService.isConnected === false, "isConnected=" + BluetoothService.isConnected);
            assert("ADV.STATE.ON.04", "stateText is ON when idle",
                btWidget.stateText === "ON", "stateText=" + btWidget.stateText);

            // Test 5: Connected Device Transition (Normal)
            BluetoothService._parseConnectedOutput("Device 12:34:56:78:9A:BC Keychron K2\n");
            assert("ADV.STATE.CONN.01", "isConnected is true when device connected",
                BluetoothService.isConnected === true, "isConnected=" + BluetoothService.isConnected);
            assert("ADV.STATE.CONN.02", "deviceName is Keychron K2",
                BluetoothService.deviceName === "Keychron K2", "deviceName=" + BluetoothService.deviceName);
            assert("ADV.STATE.CONN.03", "stateText reflects deviceName",
                btWidget.stateText === "Keychron K2", "stateText=" + btWidget.stateText);

            // Test 6: Unicode & Emoji Device Name
            BluetoothService._parseConnectedOutput("Device FE:ED:BA:BE:01:02 🎧 B&O Beoplay H95 (Space Grey)\n");
            assert("ADV.UNICODE.01", "Unicode emoji & symbols preserved",
                BluetoothService.deviceName.indexOf("🎧") !== -1 && BluetoothService.deviceName.indexOf("B&O") !== -1,
                "deviceName=" + BluetoothService.deviceName);

            // Test 7: CJK & Multilingual Device Name
            BluetoothService._parseConnectedOutput("Device 00:11:22:33:44:55 ソニー ワイヤレスヘッドセット\n");
            assert("ADV.UNICODE.02", "CJK characters preserved",
                BluetoothService.deviceName.indexOf("ソニー") !== -1,
                "deviceName=" + BluetoothService.deviceName);

            // Test 8: Adversarial Long Name (70+ characters)
            let longRaw = "Device AA:BB:CC:DD:EE:FF Extremely Super Ultra Mega Long Bluetooth Device Name That Spans Beyond Normal Screens 123456789\n";
            BluetoothService._parseConnectedOutput(longRaw);
            assert("ADV.BOUND.01", "Service clamps device name to max 24 chars",
                BluetoothService.deviceName.length <= 24, "length=" + BluetoothService.deviceName.length + ", name=" + BluetoothService.deviceName);

            // Test 9: UI Width Bounding
            // Check that bluetoothSection.width does not overflow container or bar
            let measuredWidth = btSec.width;
            let prefWidth = btSec.Layout.preferredWidth;
            console.log("DEBUG: btSec width=" + measuredWidth + ", preferredWidth=" + prefWidth + ", widget implicitWidth=" + btWidget.implicitWidth);
            assert("ADV.BOUND.02", "bluetoothSection width is strictly bounded (< 250px)",
                measuredWidth < 250 && prefWidth < 250,
                "measuredWidth=" + measuredWidth + ", prefWidth=" + prefWidth);

            // Test 10: Disconnection while powered on
            BluetoothService._parseConnectedOutput("");
            assert("ADV.DISC.01", "isConnected resets to false upon empty connected list",
                BluetoothService.isConnected === false && BluetoothService.deviceName === "",
                "isConnected=" + BluetoothService.isConnected + ", deviceName=" + BluetoothService.deviceName);
            assert("ADV.DISC.02", "stateText returns to ON",
                btWidget.stateText === "ON", "stateText=" + btWidget.stateText);

            // Test 11: Power off resets connected device even if parseConnectedOutput was not called
            BluetoothService._parseConnectedOutput("Device 12:34:56:78:9A:BC Active Device\n");
            assert("ADV.POWOFF.01", "Device connected before power off",
                BluetoothService.isConnected === true, "isConnected=" + BluetoothService.isConnected);
            BluetoothService._parseShowOutput("Controller 00:1A:7D:DA:71:13 TestHost\n\tPowered: no\n");
            assert("ADV.POWOFF.02", "Power off resets isConnected to false",
                BluetoothService.isConnected === false, "isConnected=" + BluetoothService.isConnected);
            assert("ADV.POWOFF.03", "Power off resets deviceName to empty",
                BluetoothService.deviceName === "", "deviceName=" + BluetoothService.deviceName);

            // Test 12: Daemon disconnect / crash ("Waiting to connect to bluetoothd")
            BluetoothService._parseShowOutput("Waiting to connect to bluetoothd...\n");
            assert("ADV.DAEMON.01", "available is false on daemon disconnect",
                BluetoothService.available === false, "available=" + BluetoothService.available);
            assert("ADV.DAEMON.02", "powered is false on daemon disconnect",
                BluetoothService.powered === false, "powered=" + BluetoothService.powered);

            // Restore live state
            BluetoothService.refresh();

            console.log("================================================================");
            console.log("ADVERSARIAL RESULTS: Passed=" + passCount + ", Failed=" + failCount);
            if (failCount === 0) {
                console.log("=== PASS: ALL ADVERSARIAL STRESS HARNESS TESTS PASSED ===");
            } else {
                console.error("=== FAIL: ADVERSARIAL STRESS HARNESS FAILED ===");
            }
            console.log("================================================================");

            Qt.quit();
        }
    }
}
