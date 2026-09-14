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
        width: 1920
    }

    property int passCount: 0
    property int failCount: 0

    function assertCondition(idStr, desc, condition, details) {
        if (condition) {
            passCount++;
            console.log("[PASS] " + idStr + ": " + desc + (details ? " (" + details + ")" : ""));
        } else {
            failCount++;
            console.error("[FAIL] " + idStr + ": " + desc + (details ? " (" + details + ")" : ""));
        }
    }

    Timer {
        id: stressRunner
        interval: 150
        running: true
        repeat: false

        onTriggered: {
            console.log("================================================================");
            console.log("=== EMPIRICAL CHALLENGER: M3 ADVERSARIAL RUNTIME STRESS HARNESS ===");
            console.log("================================================================");

            try {
                // =============================================================
                // 1. Controller Absence & Malformed Show Outputs
                // =============================================================
                BluetoothService._parseShowOutput("No default controller available\n");
                assertCondition("ADV.BT.MISSING.01", "Missing controller clears available and powered",
                    BluetoothService.available === false && BluetoothService.powered === false &&
                    BluetoothService.isConnected === false && BluetoothService.deviceName === "",
                    "avail=" + BluetoothService.available + ", pow=" + BluetoothService.powered);

                BluetoothService._parseShowOutput("Waiting to connect to bluetoothd...\n");
                assertCondition("ADV.BT.MISSING.02", "Bluetoothd wait string sets available=false",
                    BluetoothService.available === false && BluetoothService.powered === false,
                    "avail=" + BluetoothService.available);

                BluetoothService._parseShowOutput("");
                assertCondition("ADV.BT.MISSING.03", "Empty string output sets available=false",
                    BluetoothService.available === false && BluetoothService.powered === false,
                    "avail=" + BluetoothService.available);

                BluetoothService._parseShowOutput("   \r\n\t   \n");
                assertCondition("ADV.BT.MISSING.04", "Whitespace-only output sets available=false",
                    BluetoothService.available === false && BluetoothService.powered === false,
                    "avail=" + BluetoothService.available);

                // =============================================================
                // 2. Power State Transitions & Edge Keywords
                // =============================================================
                BluetoothService._parseShowOutput("Controller 00:11:22:33:44:55\n\tName: ctOS-Host\n\tPowered: yes\n");
                assertCondition("ADV.BT.POWER.01", "Valid controller with Powered: yes enables available & powered",
                    BluetoothService.available === true && BluetoothService.powered === true,
                    "avail=" + BluetoothService.available + ", pow=" + BluetoothService.powered);

                BluetoothService._parseShowOutput("Controller 00:11:22:33:44:55\n\tPowered: no\n");
                assertCondition("ADV.BT.POWER.02", "Powered: no sets powered=false",
                    BluetoothService.available === true && BluetoothService.powered === false,
                    "avail=" + BluetoothService.available + ", pow=" + BluetoothService.powered);

                // Check powered off keyword variant (e.g. Powered: off) does not falsely enable powered
                BluetoothService._parseShowOutput("Controller 00:11:22:33:44:55\n\tPowered: off\n");
                assertCondition("ADV.BT.POWER.03", "Powered: off does not falsely enable powered",
                    BluetoothService.powered === false,
                    "pow=" + BluetoothService.powered);

                // Reset back to powered=yes
                BluetoothService._parseShowOutput("Controller 00:11:22:33:44:55\n\tPowered: yes\n");

                // =============================================================
                // 3. Connected Devices Parsing, Unicode, Truncation & Escapes
                // =============================================================
                // Normal device
                BluetoothService._parseConnectedOutput("Device 11:22:33:44:55:66 Standard Headset\n");
                assertCondition("ADV.BT.DEV.NORMAL", "Standard device connects cleanly",
                    BluetoothService.isConnected === true && BluetoothService.deviceName === "Standard Headset",
                    "conn=" + BluetoothService.isConnected + ", name=" + BluetoothService.deviceName);

                // Excess whitespace around name
                BluetoothService._parseConnectedOutput("Device 11:22:33:44:55:66    Padded Device    \n");
                assertCondition("ADV.BT.DEV.SPACES", "Padded spaces trimmed cleanly",
                    BluetoothService.isConnected === true && BluetoothService.deviceName === "Padded Device",
                    "name=" + BluetoothService.deviceName);

                // 80+ char long device name - must be clamped to 24 chars
                let longStr = "Device 11:22:33:44:55:66 VeryLongBluetoothDeviceNameThatExceedsNormalLimitsAndIsOver50Chars1234567890\n";
                BluetoothService._parseConnectedOutput(longStr);
                assertCondition("ADV.BT.DEV.LONG", "Device name over 50 chars bounded to <= 24 chars",
                    BluetoothService.isConnected === true && BluetoothService.deviceName.length <= 24 &&
                    BluetoothService.deviceName === "VeryLongBluetoothDeviceN",
                    "len=" + BluetoothService.deviceName.length + ", name=" + BluetoothService.deviceName);

                // Unicode & Emojis
                BluetoothService._parseConnectedOutput("Device 11:22:33:44:55:66 🎧 Sony WH-1000XM4 特殊 🔥\n");
                assertCondition("ADV.BT.DEV.UNICODE", "Unicode and emojis parsed without crashing",
                    BluetoothService.isConnected === true && BluetoothService.deviceName.length > 0 &&
                    BluetoothService.deviceName.indexOf("Sony") !== -1,
                    "name=" + BluetoothService.deviceName);

                // Control characters & ANSI codes stripped
                BluetoothService._parseConnectedOutput("Device 11:22:33:44:55:66 Clean\x00\x07Device\x1b[31m\n");
                assertCondition("ADV.BT.DEV.CONTROL", "Control characters stripped from device name",
                    BluetoothService.isConnected === true && BluetoothService.deviceName.indexOf("\x00") === -1 &&
                    BluetoothService.deviceName.indexOf("\x07") === -1,
                    "name=" + BluetoothService.deviceName);

                // Multiple devices in output - selects first without error
                let multiOutput = "Device 11:22:33:44:55:66 Primary Mouse\nDevice AA:BB:CC:DD:EE:FF Secondary Keyboard\n";
                BluetoothService._parseConnectedOutput(multiOutput);
                assertCondition("ADV.BT.DEV.MULTI", "Multiple connected devices selects first device",
                    BluetoothService.isConnected === true && BluetoothService.deviceName === "Primary Mouse",
                    "name=" + BluetoothService.deviceName);

                // Malformed MAC
                BluetoothService._parseConnectedOutput("Device INVALID_MAC TestDevice\n");
                assertCondition("ADV.BT.DEV.BAD_MAC", "Invalid MAC address rejected",
                    BluetoothService.isConnected === false && BluetoothService.deviceName === "",
                    "conn=" + BluetoothService.isConnected);

                // Empty / disconnect
                BluetoothService._parseConnectedOutput("");
                assertCondition("ADV.BT.DEV.EMPTY", "Empty devices output sets isConnected=false",
                    BluetoothService.isConnected === false && BluetoothService.deviceName === "",
                    "conn=" + BluetoothService.isConnected);

                // =============================================================
                // 4. State Invariant: Power Off resets Connected state
                // =============================================================
                BluetoothService._parseConnectedOutput("Device 11:22:33:44:55:66 Headset\n");
                assertCondition("ADV.BT.INV.PRE", "Connected state established",
                    BluetoothService.isConnected === true && BluetoothService.deviceName === "Headset",
                    "name=" + BluetoothService.deviceName);

                BluetoothService._parseShowOutput("Controller 00:11:22:33:44:55\n\tPowered: no\n");
                assertCondition("ADV.BT.INV.POWER_OFF_CLEARS", "Powering off clears isConnected and deviceName",
                    BluetoothService.isConnected === false && BluetoothService.deviceName === "",
                    "conn=" + BluetoothService.isConnected + ", name=" + BluetoothService.deviceName);

                // =============================================================
                // 5. Layout, Bar Positioning & Decoupling Invariants
                // =============================================================
                let barChildren = bar.contentItem ? bar.contentItem.children : bar.children;
                let rightRow = barChildren[2];
                let rightChildren = rightRow.children;

                let batSec = rightChildren[2];
                let btSec = rightChildren[3];
                let clkSec = rightChildren[4];

                let batChildStr = batSec.children[0] ? batSec.children[0].toString() : "";
                let btChildStr = btSec.children[0] ? btSec.children[0].toString() : "";
                let clkChildStr = clkSec.children[0] ? clkSec.children[0].toString() : "";

                assertCondition("ADV.BT.LAYOUT.POS", "bluetoothSection placed strictly between battery and clock",
                    batChildStr.indexOf("BatteryWidget") !== -1 &&
                    btChildStr.indexOf("BluetoothWidget") !== -1 &&
                    clkChildStr.indexOf("ClockWidget") !== -1,
                    "bat=" + batChildStr + ", bt=" + btChildStr + ", clk=" + clkChildStr);

                assertCondition("ADV.BT.LAYOUT.HEIGHT", "bluetoothSection height is exactly Theme.barHeight - 6 (34)",
                    btSec.height === 34 && btSec.implicitHeight === 34,
                    "height=" + btSec.height);

                assertCondition("ADV.BT.LAYOUT.RADIUS", "bluetoothSection radius is Theme.radiusMedium (8)",
                    btSec.radius === 8,
                    "radius=" + btSec.radius);

                // Find BluetoothWidget inside btSec
                let btWidget = btSec.children[0];
                assertCondition("ADV.BT.LAYOUT.WDG", "bluetoothSection hosts BluetoothWidget",
                    btWidget !== null && btWidget.toString().indexOf("BluetoothWidget") !== -1,
                    "widget=" + btWidget);

                // Verify BluetoothWidget direct children: RowLayout -> CtosIcon, Text
                // Root is Item, no internal MouseArea, no internal container Rectangle
                let wdgChildren = btWidget.children;
                let rowLayout = wdgChildren.length > 0 ? wdgChildren[0] : null;
                let isRowLayout = rowLayout !== null && rowLayout.toString().indexOf("QQuickRowLayout") !== -1;

                let wdgHasInternalMA = false;
                let wdgHasContainerRect = false;
                for (let k = 0; k < wdgChildren.length; k++) {
                    let ch = wdgChildren[k];
                    let chStr = ch.toString();
                    if (chStr.indexOf("MouseArea") !== -1) wdgHasInternalMA = true;
                    if (chStr.indexOf("QQuickRectangle") !== -1) wdgHasContainerRect = true;
                }

                assertCondition("ADV.BT.DEC.NO_MA", "BluetoothWidget has zero internal MouseAreas",
                    !wdgHasInternalMA,
                    "wdgHasInternalMA=" + wdgHasInternalMA);

                assertCondition("ADV.BT.DEC.NO_RECT", "BluetoothWidget has zero internal container Rectangles",
                    !wdgHasContainerRect && isRowLayout,
                    "wdgHasContainerRect=" + wdgHasContainerRect + ", isRowLayout=" + isRowLayout);

                // =============================================================
                // 6. Section Width & Bounded Containment Stress Test
                // =============================================================
                // Test width under powered=false
                BluetoothService._parseShowOutput("Controller 00:11:22:33:44:55\n\tPowered: no\n");
                let widthOff = btSec.width;
                assertCondition("ADV.BT.WIDTH.OFF", "bluetoothSection width when OFF is compact (<= 100px)",
                    widthOff > 0 && widthOff <= 100,
                    "widthOff=" + widthOff);

                // Test width under powered=true, idle
                BluetoothService._parseShowOutput("Controller 00:11:22:33:44:55\n\tPowered: yes\n");
                BluetoothService._parseConnectedOutput("");
                let widthOn = btSec.width;
                assertCondition("ADV.BT.WIDTH.ON", "bluetoothSection width when ON is compact (<= 100px)",
                    widthOn > 0 && widthOn <= 100,
                    "widthOn=" + widthOn);

                // Test width under max 24 char device name
                BluetoothService._parseConnectedOutput(longStr);
                let widthLong = btSec.width;
                assertCondition("ADV.BT.WIDTH.LONG", "bluetoothSection width with long device is bounded (<= 170px)",
                    widthLong > 0 && widthLong <= 170,
                    "widthLong=" + widthLong);

                // Test visibility when available=false
                BluetoothService._parseShowOutput("No default controller available\n");
                assertCondition("ADV.BT.VIS.HIDDEN", "bluetoothSection visible=false when controller missing",
                    btSec.visible === false && btWidget.visible === false,
                    "secVis=" + btSec.visible + ", wdgVis=" + btWidget.visible);

                // Test visibility recovery when controller restored
                BluetoothService._parseShowOutput("Powered: yes\n");
                assertCondition("ADV.BT.VIS.RECOVER", "bluetoothSection recovers visible=true when controller restored",
                    btSec.visible === true && btWidget.visible === true,
                    "secVis=" + btSec.visible + ", wdgVis=" + btWidget.visible);

                // =============================================================
                // 7. Method Guard Invariants: togglePower
                // =============================================================
                // Set available false again
                BluetoothService._parseShowOutput("No default controller available\n");
                // togglePower should safely handle unavailable controller without crash or throw
                BluetoothService.togglePower();
                assertCondition("ADV.BT.GUARD.TOGGLE_UNAVAIL", "togglePower() is no-op when available=false",
                    BluetoothService.available === false,
                    "available=" + BluetoothService.available);

                // Restore live state
                BluetoothService.refresh();

            } catch (err) {
                console.error("[CRITICAL ERROR IN TEST HARNESS] " + err);
                failCount++;
            }

            console.log("================================================================");
            console.log("M3 ADVERSARIAL RUNTIME RESULTS: Passed=" + passCount + ", Failed=" + failCount);
            if (failCount === 0) {
                console.log("=== PASS: ALL M3 ADVERSARIAL STRESS RUNTIME TESTS PASSED ===");
            } else {
                console.error("=== FAIL: M3 ADVERSARIAL STRESS RUNTIME TESTS FAILED ===");
            }
            console.log("================================================================");

            Qt.quit();
        }
    }
}
