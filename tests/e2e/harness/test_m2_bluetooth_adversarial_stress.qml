pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import desktop.services
import desktop.core

Scope {
    id: root

    Timer {
        id: stressTimer
        interval: 100
        running: Boolean(true)
        repeat: false

        onTriggered: {
            let passCount = 0;
            let failCount = 0;
            let results = [];

            function record(idStr, desc, condition, details) {
                if (condition) {
                    passCount++;
                    console.log("[PASS] " + idStr + ": " + desc + (details ? " (" + details + ")" : ""));
                } else {
                    failCount++;
                    console.error("[FAIL] " + idStr + ": " + desc + (details ? " (" + details + ")" : ""));
                }
                results.push({ id: idStr, desc: desc, pass: condition, details: details || "" });
            }

            console.log("================================================================");
            console.log("=== ADVERSARIAL STRESS TEST: BLUETOOTH BACKEND SERVICE (M2) ===");
            console.log("================================================================");

            // -------------------------------------------------------------
            // PHASE 1: Baseline Interface & Property Contracts
            // -------------------------------------------------------------
            record("CHAL.M2.PROP.01", "isScanning property exists and is boolean",
                typeof BluetoothService.isScanning === "boolean", "typeof=" + typeof BluetoothService.isScanning);
            record("CHAL.M2.PROP.02", "scanning property exists as alias to isScanning",
                typeof BluetoothService.scanning === "boolean" && BluetoothService.scanning === BluetoothService.isScanning,
                "scanning=" + BluetoothService.scanning);
            record("CHAL.M2.PROP.03", "devices property exists and has length/count",
                BluetoothService.devices !== undefined && (BluetoothService.devices.count !== undefined || BluetoothService.devices.length !== undefined),
                "devices=" + typeof BluetoothService.devices);
            record("CHAL.M2.PROP.04", "deviceModel ListModel property exists",
                BluetoothService.deviceModel !== null && BluetoothService.deviceModel !== undefined,
                "deviceModel=" + BluetoothService.deviceModel);
            record("CHAL.M2.PROP.05", "actionTargetMac property exists and is string",
                typeof BluetoothService.actionTargetMac === "string", "actionTargetMac=" + BluetoothService.actionTargetMac);
            record("CHAL.M2.PROP.06", "actionType property exists and is string",
                typeof BluetoothService.actionType === "string", "actionType=" + BluetoothService.actionType);
            record("CHAL.M2.PROP.07", "isActionPending property exists and is boolean",
                typeof BluetoothService.isActionPending === "boolean", "isActionPending=" + BluetoothService.isActionPending);

            // -------------------------------------------------------------
            // PHASE 2: Empty String Input Validation Guards
            // -------------------------------------------------------------
            BluetoothService._parseShowOutput("Powered: yes\n");

            // Empty string MAC
            BluetoothService.connectDevice("");
            record("CHAL.M2.MAC.EMPTY_CONNECT", "connectDevice('') is safely guarded by !mac",
                BluetoothService.actionTargetMac === "" && BluetoothService.isActionPending === false,
                "actionTargetMac=" + BluetoothService.actionTargetMac);

            BluetoothService.disconnectDevice("");
            record("CHAL.M2.MAC.EMPTY_DISCONNECT", "disconnectDevice('') is safely guarded by !mac",
                BluetoothService.actionTargetMac === "" && BluetoothService.isActionPending === false,
                "actionTargetMac=" + BluetoothService.actionTargetMac);

            BluetoothService.pairDevice("");
            record("CHAL.M2.MAC.EMPTY_PAIR", "pairDevice('') is safely guarded by !mac",
                BluetoothService.actionTargetMac === "" && BluetoothService.isActionPending === false,
                "actionTargetMac=" + BluetoothService.actionTargetMac);

            BluetoothService.forgetDevice("");
            record("CHAL.M2.MAC.EMPTY_FORGET", "forgetDevice('') is safely guarded by !mac",
                BluetoothService.actionTargetMac === "" && BluetoothService.isActionPending === false,
                "actionTargetMac=" + BluetoothService.actionTargetMac);

            // -------------------------------------------------------------
            // PHASE 3: QML Type Coercion Bug: null & undefined arguments & Regex Validation
            // -------------------------------------------------------------
            // Testing connectDevice(null): QML coerces null to "null" string, bypassing !mac
            BluetoothService.connectDevice(null);
            let nullCoerced = (BluetoothService.actionTargetMac === "null");
            console.log("CHAL.EMPIRICAL: connectDevice(null) coerced to string 'null': " + nullCoerced);
            record("CHAL.M2.BUG.NULL_COERCION", "connectDevice(null) must NOT trigger actionProcess (BUG: coerced to 'null' string)",
                !nullCoerced && BluetoothService.actionTargetMac === "",
                "actionTargetMac=" + BluetoothService.actionTargetMac + ", isPending=" + BluetoothService.isActionPending);

            BluetoothService.disconnectDevice(undefined);
            record("CHAL.M2.COERCE.UNDEF_DISCONNECT", "disconnectDevice(undefined) safely rejected",
                BluetoothService.actionTargetMac === "" && BluetoothService.isActionPending === false,
                "actionTargetMac=" + BluetoothService.actionTargetMac);

            BluetoothService.pairDevice(null);
            record("CHAL.M2.COERCE.NULL_PAIR", "pairDevice(null) safely rejected",
                BluetoothService.actionTargetMac === "" && BluetoothService.isActionPending === false,
                "actionTargetMac=" + BluetoothService.actionTargetMac);

            BluetoothService.forgetDevice(undefined);
            record("CHAL.M2.COERCE.UNDEF_FORGET", "forgetDevice(undefined) safely rejected",
                BluetoothService.actionTargetMac === "" && BluetoothService.isActionPending === false,
                "actionTargetMac=" + BluetoothService.actionTargetMac);

            // Regex validation: malformed and whitespace MACs
            BluetoothService.connectDevice("invalid-mac-address");
            record("CHAL.M2.REGEX.INVALID_MAC", "connectDevice('invalid-mac-address') rejected by regex",
                BluetoothService.actionTargetMac === "" && BluetoothService.isActionPending === false,
                "actionTargetMac=" + BluetoothService.actionTargetMac);

            BluetoothService.connectDevice("   ");
            record("CHAL.M2.REGEX.WHITESPACE", "connectDevice('   ') rejected by regex/trim",
                BluetoothService.actionTargetMac === "" && BluetoothService.isActionPending === false,
                "actionTargetMac=" + BluetoothService.actionTargetMac);

            // -------------------------------------------------------------
            // PHASE 4: Action Invocations While Controller Unavailable
            // -------------------------------------------------------------
            BluetoothService._parseShowOutput("No default controller available\n");
            record("CHAL.M2.ACT.UNAVAIL_STATE", "Service state is available: false",
                BluetoothService.available === false, "available=" + BluetoothService.available);

            // -------------------------------------------------------------
            // PHASE 5: Action Invocations While Powered Off
            // -------------------------------------------------------------
            BluetoothService._parseShowOutput("Controller 00:1A:7D:DA:71:13 TestHost\n\tPowered: no\n");
            record("CHAL.M2.ACT.POW_OFF_STATE", "Service state is powered: false",
                BluetoothService.powered === false, "powered=" + BluetoothService.powered);

            // connectDevice while powered off
            BluetoothService.connectDevice("00:11:22:33:44:55");
            record("CHAL.M2.ACT.OFF_CONNECT", "connectDevice() while powered off is safely guarded",
                BluetoothService.actionTargetMac === "",
                "actionTargetMac=" + BluetoothService.actionTargetMac);

            // disconnectDevice while powered off
            BluetoothService.disconnectDevice("00:11:22:33:44:55");
            record("CHAL.M2.ACT.OFF_DISCONNECT", "disconnectDevice() while powered off is safely guarded",
                BluetoothService.actionTargetMac === "",
                "actionTargetMac=" + BluetoothService.actionTargetMac);

            // pairDevice while powered off
            BluetoothService.pairDevice("00:11:22:33:44:55");
            record("CHAL.M2.ACT.OFF_PAIR", "pairDevice() while powered off is safely guarded",
                BluetoothService.actionTargetMac === "",
                "actionTargetMac=" + BluetoothService.actionTargetMac);

            // forgetDevice while powered off: check if guarded by !root._powered
            BluetoothService.forgetDevice("00:11:22:33:44:55");
            record("CHAL.M2.BUG.FORGET_POW_GUARD", "forgetDevice() while powered off is safely guarded",
                BluetoothService.actionTargetMac === "" && BluetoothService.isActionPending === false,
                "actionTargetMac=" + BluetoothService.actionTargetMac + ", isPending=" + BluetoothService.isActionPending);

            // -------------------------------------------------------------
            // PHASE 6: Rapid Scanning Stress
            // -------------------------------------------------------------
            BluetoothService._parseShowOutput("Powered: yes\n");

            // Burst startScan() x 50
            for (let i = 0; i < 50; i++) {
                BluetoothService.startScan();
            }
            record("CHAL.M2.SCAN.BURST_START", "Rapid burst of 50 startScan() leaves isScanning === true",
                BluetoothService.isScanning === true, "isScanning=" + BluetoothService.isScanning);

            // Burst stopScan() x 50
            for (let i = 0; i < 50; i++) {
                BluetoothService.stopScan();
            }
            record("CHAL.M2.SCAN.BURST_STOP", "Rapid burst of 50 stopScan() leaves isScanning === false",
                BluetoothService.isScanning === false, "isScanning=" + BluetoothService.isScanning);

            // Auto-abort active scan on power off
            BluetoothService._parseShowOutput("Powered: yes\n");
            BluetoothService.startScan();
            BluetoothService._parseShowOutput("Powered: no\n");
            record("CHAL.M2.SCAN.AUTO_ABORT_ON_OFF", "Controller power-off automatically aborts active scan",
                BluetoothService.isScanning === false, "isScanning=" + BluetoothService.isScanning);

            // Restore live state
            BluetoothService.refresh();

            console.log("================================================================");
            console.log("ADVERSARIAL HARNESS SUMMARY: Passed=" + passCount + ", Failed=" + failCount);
            console.log("================================================================");

            Qt.quit();
        }
    }
}
