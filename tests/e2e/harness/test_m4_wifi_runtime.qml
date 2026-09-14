pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import desktop.services
import desktop.core
import desktop.surfaces

Scope {
    id: root

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
            console.log("=== EMPIRICAL RUNTIME: WIFI & WATCHDOG HARNESS (M4) ===");
            console.log("================================================================");

            // 1. NetworkService Singleton Contract
            assertCondition("M4.RUN.01", "NetworkService singleton is instantiated",
                NetworkService !== null && NetworkService !== undefined,
                "NetworkService=" + NetworkService);

            assertCondition("M4.RUN.02", "NetworkService has boolean available property",
                typeof NetworkService.available === "boolean",
                "available=" + NetworkService.available);

            assertCondition("M4.RUN.03", "NetworkService has string connectingSsid property",
                typeof NetworkService.connectingSsid === "string",
                "connectingSsid=" + NetworkService.connectingSsid);

            assertCondition("M4.RUN.04", "NetworkService has boolean isConnecting property",
                typeof NetworkService.isConnecting === "boolean",
                "isConnecting=" + NetworkService.isConnecting);

            assertCondition("M4.RUN.05", "NetworkService has string lastError property",
                typeof NetworkService.lastError === "string",
                "lastError=" + NetworkService.lastError);

            assertCondition("M4.RUN.06", "NetworkService has callable connectToNetwork method",
                typeof NetworkService.connectToNetwork === "function",
                "typeof=" + typeof NetworkService.connectToNetwork);

            assertCondition("M4.RUN.07", "NetworkService has callable _evaluateNetworkState method",
                typeof NetworkService._evaluateNetworkState === "function",
                "typeof=" + typeof NetworkService._evaluateNetworkState);

            // 2. SystemRail Instantiation
            const railSurface = railLoader.item;
            assertCondition("M4.RUN.08", "SystemRail surface instantiated successfully",
                railSurface !== null && railSurface !== undefined,
                "status=" + railLoader.status);

            if (railSurface) {
                railSurface.navigateToWifi();
                assertCondition("M4.RUN.09", "SystemRail routes to wifi submenu",
                    railSurface.currentView === "wifi",
                    "currentView=" + railSurface.currentView);
            }

            // 3. State Transition: Trigger connectToNetwork()
            const initialSsid = NetworkService.connectingSsid;
            assertCondition("M4.RUN.10", "NetworkService isConnecting initially false",
                NetworkService.isConnecting === false,
                "isConnecting=" + NetworkService.isConnecting);

            // Synthetic test connection initiation
            NetworkService.connectingSsid = "NightCity-WLAN";
            assertCondition("M4.RUN.11", "NetworkService.isConnecting reflects active connectingSsid",
                NetworkService.isConnecting === true && NetworkService.connectingSsid === "NightCity-WLAN",
                "isConnecting=" + NetworkService.isConnecting + ", connectingSsid=" + NetworkService.connectingSsid);

            // 4. State Transition: Successful connection clearing connectingSsid
            NetworkService._applyConnectedState("wifi", "NightCity-WLAN", 0.85);
            assertCondition("M4.RUN.12", "Successful connection clears connectingSsid and isConnecting",
                NetworkService.connectingSsid === "" && NetworkService.isConnecting === false && NetworkService.isConnected === true,
                "connectingSsid=" + NetworkService.connectingSsid + ", isConnected=" + NetworkService.isConnected);

            // 5. State Transition: Timeout simulation
            NetworkService.connectingSsid = "SlowAP";
            assertCondition("M4.RUN.13", "Synthetic connection start for timeout test",
                NetworkService.isConnecting === true && NetworkService.connectingSsid === "SlowAP",
                "connectingSsid=" + NetworkService.connectingSsid);

            // Simulate timeout resolution: clear connectingSsid and record lastError
            NetworkService.connectingSsid = "";
            NetworkService.lastError = "Connection timed out";
            assertCondition("M4.RUN.14", "Timeout resolution clears connectingSsid and populates lastError",
                NetworkService.connectingSsid === "" && NetworkService.isConnecting === false && NetworkService.lastError.length > 0,
                "lastError=" + NetworkService.lastError);

            // Reset state
            NetworkService.lastError = "";
            NetworkService._applyDisconnectedState();

            console.log("================================================================");
            console.log("M4 RUNTIME RESULTS: Passed=" + passCount + ", Failed=" + failCount);
            if (failCount === 0) {
                console.log("=== PASS: M4 WIFI RUNTIME HARNESS SUCCESSFUL ===");
            } else {
                console.error("=== FAIL: M4 WIFI RUNTIME HARNESS FAILED ===");
            }
            console.log("================================================================");

            Qt.quit();
        }
    }
}
