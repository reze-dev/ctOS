pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import desktop.services

Scope {
    id: root

    Timer {
        id: testTimer
        interval: 100
        running: true
        repeat: false

        onTriggered: {
            let passCount = 0;
            let failCount = 0;
            let failedTests = [];

            function assertCond(idStr, desc, condition, details) {
                if (condition) {
                    passCount++;
                    console.log("[PASS] " + idStr + ": " + desc + (details ? " (" + details + ")" : ""));
                } else {
                    failCount++;
                    failedTests.push(idStr + ": " + desc + " | " + details);
                    console.error("[FAIL] " + idStr + ": " + desc + (details ? " (" + details + ")" : ""));
                }
            }

            console.log("================================================================");
            console.log("=== EMPIRICAL CHALLENGER: MILESTONE 2 BLUETOOTH BACKEND ===");
            console.log("================================================================");

            // =================================================================
            // 1. Singleton Properties & Methods
            // =================================================================
            assertCond("M2.INTF.01", "BluetoothService exists", BluetoothService !== null && BluetoothService !== undefined, "");
            assertCond("M2.INTF.02", "isScanning property exists", typeof BluetoothService.isScanning === "boolean", "isScanning=" + BluetoothService.isScanning);
            assertCond("M2.INTF.03", "devices property exists", BluetoothService.devices !== undefined && typeof BluetoothService.devices.count === "number", "count=" + BluetoothService.devices.count);
            assertCond("M2.INTF.04", "connectedDevices property exists", BluetoothService.connectedDevices !== undefined && typeof BluetoothService.connectedDevices.count === "number", "");
            assertCond("M2.INTF.05", "pairedDevices property exists", BluetoothService.pairedDevices !== undefined && typeof BluetoothService.pairedDevices.count === "number", "");
            assertCond("M2.INTF.06", "availableDevices property exists", BluetoothService.availableDevices !== undefined && typeof BluetoothService.availableDevices.count === "number", "");
            assertCond("M2.INTF.07", "deviceModel exists and is ListModel", BluetoothService.deviceModel !== undefined && typeof BluetoothService.deviceModel.get === "function", "");
            assertCond("M2.INTF.08", "startScan is callable", typeof BluetoothService.startScan === "function", "");
            assertCond("M2.INTF.09", "stopScan is callable", typeof BluetoothService.stopScan === "function", "");
            assertCond("M2.INTF.10", "toggleScan is callable", typeof BluetoothService.toggleScan === "function", "");
            assertCond("M2.INTF.11", "connectDevice is callable", typeof BluetoothService.connectDevice === "function", "");
            assertCond("M2.INTF.12", "disconnectDevice is callable", typeof BluetoothService.disconnectDevice === "function", "");
            assertCond("M2.INTF.13", "pairDevice is callable", typeof BluetoothService.pairDevice === "function", "");
            assertCond("M2.INTF.14", "forgetDevice is callable", typeof BluetoothService.forgetDevice === "function", "");

            // =================================================================
            // 2. Parser Injections: _parseShowOutput
            // =================================================================
            BluetoothService._parseShowOutput("Powered: yes\n");
            assertCond("M2.SHOW.01", "_parseShowOutput Powered: yes sets powered=true", BluetoothService.powered === true && BluetoothService.available === true, "");

            BluetoothService._parseShowOutput("Powered: no\n");
            assertCond("M2.SHOW.02", "_parseShowOutput Powered: no sets powered=false", BluetoothService.powered === false && BluetoothService.available === true, "");

            BluetoothService._parseShowOutput("No default controller available\n");
            assertCond("M2.SHOW.03", "_parseShowOutput No controller sets available=false", BluetoothService.available === false && BluetoothService.powered === false, "");

            BluetoothService._parseShowOutput("Waiting to connect to bluetoothd...\n");
            assertCond("M2.SHOW.04", "_parseShowOutput Waiting to connect sets available=false", BluetoothService.available === false && BluetoothService.powered === false, "");

            // Reset to powered=true
            BluetoothService._parseShowOutput("Controller 00:11:22:33:44:55 ctOS-Host\n\tPowered: yes\n");

            // =================================================================
            // 3. Parser Injections: _parseDevicesOutput, _parsePairedOutput, _parseConnectedOutput
            // =================================================================
            // Clear map first
            BluetoothService._clearAllDevices();
            assertCond("M2.DEV.01", "_clearAllDevices resets device list to 0", BluetoothService.devices.count === 0, "count=" + BluetoothService.devices.count);

            // Inject Known Devices
            const knownRaw = "Device AA:11:22:33:44:01 Keyboard K380\n" +
                             "Device BB:22:33:44:55:02 Mouse MX Master\n" +
                             "Device CC:33:44:55:66:03 Headphones WH1000\n" +
                             "Device DD:44:55:66:77:04 Discovered Tag\n";
            BluetoothService._parseDevicesOutput(knownRaw);
            assertCond("M2.DEV.02", "_parseDevicesOutput populates 4 devices", BluetoothService.devices.count === 4, "count=" + BluetoothService.devices.count);
            assertCond("M2.DEV.03", "All 4 devices start as available (unpaired, unconnected)", BluetoothService.availableDevices.count === 4, "avail=" + BluetoothService.availableDevices.count);

            // Inject Paired Devices
            const pairedRaw = "Device AA:11:22:33:44:01 Keyboard K380\n" +
                              "Device CC:33:44:55:66:03 Headphones WH1000\n";
            BluetoothService._parsePairedOutput(pairedRaw);
            assertCond("M2.PAIR.01", "_parsePairedOutput sets pairedDevices count to 2", BluetoothService.pairedDevices.count === 2, "paired=" + BluetoothService.pairedDevices.count);
            assertCond("M2.PAIR.02", "Available devices reduced to 2", BluetoothService.availableDevices.count === 2, "avail=" + BluetoothService.availableDevices.count);

            // Inject Connected Devices
            const connRaw = "Device CC:33:44:55:66:03 Headphones WH1000\n";
            BluetoothService._parseConnectedOutput(connRaw);
            assertCond("M2.CONN.01", "_parseConnectedOutput sets isConnected=true", BluetoothService.isConnected === true, "isConnected=" + BluetoothService.isConnected);
            assertCond("M2.CONN.02", "_parseConnectedOutput sets deviceName", BluetoothService.deviceName === "Headphones WH1000", "deviceName=" + BluetoothService.deviceName);
            assertCond("M2.CONN.03", "connectedDevices count is 1", BluetoothService.connectedDevices.count === 1, "conn=" + BluetoothService.connectedDevices.count);
            assertCond("M2.CONN.04", "pairedDevices (not connected) count is 1", BluetoothService.pairedDevices.count === 1, "paired=" + BluetoothService.pairedDevices.count);

            // Check model contents and properties
            const dev0 = BluetoothService.devices.get(0);
            assertCond("M2.MODEL.01", "Device model entry has mac", typeof dev0.mac === "string" && dev0.mac.indexOf(":") !== -1, "mac=" + dev0.mac);
            assertCond("M2.MODEL.02", "Device model entry has name", typeof dev0.name === "string" && dev0.name.length > 0, "name=" + dev0.name);
            assertCond("M2.MODEL.03", "Device model entry has connected boolean", typeof dev0.connected === "boolean", "connected=" + dev0.connected);
            assertCond("M2.MODEL.04", "Device model entry has paired boolean", typeof dev0.paired === "boolean", "paired=" + dev0.paired);
            assertCond("M2.MODEL.05", "Device model entry has icon string", typeof dev0.icon === "string", "icon=" + dev0.icon);

            // Check deviceListModel sync
            assertCond("M2.LISTMODEL.01", "deviceListModel.count matches devices.count", BluetoothService.deviceModel.count === BluetoothService.devices.count, "listModelCount=" + BluetoothService.deviceModel.count);
            assertCond("M2.LISTMODEL.02", "deviceListModel.get(0).mac matches devices.get(0).mac", BluetoothService.deviceModel.get(0).mac === dev0.mac, "");

            // =================================================================
            // 4. Name Sanitization & Length Truncation
            // =================================================================
            // Control characters ( -)
            const ctrlRaw = "Device EE:55:66:77:88:05 Bad\x00Ctrl\x07Name\x1B\x7FEnd\n";
            BluetoothService._parseDevicesOutput(ctrlRaw);
            let foundCtrl = null;
            for (let i = 0; i < BluetoothService.devices.count; i++) {
                if (BluetoothService.devices.get(i).mac === "EE:55:66:77:88:05") {
                    foundCtrl = BluetoothService.devices.get(i);
                    break;
                }
            }
            assertCond("M2.SAN.01", "Control characters sanitized", foundCtrl !== null && foundCtrl.name === "BadCtrlNameEnd", "name=" + (foundCtrl ? foundCtrl.name : "null"));

            // 60+ chars long name truncation
            const longName = "A".repeat(70);
            const longRaw = "Device FF:66:77:88:99:06 " + longName + "\n";
            BluetoothService._parseDevicesOutput(longRaw);
            let foundLong = null;
            for (let i = 0; i < BluetoothService.devices.count; i++) {
                if (BluetoothService.devices.get(i).mac === "FF:66:77:88:99:06") {
                    foundLong = BluetoothService.devices.get(i);
                    break;
                }
            }
            assertCond("M2.SAN.02", "Long name (60+ chars) truncated cleanly (<= 24 chars)",
                foundLong !== null && foundLong.name.length <= 24 && foundLong.name.length > 0,
                "length=" + (foundLong ? foundLong.name.length : 0) + ", name=" + (foundLong ? foundLong.name : "null"));

            // =================================================================
            // 5. Scan Output Parser (_parseScanOutput)
            // =================================================================
            const scanNewRaw = "[NEW] Device 12:34:56:AB:CD:EF NewScannedDevice\n";
            BluetoothService._parseScanOutput(scanNewRaw);
            let foundScan = null;
            for (let i = 0; i < BluetoothService.devices.count; i++) {
                if (BluetoothService.devices.get(i).mac === "12:34:56:AB:CD:EF") {
                    foundScan = BluetoothService.devices.get(i);
                    break;
                }
            }
            assertCond("M2.SCAN.01", "_parseScanOutput [NEW] registers discovered device", foundScan !== null && foundScan.name === "NewScannedDevice", "");

            const scanDelRaw = "[DEL] Device 12:34:56:AB:CD:EF\n";
            BluetoothService._parseScanOutput(scanDelRaw);
            let foundAfterDel = false;
            for (let i = 0; i < BluetoothService.devices.count; i++) {
                if (BluetoothService.devices.get(i).mac === "12:34:56:AB:CD:EF") {
                    foundAfterDel = true;
                    break;
                }
            }
            assertCond("M2.SCAN.02", "_parseScanOutput [DEL] removes unpaired discovered device", foundAfterDel === false, "");

            // =================================================================
            // 6. Power Toggle On/Off State Transitions
            // =================================================================
            // Currently: CC:33:44:55:66:03 is connected
            // AA:11:22:33:44:01 is paired (not connected)
            // BB:22:33:44:55:02, DD:44:55:66:77:04, EE:55:66:77:88:05, FF:66:77:88:99:06 are discovered (unpaired)
            console.log("STATE BEFORE POWER OFF:");
            console.log("  isConnected=" + BluetoothService.isConnected + ", deviceName=" + BluetoothService.deviceName);
            console.log("  connectedDevices.count=" + BluetoothService.connectedDevices.count);
            console.log("  pairedDevices.count=" + BluetoothService.pairedDevices.count);
            console.log("  availableDevices.count=" + BluetoothService.availableDevices.count);
            console.log("  devices.count=" + BluetoothService.devices.count);

            // Trigger Power Off
            BluetoothService._parseShowOutput("Powered: no\n");

            console.log("STATE AFTER POWER OFF (Powered: no):");
            console.log("  powered=" + BluetoothService.powered);
            console.log("  isConnected=" + BluetoothService.isConnected + ", deviceName=" + BluetoothService.deviceName);
            console.log("  connectedDevices.count=" + BluetoothService.connectedDevices.count);
            console.log("  pairedDevices.count=" + BluetoothService.pairedDevices.count);
            console.log("  availableDevices.count=" + BluetoothService.availableDevices.count);
            console.log("  devices.count=" + BluetoothService.devices.count);

            assertCond("M2.POW.01", "Power off resets isConnected to false", BluetoothService.isConnected === false, "isConnected=" + BluetoothService.isConnected);
            assertCond("M2.POW.02", "Power off resets deviceName to empty", BluetoothService.deviceName === "", "deviceName=" + BluetoothService.deviceName);
            assertCond("M2.POW.03", "Power off resets connectedDevices count to 0", BluetoothService.connectedDevices.count === 0, "conn=" + BluetoothService.connectedDevices.count);

            // Test discovered devices cleared or not:
            console.log("CHECK DISCOVERED DEVICES ON POWER OFF:");
            console.log("  availableDevices (discovered) count: " + BluetoothService.availableDevices.count);
            for (let i = 0; i < BluetoothService.availableDevices.count; i++) {
                console.log("    discovered[" + i + "]: " + BluetoothService.availableDevices.get(i).mac + " " + BluetoothService.availableDevices.get(i).name);
            }

            assertCond("M2.POW.04", "Power off resets connected flag on previously connected device",
                BluetoothService.devices.get(0) !== undefined && BluetoothService.devices.get(0).connected === false, "");

            assertCond("M2.POW.05", "Power off clears discovered devices (availableDevices count === 0)",
                BluetoothService.availableDevices.count === 0, "availableDevices.count=" + BluetoothService.availableDevices.count);

            console.log("================================================================");
            console.log("M2 CHALLENGER RESULTS: Passed=" + passCount + ", Failed=" + failCount);
            if (failCount > 0) {
                console.log("FAILED TESTS:");
                for (let k = 0; k < failedTests.length; k++) {
                    console.log("  - " + failedTests[k]);
                }
            }
            console.log("================================================================");

            Qt.quit();
        }
    }
}
