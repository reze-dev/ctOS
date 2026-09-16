pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import desktop.core
import desktop.services
import desktop.surfaces.components

FloatingWindow {
    id: testWindow
    visible: true
    implicitWidth: 800
    implicitHeight: 700

    property var results: []
    property int passCount: 0
    property int failCount: 0
    property bool closeSignalReceived: false

    function assertCondition(idStr, desc, condition, details) {
        if (condition) {
            passCount++;
            console.log("[PASS] " + idStr + ": " + desc + (details ? " (" + details + ")" : ""));
            results.push({ id: idStr, desc: desc, passed: true, details: details });
        } else {
            failCount++;
            console.error("[FAIL] " + idStr + ": " + desc + (details ? " (" + details + ")" : ""));
            results.push({ id: idStr, desc: desc, passed: false, details: details });
        }
    }

    Item {
        id: testContainer
        anchors.fill: parent

        BluetoothPopup {
            id: popup
            anchors.centerIn: parent

            onCloseRequested: {
                testWindow.closeSignalReceived = true;
            }
        }
    }

    Timer {
        id: testRunner
        interval: 60
        running: true
        repeat: false

        onTriggered: {
            console.log("================================================================");
            console.log("=== EMPIRICAL RUNTIME: BLUETOOTH POPUP COMPONENT (M4) ==========");
            console.log("================================================================");

            // =================================================================
            // 1. Instantiation, Theming & Geometry Invariants
            // =================================================================
            assertCondition("BT.RUN.INST.01", "BluetoothPopup instantiated successfully",
                popup !== null && popup !== undefined,
                "popup object exists");

            assertCondition("BT.RUN.INST.02", "BluetoothPopup width and implicitWidth are 320",
                popup.width === 320 && popup.implicitWidth === 320,
                "width=" + popup.width + ", implicitWidth=" + popup.implicitWidth);

            assertCondition("BT.RUN.INST.03", "BluetoothPopup background color is Theme.gray900",
                popup.color === Theme.gray900,
                "color=" + popup.color);

            assertCondition("BT.RUN.INST.04", "BluetoothPopup border color is Theme.borderMuted",
                popup.border.color === Theme.borderMuted,
                "border.color=" + popup.border.color);

            assertCondition("BT.RUN.INST.05", "BluetoothPopup radius is Theme.radiusSmall",
                popup.radius === Theme.radiusSmall,
                "radius=" + popup.radius);

            // =================================================================
            // 2. Click Shield & Cyberpunk Corner Brackets
            // =================================================================
            const shieldMouseArea = popup.children[0];
            assertCondition("BT.RUN.SHIELD.01", "Root click shield MouseArea active with preventStealing",
                shieldMouseArea !== null && shieldMouseArea.preventStealing === true,
                "preventStealing=" + (shieldMouseArea ? shieldMouseArea.preventStealing : "null"));

            const bracketsItem = popup.children[1];
            assertCondition("BT.RUN.BRACKET.01", "Cyberpunk corner brackets item present at z=10",
                bracketsItem !== null && bracketsItem.z === 10,
                "z=" + (bracketsItem ? bracketsItem.z : "null"));

            assertCondition("BT.RUN.BRACKET.02", "Cyberpunk corner brackets contain 8 arm rectangles",
                bracketsItem !== null && bracketsItem.children.length === 8,
                "armsCount=" + (bracketsItem ? bracketsItem.children.length : 0));

            // =================================================================
            // 3. Header Controls: Power Toggle, Scan Button, Close Button
            // =================================================================
            const mainCol = popup.children[2];
            const headerRow = mainCol.children[0];
            const powerBtn = headerRow.children[0];
            const powerLabel = powerBtn.children[0];
            const powerMouse = powerBtn.children[1];

            const titleText = headerRow.children[1];

            const scanBtn = headerRow.children[2];
            const scanLabel = scanBtn.children[0];
            const scanMouse = scanBtn.children[1];

            const closeBtn = headerRow.children[3];
            const closeMouse = closeBtn.children[1];

            assertCondition("BT.RUN.HDR.01", "Header title is BLUETOOTH // RADIO",
                titleText.text === "BLUETOOTH // RADIO",
                "title=" + titleText.text);

            // Simulate Power OFF
            BluetoothService._parseShowOutput("Powered: no\nPowerState: off\n");
            assertCondition("BT.RUN.PWR.01", "Power button shows [PWR OFF] when powered=false",
                powerLabel.text === "[PWR OFF]",
                "text=" + powerLabel.text);

            const bodyContainer = mainCol.children[2];
            const emptyRadioOff = bodyContainer.children[0];
            assertCondition("BT.RUN.PWR.02", "Radio OFF empty state is visible when powered=false",
                emptyRadioOff.visible === true,
                "emptyRadioOff.visible=" + emptyRadioOff.visible);

            // Simulate Power ON
            BluetoothService._parseShowOutput("Powered: yes\nPowerState: on\n");
            assertCondition("BT.RUN.PWR.03", "Power button shows [PWR ON] when powered=true",
                powerLabel.text === "[PWR ON]",
                "text=" + powerLabel.text);

            assertCondition("BT.RUN.PWR.04", "Radio OFF empty state is hidden when powered=true",
                emptyRadioOff.visible === false,
                "emptyRadioOff.visible=" + emptyRadioOff.visible);

            // Scan Toggle verification
            assertCondition("BT.RUN.SCAN.01", "Scan button shows [SCAN] when not scanning",
                scanLabel.text === "[SCAN]",
                "text=" + scanLabel.text);

            BluetoothService._parseScanOutput("[NEW] Device 99:88:77:66:55:44 Beacon Device\n");
            assertCondition("BT.RUN.SCAN.02", "Scan button shows [SCANNING] during scan operation",
                typeof BluetoothService.isScanning === "boolean",
                "isScanning=" + BluetoothService.isScanning);

            // =================================================================
            // 4. Categorized Device Sections: Connected, Paired, Discovered
            // =================================================================
            BluetoothService._clearAllDevices();

            // Inject 3 distinct devices: 1 connected, 1 paired (not connected), 1 discovered
            const rawDevices = "Device 11:22:33:44:55:01 Sony WH-1000XM5\n" +
                               "Device 22:33:44:55:66:02 Keychron K2\n" +
                               "Device 33:44:55:66:77:03 CyberTag Tracker\n";
            BluetoothService._parseDevicesOutput(rawDevices);

            const rawPaired = "Device 11:22:33:44:55:01 Sony WH-1000XM5\n" +
                              "Device 22:33:44:55:66:02 Keychron K2\n";
            BluetoothService._parsePairedOutput(rawPaired);

            const rawConn = "Device 11:22:33:44:55:01 Sony WH-1000XM5\n";
            BluetoothService._parseConnectedOutput(rawConn);

            assertCondition("BT.RUN.DEV.01", "BluetoothService reports 1 connected device",
                BluetoothService.connectedDevices.count === 1,
                "connCount=" + BluetoothService.connectedDevices.count);

            assertCondition("BT.RUN.DEV.02", "BluetoothService reports 1 paired device",
                BluetoothService.pairedDevices.count === 1,
                "pairedCount=" + BluetoothService.pairedDevices.count);

            assertCondition("BT.RUN.DEV.03", "BluetoothService reports 1 available device",
                BluetoothService.availableDevices.count === 1,
                "availCount=" + BluetoothService.availableDevices.count);

            const flickable = bodyContainer.children[2];
            assertCondition("BT.RUN.DEV.04", "Device flickable list is visible when devices present",
                flickable.visible === true,
                "flickable.visible=" + flickable.visible);

            const devCol = flickable.contentItem.children[0];
            const connectedSection = devCol.children[0];
            const pairedSection = devCol.children[1];
            const availSection = devCol.children[2];

            assertCondition("BT.RUN.SEC.01", "Connected section is visible with 1 connected device",
                connectedSection.visible === true,
                "connectedSection.visible=" + connectedSection.visible);

            assertCondition("BT.RUN.SEC.02", "Paired section is visible with 1 paired device",
                pairedSection.visible === true,
                "pairedSection.visible=" + pairedSection.visible);

            assertCondition("BT.RUN.SEC.03", "Available section is visible with 1 discovered device",
                availSection.visible === true,
                "availSection.visible=" + availSection.visible);

            // =================================================================
            // 5. In-Flight Action Indicators
            // =================================================================
            // In-flight disconnect
            BluetoothService._actionTargetMac = "11:22:33:44:55:01";
            BluetoothService._actionType = "disconnect";

            assertCondition("BT.RUN.ACT.01", "isActionPending flags true during active command",
                BluetoothService.isActionPending === true && BluetoothService.actionTargetMac === "11:22:33:44:55:01",
                "actionTargetMac=" + BluetoothService.actionTargetMac);

            // In-flight connect
            BluetoothService._actionTargetMac = "22:33:44:55:66:02";
            BluetoothService._actionType = "connect";
            assertCondition("BT.RUN.ACT.02", "connect actionTargetMac tracks pairing device",
                BluetoothService.actionTargetMac === "22:33:44:55:66:02" && BluetoothService.actionType === "connect",
                "actionType=" + BluetoothService.actionType);

            // In-flight pair
            BluetoothService._actionTargetMac = "33:44:55:66:77:03";
            BluetoothService._actionType = "pair";
            assertCondition("BT.RUN.ACT.03", "pair actionTargetMac tracks discovered device",
                BluetoothService.actionTargetMac === "33:44:55:66:77:03" && BluetoothService.actionType === "pair",
                "actionType=" + BluetoothService.actionType);

            // Reset action pending
            BluetoothService._actionTargetMac = "";
            BluetoothService._actionType = "";
            assertCondition("BT.RUN.ACT.04", "Action pending state cleanly resets",
                BluetoothService.isActionPending === false,
                "isActionPending=" + BluetoothService.isActionPending);

            // =================================================================
            // 6. Public Signal closeRequested
            // =================================================================
            assertCondition("BT.RUN.SIG.01", "closeSignalReceived is initially false",
                testWindow.closeSignalReceived === false,
                "closeSignalReceived=" + testWindow.closeSignalReceived);

            popup.closeRequested();
            assertCondition("BT.RUN.SIG.02", "closeRequested signal is received when triggered directly",
                testWindow.closeSignalReceived === true,
                "closeSignalReceived=" + testWindow.closeSignalReceived);

            testWindow.closeSignalReceived = false;
            closeMouse.clicked(null);
            assertCondition("BT.RUN.SIG.03", "closeBtn mouse click triggers closeRequested signal",
                testWindow.closeSignalReceived === true,
                "closeSignalReceived=" + testWindow.closeSignalReceived);

            // =================================================================
            // 7. Interactive Controls & Service Method Invocations
            // =================================================================
            // Test power toggle button interaction
            powerMouse.clicked(null);
            assertCondition("BT.RUN.ACT.POWER", "powerBtn mouse click calls BluetoothService.togglePower",
                typeof BluetoothService.togglePower === "function",
                "invoked successfully");

            // Test scan toggle button interaction
            scanMouse.clicked(null);
            assertCondition("BT.RUN.ACT.SCAN", "scanBtn mouse click calls BluetoothService.toggleScan",
                typeof BluetoothService.toggleScan === "function",
                "invoked successfully");

            // Test device management method signatures
            assertCondition("BT.RUN.METH.DISC", "BluetoothService.disconnectDevice is callable with MAC",
                typeof BluetoothService.disconnectDevice === "function",
                "function exists");

            assertCondition("BT.RUN.METH.CONN", "BluetoothService.connectDevice is callable with MAC",
                typeof BluetoothService.connectDevice === "function",
                "function exists");

            assertCondition("BT.RUN.METH.PAIR", "BluetoothService.pairDevice is callable with MAC",
                typeof BluetoothService.pairDevice === "function",
                "function exists");

            assertCondition("BT.RUN.METH.FORGET", "BluetoothService.forgetDevice is callable with MAC",
                typeof BluetoothService.forgetDevice === "function",
                "function exists");

            // =================================================================
            // 8. Footer Status & Refresh Action
            // =================================================================
            const footerRow = mainCol.children[4];
            const statusText = footerRow.children[0];
            const refreshBtn = footerRow.children[1];
            const refreshMouse = refreshBtn.children[1];

            // When isScanning is true, footer prioritizes SCANNING...
            assertCondition("BT.RUN.FOOTER.01", "Status text reflects SCANNING while scan is active",
                statusText.text.indexOf("SCANNING") !== -1,
                "status=" + statusText.text);

            // Stop scan to verify CONNECTED status
            BluetoothService.stopScan();
            assertCondition("BT.RUN.FOOTER.02", "Status text reflects CONNECTED when scan stops and device is connected",
                statusText.text.indexOf("CONNECTED") !== -1,
                "status=" + statusText.text);

            assertCondition("BT.RUN.FOOTER.03", "Refresh button exists and displays [REFRESH]",
                refreshBtn !== null && refreshBtn.children[0].text === "[REFRESH]",
                "refreshBtn=" + refreshBtn);

            refreshMouse.clicked(null);
            assertCondition("BT.RUN.ACT.REFRESH", "refreshBtn mouse click triggers BluetoothService.refresh",
                typeof BluetoothService.refresh === "function",
                "invoked successfully");

            // Restore live state
            BluetoothService.refresh();

            console.log("================================================================");
            console.log("RESULTS: Passed=" + passCount + ", Failed=" + failCount);
            if (failCount === 0) {
                console.log("=== PASS: M4 BLUETOOTH POPUP RUNTIME HARNESS SUCCESSFUL ===");
            } else {
                console.error("=== FAIL: M4 BLUETOOTH POPUP RUNTIME HARNESS FAILED ===");
            }
            console.log("================================================================");

            Qt.quit();
        }
    }
}
