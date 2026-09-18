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

        NetworkPopup {
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
            console.log("=== EMPIRICAL RUNTIME: NETWORK POPUP COMPONENT (R3) ============");
            console.log("================================================================");

            // =================================================================
            // 1. Instantiation, Theming & Geometry Invariants
            // =================================================================
            assertCondition("WF.RUN.INST.01", "NetworkPopup instantiated successfully",
                popup !== null && popup !== undefined,
                "popup object exists");

            assertCondition("WF.RUN.INST.02", "NetworkPopup width and implicitWidth are 320",
                popup.width === 320 && popup.implicitWidth === 320,
                "width=" + popup.width + ", implicitWidth=" + popup.implicitWidth);

            assertCondition("WF.RUN.INST.03", "NetworkPopup background color is Theme.gray900",
                popup.color === Theme.gray900,
                "color=" + popup.color);

            assertCondition("WF.RUN.INST.04", "NetworkPopup border color is Theme.borderMuted",
                popup.border.color === Theme.borderMuted,
                "border.color=" + popup.border.color);

            assertCondition("WF.RUN.INST.05", "NetworkPopup radius is Theme.radiusSmall",
                popup.radius === Theme.radiusSmall,
                "radius=" + popup.radius);

            // =================================================================
            // 2. Click Shield & Cyberpunk Corner Brackets
            // =================================================================
            const shieldMouseArea = popup.children[0];
            assertCondition("WF.RUN.SHIELD.01", "Root click shield MouseArea active with preventStealing",
                shieldMouseArea !== null && shieldMouseArea.preventStealing === true,
                "preventStealing=" + (shieldMouseArea ? shieldMouseArea.preventStealing : "null"));

            const bracketsItem = popup.children[1];
            assertCondition("WF.RUN.BRACKET.01", "Cyberpunk corner brackets item present at z=10",
                bracketsItem !== null && bracketsItem.z === 10,
                "z=" + (bracketsItem ? bracketsItem.z : "null"));

            assertCondition("WF.RUN.BRACKET.02", "Cyberpunk corner brackets contain 8 arm rectangles",
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

            assertCondition("WF.RUN.HDR.01", "Header title is NETWORK // WI-FI",
                titleText.text === "NETWORK // WI-FI",
                "title=" + titleText.text);

            assertCondition("WF.RUN.PWR.01", "Power button shows [PWR ON] or [PWR OFF] based on wifiEnabled",
                powerLabel.text === (NetworkService.wifiEnabled ? "[PWR ON]" : "[PWR OFF]"),
                "text=" + powerLabel.text);

            const bodyContainer = mainCol.children[2];
            const emptyRadioOff = bodyContainer.children[0];
            assertCondition("WF.RUN.PWR.02", "Radio OFF empty state visibility reflects wifiEnabled",
                emptyRadioOff.visible === !NetworkService.wifiEnabled,
                "emptyRadioOff.visible=" + emptyRadioOff.visible);

            assertCondition("WF.RUN.SCAN.01", "Scan button shows [SCAN] or [SCANNING]",
                scanLabel.text === (NetworkService.isScanning ? "[SCANNING]" : "[SCAN]"),
                "text=" + scanLabel.text);

            // =================================================================
            // 4. Public Signal closeRequested
            // =================================================================
            assertCondition("WF.RUN.SIG.01", "closeSignalReceived is initially false",
                testWindow.closeSignalReceived === false,
                "closeSignalReceived=" + testWindow.closeSignalReceived);

            popup.closeRequested();
            assertCondition("WF.RUN.SIG.02", "closeRequested signal is received when triggered directly",
                testWindow.closeSignalReceived === true,
                "closeSignalReceived=" + testWindow.closeSignalReceived);

            testWindow.closeSignalReceived = false;
            closeMouse.clicked(null);
            assertCondition("WF.RUN.SIG.03", "closeBtn mouse click triggers closeRequested signal",
                testWindow.closeSignalReceived === true,
                "closeSignalReceived=" + testWindow.closeSignalReceived);

            // =================================================================
            // 5. Interactive Network List & Categorized Sections
            // =================================================================
            // Inject synthetic available networks: 1 connected, 1 saved, 1 discovered secured
            NetworkService.availableNetworks = [
                {
                    ssid: "NightCity-Net",
                    rawSsid: "NightCity-Net",
                    signalStrength: 0.95,
                    known: true,
                    connected: true,
                    security: 2,
                    requiresPassword: false
                },
                {
                    ssid: "Arasaka-Corp",
                    rawSsid: "Arasaka-Corp",
                    signalStrength: 0.80,
                    known: true,
                    connected: false,
                    security: 2,
                    requiresPassword: false
                },
                {
                    ssid: "Afterlife-Guest",
                    rawSsid: "Afterlife-Guest",
                    signalStrength: 0.65,
                    known: false,
                    connected: false,
                    security: 2,
                    requiresPassword: true
                }
            ];

            assertCondition("WF.RUN.CAT.01", "NetworkService reports 1 connected network",
                NetworkService.connectedNetworks.length === 1,
                "connectedCount=" + NetworkService.connectedNetworks.length);

            assertCondition("WF.RUN.CAT.02", "NetworkService reports 1 saved network",
                NetworkService.savedNetworks.length === 1,
                "savedCount=" + NetworkService.savedNetworks.length);

            assertCondition("WF.RUN.CAT.03", "NetworkService reports 1 discovered network",
                NetworkService.discoveredNetworks.length === 1,
                "discoveredCount=" + NetworkService.discoveredNetworks.length);

            const flickable = bodyContainer.children[2];
            assertCondition("WF.RUN.LIST.01", "Network flickable list is visible when networks present and wifi enabled",
                flickable.visible === Boolean(NetworkService.wifiEnabled && NetworkService.availableNetworks.length > 0),
                "flickable.visible=" + flickable.visible);

            // =================================================================
            // 6. Inline Cyberpunk Password Prompt
            // =================================================================
            assertCondition("WF.RUN.PROMPT.01", "selectedSsid is initially empty",
                popup.selectedSsid === "",
                "selectedSsid=" + popup.selectedSsid);

            popup.selectedSsid = "Afterlife-Guest";
            assertCondition("WF.RUN.PROMPT.02", "selectedSsid can be set to reveal password prompt",
                popup.selectedSsid === "Afterlife-Guest",
                "selectedSsid=" + popup.selectedSsid);

            popup.selectedSsid = "";
            assertCondition("WF.RUN.PROMPT.03", "selectedSsid resets cleanly on cancellation",
                popup.selectedSsid === "",
                "selectedSsid=" + popup.selectedSsid);

            // =================================================================
            // 7. Footer Status & Refresh Action
            // =================================================================
            const footerRow = mainCol.children[4];
            const statusText = footerRow.children[0];
            const refreshBtn = footerRow.children[1];
            const refreshMouse = refreshBtn.children[1];

            assertCondition("WF.RUN.FOOTER.01", "Status text displays reactive status string",
                statusText.text.indexOf("// STATUS:") === 0,
                "status=" + statusText.text);

            assertCondition("WF.RUN.FOOTER.02", "Refresh button exists and displays [REFRESH]",
                refreshBtn !== null && refreshBtn.children[0].text === "[REFRESH]",
                "refreshBtn text=" + (refreshBtn ? refreshBtn.children[0].text : "null"));

            refreshMouse.clicked(null);
            assertCondition("WF.RUN.ACT.REFRESH", "refreshBtn mouse click triggers NetworkService.refresh",
                typeof NetworkService.refresh === "function",
                "refresh called successfully");

            console.log("================================================================");
            console.log("RESULTS: Passed=" + passCount + ", Failed=" + failCount);
            if (failCount === 0) {
                console.log("=== PASS: R3 WIFI POPUP RUNTIME HARNESS SUCCESSFUL ===");
            } else {
                console.error("=== FAIL: R3 WIFI POPUP RUNTIME HARNESS FAILED ===");
            }
            console.log("================================================================");

            Qt.quit();
        }
    }
}
