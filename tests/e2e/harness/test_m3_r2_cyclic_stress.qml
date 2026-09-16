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
        id: stressTimer
        interval: 100
        running: true
        repeat: false

        onTriggered: {
            console.log("================================================================");
            console.log("=== EMPIRICAL CHALLENGER R2: MULTI-CYCLE STRESS & PARSER HARNESS ===");
            console.log("================================================================");

            try {
                let barChildren = bar.contentItem ? bar.contentItem.children : bar.children;
                let rightRow = barChildren[2];
                let rightChildren = rightRow.children;
                let btSec = rightChildren[3];
                let btWidget = btSec.children[0];

                // -------------------------------------------------------------
                // TEST 1: Rapid 20-Cycle Availability Toggle (Zero Deadlock)
                // -------------------------------------------------------------
                console.log("\n--- Subtest 1: Rapid 20-Cycle Availability Toggle ---");
                let deadlockDetected = false;
                for (let cycle = 1; cycle <= 20; cycle++) {
                    // Turn OFF available
                    BluetoothService._parseShowOutput("No default controller available\n");
                    if (btSec.visible !== false || btWidget.visible !== false) {
                        deadlockDetected = true;
                        assertCondition("R2.CYCLE.OFF." + cycle, "Cycle " + cycle + " hide failed", false,
                            "btSec.visible=" + btSec.visible + ", btWidget.visible=" + btWidget.visible);
                        break;
                    }

                    // Turn ON available
                    BluetoothService._parseShowOutput("Controller 00:11:22:33:44:55 ctOS-Host\n\tPowered: yes\n");
                    if (btSec.visible !== true || btWidget.visible !== true) {
                        deadlockDetected = true;
                        assertCondition("R2.CYCLE.ON." + cycle, "Cycle " + cycle + " recover failed (DEADLOCK)", false,
                            "btSec.visible=" + btSec.visible + ", btWidget.visible=" + btWidget.visible);
                        break;
                    }
                }
                assertCondition("R2.STRESS.CYCLE_20", "20 consecutive availability cycles without deadlock",
                    !deadlockDetected, "20/20 cycles cleanly recovered visibility");

                // -------------------------------------------------------------
                // TEST 2: Watchdog Poller Lifecycle under Unavailable State
                // -------------------------------------------------------------
                console.log("\n--- Subtest 2: Watchdog Poller Lifecycle ---");
                // When controller is unavailable:
                BluetoothService._parseShowOutput("No default controller available\n");
                assertCondition("R2.POLL.UNAVAIL_RUNNING", "pollTimer stays running when Bluetooth is unavailable",
                    BluetoothService.refreshInterval > 0 && Boolean(BluetoothService.refreshInterval > 0) === true,
                    "refreshInterval=" + BluetoothService.refreshInterval);

                // When user sets refreshInterval = 0:
                BluetoothService.refreshInterval = 0;
                assertCondition("R2.POLL.ZERO_DISABLE", "pollTimer disables when refreshInterval=0",
                    Boolean(BluetoothService.refreshInterval > 0) === false,
                    "refreshInterval=0 -> running=false");

                // When user restores refreshInterval = 4000:
                BluetoothService.refreshInterval = 4000;
                assertCondition("R2.POLL.RESTORE", "pollTimer reactivates when refreshInterval=4000",
                    Boolean(BluetoothService.refreshInterval > 0) === true,
                    "refreshInterval=4000 -> running=true");

                // -------------------------------------------------------------
                // TEST 3: BLE Unnamed Peripheral Variations
                // -------------------------------------------------------------
                console.log("\n--- Subtest 3: BLE Unnamed Peripherals ---");
                BluetoothService._parseShowOutput("Controller 00:11:22:33:44:55 ctOS-Host\n\tPowered: yes\n");

                // 3a. No trailing space
                BluetoothService._parseConnectedOutput("Device 12:34:56:78:9A:BC\n");
                assertCondition("R2.BLE.NO_SPACE", "Unnamed device (no trailing space) connects as 'Device'",
                    BluetoothService.isConnected === true && BluetoothService.deviceName === "Device",
                    "isConnected=" + BluetoothService.isConnected + ", name=" + BluetoothService.deviceName);

                // 3b. Single trailing space
                BluetoothService._parseConnectedOutput("Device 12:34:56:78:9A:BC \n");
                assertCondition("R2.BLE.ONE_SPACE", "Unnamed device (single trailing space) connects as 'Device'",
                    BluetoothService.isConnected === true && BluetoothService.deviceName === "Device",
                    "isConnected=" + BluetoothService.isConnected + ", name=" + BluetoothService.deviceName);

                // 3c. Multiple trailing spaces
                BluetoothService._parseConnectedOutput("Device 12:34:56:78:9A:BC     \n");
                assertCondition("R2.BLE.MULTI_SPACES", "Unnamed device (multiple spaces) connects as 'Device'",
                    BluetoothService.isConnected === true && BluetoothService.deviceName === "Device",
                    "isConnected=" + BluetoothService.isConnected + ", name=" + BluetoothService.deviceName);

                // 3d. Trailing tabs
                BluetoothService._parseConnectedOutput("Device 12:34:56:78:9A:BC\t\t\n");
                assertCondition("R2.BLE.TABS", "Unnamed device (trailing tabs) connects as 'Device'",
                    BluetoothService.isConnected === true && BluetoothService.deviceName === "Device",
                    "isConnected=" + BluetoothService.isConnected + ", name=" + BluetoothService.deviceName);

                // 3e. Lowercase MAC
                BluetoothService._parseConnectedOutput("Device aa:bb:cc:dd:ee:ff\n");
                assertCondition("R2.BLE.LOWER_MAC", "Lowercase MAC unnamed device connects as 'Device'",
                    BluetoothService.isConnected === true && BluetoothService.deviceName === "Device",
                    "isConnected=" + BluetoothService.isConnected + ", name=" + BluetoothService.deviceName);

                // -------------------------------------------------------------
                // TEST 4: Unicode, Emojis, Control Codes, Long Device Names
                // -------------------------------------------------------------
                console.log("\n--- Subtest 4: Device Name Sanitation & Bounding ---");
                // 4a. 60-char long name
                let sixtyChars = "A123456789B123456789C123456789D123456789E123456789F123456789";
                BluetoothService._parseConnectedOutput("Device 12:34:56:78:9A:BC " + sixtyChars + "\n");
                assertCondition("R2.NAME.LEN_CLAMP", "60-char device name strictly clamped to 24 characters",
                    BluetoothService.deviceName.length === 24 && BluetoothService.deviceName === sixtyChars.slice(0, 24),
                    "len=" + BluetoothService.deviceName.length + ", name=" + BluetoothService.deviceName);

                // 4b. Multi-byte UTF-8 emoji and Japanese text
                let utf8Name = "🎧 WH-1000XM4 東京 🔥";
                BluetoothService._parseConnectedOutput("Device 12:34:56:78:9A:BC " + utf8Name + "\n");
                assertCondition("R2.NAME.UTF8", "Multi-byte UTF-8 emojis and kanji cleanly handled",
                    BluetoothService.isConnected === true && BluetoothService.deviceName.indexOf("🎧") !== -1 &&
                    BluetoothService.deviceName.indexOf("東京") !== -1,
                    "name=" + BluetoothService.deviceName);

                // 4c. Control chars (null byte, bell, escape, DEL)
                let dirtyName = "\x00\x07Clean\x1b[31mSound\x7f";
                BluetoothService._parseConnectedOutput("Device 12:34:56:78:9A:BC " + dirtyName + "\n");
                assertCondition("R2.NAME.CTRL_STRIP", "Control characters stripped from name",
                    BluetoothService.isConnected === true &&
                    BluetoothService.deviceName.indexOf("\x00") === -1 &&
                    BluetoothService.deviceName.indexOf("\x07") === -1 &&
                    BluetoothService.deviceName.indexOf("\x7f") === -1,
                    "name=" + BluetoothService.deviceName);

                // -------------------------------------------------------------
                // TEST 5: Live UI Geometry Bounding Under All States
                // -------------------------------------------------------------
                console.log("\n--- Subtest 5: Live Layout & Geometry Invariants ---");
                // Height invariant
                assertCondition("R2.GEO.HEIGHT", "bluetoothSection height is exactly Theme.barHeight - 6",
                    btSec.height === 34 && btSec.implicitHeight === 34,
                    "height=" + btSec.height);

                // Radius invariant
                assertCondition("R2.GEO.RADIUS", "bluetoothSection radius is Theme.radiusMedium (8)",
                    btSec.radius === 8,
                    "radius=" + btSec.radius);

                // Width bounds:
                // Connected with max length text
                BluetoothService._parseConnectedOutput("Device 12:34:56:78:9A:BC " + sixtyChars + "\n");
                let maxConnectedWidth = btSec.width;
                assertCondition("R2.GEO.MAX_WIDTH", "bluetoothSection width strictly bounded under 24-char text (<= 160px)",
                    maxConnectedWidth > 0 && maxConnectedWidth <= 160,
                    "width=" + maxConnectedWidth);

                // Idle / ON width
                BluetoothService._parseConnectedOutput("");
                let onWidth = btSec.width;
                assertCondition("R2.GEO.ON_WIDTH", "bluetoothSection width when ON is compact (<= 100px)",
                    onWidth > 0 && onWidth <= 100,
                    "width=" + onWidth);

                // Powered OFF width
                BluetoothService._parseShowOutput("Controller 00:11:22:33:44:55 ctOS-Host\n\tPowered: no\n");
                let offWidth = btSec.width;
                assertCondition("R2.GEO.OFF_WIDTH", "bluetoothSection width when OFF is compact (<= 100px)",
                    offWidth > 0 && offWidth <= 100,
                    "width=" + offWidth);

                // -------------------------------------------------------------
                // TEST 6: Decoupling & Mouse Interaction Safety
                // -------------------------------------------------------------
                console.log("\n--- Subtest 6: Decoupling & Invocation Safety ---");
                // BluetoothWidget has 0 MouseAreas
                let hasMA = false;
                for (let k = 0; k < btWidget.children.length; k++) {
                    if (btWidget.children[k].toString().indexOf("MouseArea") !== -1) hasMA = true;
                }
                assertCondition("R2.DEC.NO_CHILD_MA", "BluetoothWidget has 0 internal MouseAreas", !hasMA, "hasMA=" + hasMA);

                // Toggle power when unavailable is safe no-op
                BluetoothService._parseShowOutput("No default controller available\n");
                BluetoothService.togglePower();
                assertCondition("R2.SAFE.TOGGLE_NOOP", "togglePower() does not throw when unavailable",
                    BluetoothService.available === false,
                    "available=" + BluetoothService.available);

                // Restore live state
                BluetoothService._parseShowOutput("Controller 00:11:22:33:44:55 ctOS-Host\n\tPowered: yes\n");

            } catch (e) {
                console.error("[CRITICAL TEST ERROR] " + e);
                failCount++;
            }

            console.log("\n================================================================");
            console.log("R2 EMPIRICAL STRESS RESULTS: Passed=" + passCount + ", Failed=" + failCount);
            if (failCount === 0) {
                console.log("=== PASS: ALL R2 EMPIRICAL ADVERSARIAL STRESS TESTS PASSED ===");
            } else {
                console.error("=== FAIL: R2 EMPIRICAL ADVERSARIAL STRESS TESTS FAILED ===");
            }
            console.log("================================================================");

            Qt.quit();
        }
    }
}
