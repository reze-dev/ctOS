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

    Item {
        id: railContainer
        width: 360
        height: 800

        Loader {
            id: railLoader
            anchors.fill: parent
            source: "file:///home/reze/Projects/ctOS/shell/desktop/surfaces/SystemRail.qml"
        }
    }

    // Signal spy on NetworkService.connectionFailed
    property int failedSignalCount: 0
    property string lastFailedSsid: ""
    property string lastFailedReason: ""

    Connections {
        target: NetworkService
        function onConnectionFailed(ssid, reason) {
            root.failedSignalCount++;
            root.lastFailedSsid = ssid;
            root.lastFailedReason = reason;
            console.log("[SPY] connectionFailed signal caught: ssid=" + ssid + ", reason=" + reason);
        }
    }

    // State sequence runner
    Timer {
        id: seqRunner
        interval: 100
        running: true
        repeat: false

        onTriggered: {
            console.log("================================================================");
            console.log("=== EMPIRICAL CHALLENGER: M4 WIFI ADVERSARIAL RUNTIME HARNESS ===");
            console.log("================================================================");

            // -------------------------------------------------------------
            // Phase 1: Invariants & Watchdog Pausing/Resuming
            // -------------------------------------------------------------
            assertCondition("ADV.WDG.01", "watchdogInterval defaults to 10000ms",
                NetworkService.watchdogInterval === 10000,
                "watchdogInterval=" + NetworkService.watchdogInterval);

            assertCondition("ADV.TMO.01", "connectionTimeout property is 15000ms",
                NetworkService.connectionTimeout === 15000,
                "connectionTimeout=" + NetworkService.connectionTimeout);

            // Test watchdog toggling via watchdogInterval
            try {
                NetworkService.watchdogInterval = 0;
                assertCondition("ADV.WDG.02", "watchdogInterval=0 disables watchdog without error",
                    NetworkService.watchdogInterval === 0,
                    "watchdogInterval=" + NetworkService.watchdogInterval);

                NetworkService.watchdogInterval = 10000;
                assertCondition("ADV.WDG.03", "watchdogInterval restores cleanly",
                    NetworkService.watchdogInterval === 10000,
                    "watchdogInterval=" + NetworkService.watchdogInterval);
            } catch (e) {
                assertCondition("ADV.WDG.04", "watchdogInterval toggling threw exception", false, String(e));
            }

            // -------------------------------------------------------------
            // Phase 2: SystemRail View & Tier 1/2 UI State Coherence
            // -------------------------------------------------------------
            const rail = railLoader.item;
            assertCondition("ADV.UI.RAIL.LOAD", "SystemRail loaded cleanly",
                rail !== null && rail !== undefined,
                "railLoader.status=" + railLoader.status);

            if (rail) {
                rail.navigateToWifi();
                assertCondition("ADV.UI.RAIL.NAV", "SystemRail navigated to wifi view",
                    rail.currentView === "wifi",
                    "currentView=" + rail.currentView);
            }

            // Check initial state
            assertCondition("ADV.UI.INIT.01", "Initial isConnecting is false",
                NetworkService.isConnecting === false && NetworkService.connectingSsid === "",
                "isConnecting=" + NetworkService.isConnecting);

            // -------------------------------------------------------------
            // Phase 3: Early Cancellation: Connection Success at t=2s
            // -------------------------------------------------------------
            root.failedSignalCount = 0;
            NetworkService.connectToNetwork("EarlySuccessAP");
            assertCondition("ADV.RACE.EARLY.01", "connectToNetwork starts connecting to EarlySuccessAP",
                NetworkService.isConnecting === true && NetworkService.connectingSsid === "EarlySuccessAP",
                "connectingSsid=" + NetworkService.connectingSsid);

            // Simulate connection success event (as would arrive from NetworkManager D-Bus)
            NetworkService._applyConnectedState("wifi", "EarlySuccessAP", 0.95);
            assertCondition("ADV.RACE.EARLY.02", "applyConnectedState clears connectingSsid immediately",
                NetworkService.connectingSsid === "" && NetworkService.isConnecting === false && NetworkService.isConnected === true,
                "connectingSsid=" + NetworkService.connectingSsid + ", isConnected=" + NetworkService.isConnected);

            assertCondition("ADV.RACE.EARLY.03", "No spurious connectionFailed signal on success",
                root.failedSignalCount === 0,
                "failedSignalCount=" + root.failedSignalCount);

            // -------------------------------------------------------------
            // Phase 4: Early Cancellation: Manual Disconnect
            // -------------------------------------------------------------
            NetworkService.connectToNetwork("ManualDiscAP");
            assertCondition("ADV.RACE.DISC.01", "connectToNetwork starts connecting to ManualDiscAP",
                NetworkService.isConnecting === true && NetworkService.connectingSsid === "ManualDiscAP",
                "connectingSsid=" + NetworkService.connectingSsid);

            NetworkService.disconnectCurrentNetwork();
            assertCondition("ADV.RACE.DISC.02", "disconnectCurrentNetwork stops connecting immediately",
                NetworkService.connectingSsid === "" && NetworkService.isConnecting === false,
                "connectingSsid=" + NetworkService.connectingSsid);

            // -------------------------------------------------------------
            // Phase 5: Early Cancellation: Wi-Fi Disabled
            // -------------------------------------------------------------
            NetworkService.connectToNetwork("RadioOffAP");
            assertCondition("ADV.RACE.RADIO.01", "connectToNetwork starts connecting to RadioOffAP",
                NetworkService.isConnecting === true && NetworkService.connectingSsid === "RadioOffAP",
                "connectingSsid=" + NetworkService.connectingSsid);

            NetworkService.setWifiEnabled(false);
            assertCondition("ADV.RACE.RADIO.02", "setWifiEnabled(false) stops connecting immediately",
                NetworkService.connectingSsid === "" && NetworkService.isConnecting === false,
                "connectingSsid=" + NetworkService.connectingSsid);

            // Attempt connecting while Wi-Fi disabled
            NetworkService.connectToNetwork("BlockedAP");
            assertCondition("ADV.RACE.RADIO.03", "connectToNetwork while disabled sets lastError and rejects",
                NetworkService.connectingSsid === "" && NetworkService.isConnecting === false && NetworkService.lastError === "Wi-Fi subsystem unavailable",
                "lastError=" + NetworkService.lastError);

            // Restore Wi-Fi
            NetworkService.setWifiEnabled(true);
            NetworkService.lastError = "";
            NetworkService._applyDisconnectedState();

            // -------------------------------------------------------------
            // Phase 6: Sanitization Stress
            // -------------------------------------------------------------
            const badName = "Cyber\x00\x1fHack\x7fAP";
            const sanitized = NetworkService.sanitizeName(badName);
            assertCondition("ADV.SANIT.01", "sanitizeName strips control chars",
                sanitized === "CyberHackAP",
                "sanitized=" + sanitized);

            const emptySanitized = NetworkService.sanitizeName("   ");
            assertCondition("ADV.SANIT.02", "sanitizeName on whitespace returns --N/A--",
                emptySanitized === "--N/A--",
                "emptySanitized=" + emptySanitized);

            // -------------------------------------------------------------
            // Phase 7: Real 15-Second Connection Timeout Lifecycle Test
            // -------------------------------------------------------------
            console.log("[TEST] Initiating 15-second real connection timeout test for 'EmpiricalHangAP'...");
            root.failedSignalCount = 0;
            root.lastFailedSsid = "";
            root.lastFailedReason = "";

            NetworkService.connectToNetwork("EmpiricalHangAP");
            assertCondition("ADV.TMO.REAL.01", "Timeout test started: connectingSsid=EmpiricalHangAP",
                NetworkService.connectingSsid === "EmpiricalHangAP" && NetworkService.isConnecting === true,
                "isConnecting=" + NetworkService.isConnecting);

            // Schedule intermediate and final checks
            checkMidTimer.start();
            checkWatchdogTimer.start();
            checkFinalTimeoutTimer.start();
        }
    }

    // Mid-check at t = 5000ms: connection should still be actively pending
    Timer {
        id: checkMidTimer
        interval: 5000
        repeat: false
        onTriggered: {
            root.assertCondition("ADV.TMO.REAL.02", "At t=5s, connection is still pending (not premature)",
                NetworkService.connectingSsid === "EmpiricalHangAP" && NetworkService.isConnecting === true && root.failedSignalCount === 0,
                "connectingSsid=" + NetworkService.connectingSsid + ", failedCount=" + root.failedSignalCount);
        }
    }

    // Watchdog check at t = 10500ms: watchdog ran at 10s without killing active connecting state
    Timer {
        id: checkWatchdogTimer
        interval: 10500
        repeat: false
        onTriggered: {
            root.assertCondition("ADV.TMO.REAL.03", "At t=10.5s, watchdog re-evaluation did not abort connectingSsid",
                NetworkService.connectingSsid === "EmpiricalHangAP" && NetworkService.isConnecting === true,
                "connectingSsid=" + NetworkService.connectingSsid);
        }
    }

    // Final check at t = 15300ms: timeout must have fired (interval = 15000ms)
    Timer {
        id: checkFinalTimeoutTimer
        interval: 15300
        repeat: false
        onTriggered: {
            console.log("[TEST] Checking t=15.3s timeout resolution results...");

            root.assertCondition("ADV.TMO.REAL.04", "connectingSsid cleared to empty string after 15s",
                NetworkService.connectingSsid === "",
                "connectingSsid=" + NetworkService.connectingSsid);

            root.assertCondition("ADV.TMO.REAL.05", "isConnecting is false after timeout",
                NetworkService.isConnecting === false,
                "isConnecting=" + NetworkService.isConnecting);

            root.assertCondition("ADV.TMO.REAL.06", "lastError populated with 'Connection timed out'",
                NetworkService.lastError === "Connection timed out",
                "lastError=" + NetworkService.lastError);

            root.assertCondition("ADV.TMO.REAL.07", "connectionFailed signal emitted exactly once",
                root.failedSignalCount === 1,
                "failedSignalCount=" + root.failedSignalCount);

            root.assertCondition("ADV.TMO.REAL.08", "connectionFailed signal parameters match timed out SSID and reason",
                root.lastFailedSsid === "EmpiricalHangAP" && root.lastFailedReason === "Connection timed out",
                "ssid=" + root.lastFailedSsid + ", reason=" + root.lastFailedReason);

            // Reset state
            NetworkService.lastError = "";
            NetworkService._applyDisconnectedState();

            console.log("================================================================");
            console.log("EMPIRICAL M4 ADVERSARIAL RESULTS: Passed=" + root.passCount + ", Failed=" + root.failCount);
            if (root.failCount === 0) {
                console.log("=== PASS: M4 ADVERSARIAL RUNTIME HARNESS COMPLETED SUCCESSFULLY ===");
            } else {
                console.error("=== FAIL: M4 ADVERSARIAL RUNTIME HARNESS HAD FAILURES ===");
            }
            console.log("================================================================");

            Qt.quit();
        }
    }
}
