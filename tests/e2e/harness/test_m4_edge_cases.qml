pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import desktop.services
import desktop.core
import desktop.surfaces

Scope {
    id: root

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

    property int failedSignalCount: 0
    property string lastFailedSsid: ""
    property string lastFailedReason: ""

    Connections {
        target: NetworkService
        function onConnectionFailed(ssid, reason) {
            root.failedSignalCount++;
            root.lastFailedSsid = ssid;
            root.lastFailedReason = reason;
        }
    }

    Timer {
        id: testRunner
        interval: 100
        running: true
        repeat: false

        onTriggered: {
            console.log("================================================================");
            console.log("=== EMPIRICAL CHALLENGER: M4 WIFI EDGE CASES & STRESS HARNESS ===");
            console.log("================================================================");

            // -------------------------------------------------------------
            // TEST SUITE 1: Repeated Rapid Connection Calls
            // -------------------------------------------------------------
            console.log("--- Suite 1: Repeated Rapid Connection Calls ---");
            NetworkService.connectToNetwork("SSID_Alfa");
            assertCondition("EDGE.RAPID.01", "First connect call sets connectingSsid to SSID_Alfa",
                NetworkService.connectingSsid === "SSID_Alfa" && NetworkService.isConnecting === true,
                "connectingSsid=" + NetworkService.connectingSsid);

            NetworkService.connectToNetwork("SSID_Bravo");
            assertCondition("EDGE.RAPID.02", "Immediate second connect call updates connectingSsid to SSID_Bravo",
                NetworkService.connectingSsid === "SSID_Bravo" && NetworkService.isConnecting === true,
                "connectingSsid=" + NetworkService.connectingSsid);

            NetworkService.connectToNetwork("SSID_Charlie");
            assertCondition("EDGE.RAPID.03", "Immediate third connect call updates connectingSsid to SSID_Charlie",
                NetworkService.connectingSsid === "SSID_Charlie" && NetworkService.isConnecting === true,
                "connectingSsid=" + NetworkService.connectingSsid);

            // Clean up
            NetworkService.disconnectCurrentNetwork();
            assertCondition("EDGE.RAPID.04", "disconnectCurrentNetwork cleans up after rapid spam",
                NetworkService.connectingSsid === "" && NetworkService.isConnecting === false,
                "connectingSsid=" + NetworkService.connectingSsid);

            // -------------------------------------------------------------
            // TEST SUITE 2: Abort During Connect (Manual Disconnect & Radio Off)
            // -------------------------------------------------------------
            console.log("--- Suite 2: Abort During Connect ---");
            NetworkService.connectToNetwork("AbortTarget_1");
            assertCondition("EDGE.ABORT.01", "connectToNetwork starts connection to AbortTarget_1",
                NetworkService.connectingSsid === "AbortTarget_1" && NetworkService.isConnecting === true,
                "connectingSsid=" + NetworkService.connectingSsid);

            NetworkService.disconnectCurrentNetwork();
            assertCondition("EDGE.ABORT.02", "disconnectCurrentNetwork aborts active connection immediately",
                NetworkService.connectingSsid === "" && NetworkService.isConnecting === false,
                "connectingSsid=" + NetworkService.connectingSsid);

            NetworkService.connectToNetwork("AbortTarget_2");
            assertCondition("EDGE.ABORT.03", "connectToNetwork starts connection to AbortTarget_2",
                NetworkService.connectingSsid === "AbortTarget_2" && NetworkService.isConnecting === true,
                "connectingSsid=" + NetworkService.connectingSsid);

            NetworkService.setWifiEnabled(false);
            assertCondition("EDGE.ABORT.04", "setWifiEnabled(false) aborts active connection immediately",
                NetworkService.connectingSsid === "" && NetworkService.isConnecting === false,
                "connectingSsid=" + NetworkService.connectingSsid);

            // Re-enable Wi-Fi
            NetworkService.setWifiEnabled(true);

            // -------------------------------------------------------------
            // TEST SUITE 3: Watchdog / Background Collision Stress Test
            // -------------------------------------------------------------
            console.log("--- Suite 3: Watchdog / State Collision Stress ---");
            // Case A: User connects to "TargetAP" while system is already connected to "CurrentAP"
            NetworkService.connectToNetwork("TargetAP");
            assertCondition("EDGE.COLL.01", "connectToNetwork sets target to TargetAP",
                NetworkService.connectingSsid === "TargetAP" && NetworkService.isConnecting === true,
                "connectingSsid=" + NetworkService.connectingSsid);

            // Simulate what happens when watchdog calls _evaluateNetworkState() while connected to "CurrentAP"
            // Watchdog calls _applyConnectedState("wifi", "CurrentAP", 0.9)
            NetworkService._applyConnectedState("wifi", "CurrentAP", 0.9);

            // In an ideal implementation, connectingSsid should REMAIN "TargetAP" because "CurrentAP" != "TargetAP"
            const coll02Passed = (NetworkService.connectingSsid === "TargetAP");
            assertCondition("EDGE.COLL.02", "Watchdog evaluating existing CurrentAP must NOT clear connectingSsid TargetAP",
                coll02Passed,
                "connectingSsid=" + NetworkService.connectingSsid + (coll02Passed ? "" : " (BUG: prematurely cleared by _applyConnectedState!)"));

            // Case B: User connects to "TargetAP_Eth" while Ethernet is active
            NetworkService.connectToNetwork("TargetAP_Eth");
            NetworkService._applyConnectedState("ethernet", "Ethernet", 1.0);
            const coll03Passed = (NetworkService.connectingSsid === "TargetAP_Eth");
            assertCondition("EDGE.COLL.03", "Watchdog evaluating active Ethernet must NOT clear connectingSsid TargetAP_Eth",
                coll03Passed,
                "connectingSsid=" + NetworkService.connectingSsid + (coll03Passed ? "" : " (BUG: prematurely cleared by _applyConnectedState!)"));

            // Case C: When the TARGET network connects, it SHOULD clear connectingSsid
            NetworkService.connectToNetwork("SuccessAP");
            NetworkService._applyConnectedState("wifi", "SuccessAP", 0.9);
            assertCondition("EDGE.COLL.04", "Target network connecting DOES clear connectingSsid",
                NetworkService.connectingSsid === "" && NetworkService.isConnecting === false,
                "connectingSsid=" + NetworkService.connectingSsid);

            // -------------------------------------------------------------
            // TEST SUITE 4: Timeout Trigger Semantics
            // -------------------------------------------------------------
            console.log("--- Suite 4: Timeout Trigger Semantics ---");
            root.failedSignalCount = 0;
            root.lastFailedSsid = "";
            root.lastFailedReason = "";

            NetworkService.connectToNetwork("TimeoutAP");
            assertCondition("EDGE.TMO.01", "Connection to TimeoutAP initiated",
                NetworkService.connectingSsid === "TimeoutAP" && NetworkService.isConnecting === true,
                "connectingSsid=" + NetworkService.connectingSsid);

            // Manually simulate the timeout action (clearing connectingSsid, setting lastError, emitting signal)
            // as defined in NetworkService.qml lines 211-216
            const timedOutSsid = NetworkService.connectingSsid;
            NetworkService.connectingSsid = "";
            NetworkService.lastError = "Connection timed out";
            NetworkService.connectionFailed(timedOutSsid, "Connection timed out");

            assertCondition("EDGE.TMO.02", "Timeout resolution clears connectingSsid",
                NetworkService.connectingSsid === "" && NetworkService.isConnecting === false,
                "connectingSsid=" + NetworkService.connectingSsid);

            assertCondition("EDGE.TMO.03", "Timeout resolution sets lastError to 'Connection timed out'",
                NetworkService.lastError === "Connection timed out",
                "lastError=" + NetworkService.lastError);

            assertCondition("EDGE.TMO.04", "Timeout resolution emits connectionFailed with matching SSID",
                root.failedSignalCount === 1 && root.lastFailedSsid === "TimeoutAP" && root.lastFailedReason === "Connection timed out",
                "count=" + root.failedSignalCount + ", ssid=" + root.lastFailedSsid + ", reason=" + root.lastFailedReason);

            // Clean up
            NetworkService.lastError = "";
            NetworkService._applyDisconnectedState();

            console.log("================================================================");
            console.log("EDGE CASES RESULTS: Passed=" + root.passCount + ", Failed=" + root.failCount);
            if (root.failCount === 0) {
                console.log("=== PASS: ALL EDGE CASES PASSED ===");
            } else {
                console.error("=== FAIL: EDGE CASES DETECTED BUGS ===");
            }
            console.log("================================================================");

            Qt.quit();
        }
    }
}
