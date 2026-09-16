pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import desktop.services
import desktop.core
import desktop.surfaces.components

Scope {
    id: testRoot

    property bool closeSignalReceived: false
    property int closeSignalCount: 0

    BluetoothPopup {
        id: popup

        onCloseRequested: {
            testRoot.closeSignalReceived = true;
            testRoot.closeSignalCount++;
        }
    }

    Timer {
        id: testTimer
        interval: 150
        running: true
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
            console.log("=== EMPIRICAL CHALLENGER: BLUETOOTH POPUP COMPONENT (M3) ===");
            console.log("================================================================");

            // =================================================================
            // 1. Geometry, Dimensions & Theme Tokens
            // =================================================================
            assert("POP.GEO.01", "BluetoothPopup instantiates cleanly", popup !== null && popup !== undefined, "popup=" + popup);
            assert("POP.GEO.02", "Popup width is exactly 320px", popup.width === 320, "width=" + popup.width);
            assert("POP.GEO.03", "Popup implicitWidth is exactly 320px", popup.implicitWidth === 320, "implicitWidth=" + popup.implicitWidth);
            assert("POP.GEO.04", "Popup surface color matches Theme.gray900", popup.color.toString().toLowerCase() === Theme.gray900.toString().toLowerCase(), "color=" + popup.color);
            assert("POP.GEO.05", "Popup border color matches Theme.borderMuted", popup.border.color.toString().toLowerCase() === Theme.borderMuted.toString().toLowerCase(), "border=" + popup.border.color);
            assert("POP.GEO.06", "Popup border width matches Theme.borderWidth", popup.border.width === Theme.borderWidth, "borderWidth=" + popup.border.width);
            assert("POP.GEO.07", "Popup radius matches Theme.radiusSmall", popup.radius === Theme.radiusSmall, "radius=" + popup.radius);

            let mainCol = popup.children[2];
            assert("POP.GEO.08", "Popup implicitHeight dynamically bounds to mainColumn + paddingLarge*2",
                popup.implicitHeight === mainCol.implicitHeight + Theme.paddingLarge * 2,
                "implicitHeight=" + popup.implicitHeight);

            // =================================================================
            // 2. Click Shield (Root MouseArea)
            // =================================================================
            let shieldMouse = popup.children[0];
            assert("POP.SHIELD.01", "Shield MouseArea is first child of root", shieldMouse !== null && shieldMouse !== undefined, "shield=" + shieldMouse);
            assert("POP.SHIELD.02", "Shield MouseArea fills parent", shieldMouse.anchors.fill === popup, "anchors.fill=" + shieldMouse.anchors.fill);
            assert("POP.SHIELD.03", "Shield MouseArea has preventStealing: true", shieldMouse.preventStealing === true, "preventStealing=" + shieldMouse.preventStealing);
            assert("POP.SHIELD.04", "Shield MouseArea has hoverEnabled: true", shieldMouse.hoverEnabled === true, "hoverEnabled=" + shieldMouse.hoverEnabled);
            assert("POP.SHIELD.05", "Shield MouseArea is stacked below mainColumn (z: 0 vs later sibling)", shieldMouse.z <= mainCol.z, "shieldZ=" + shieldMouse.z + ", mainColZ=" + mainCol.z);

            // =================================================================
            // 3. Cyberpunk Corner Brackets
            // =================================================================
            let bracketsItem = popup.children[1];
            assert("POP.BRACKET.01", "Corner brackets container item exists", bracketsItem !== null && bracketsItem !== undefined, "brackets=" + bracketsItem);
            assert("POP.BRACKET.02", "Corner brackets z-index is 10", bracketsItem.z === 10, "z=" + bracketsItem.z);
            assert("POP.BRACKET.03", "Corner brackets bracketColor is Theme.acidGreen", bracketsItem.bracketColor.toString().toLowerCase() === Theme.acidGreen.toString().toLowerCase(), "color=" + bracketsItem.bracketColor);
            assert("POP.BRACKET.04", "Corner brackets has exactly 8 arm rectangles", bracketsItem.children.length === 8, "count=" + bracketsItem.children.length);

            let armDimsValid = true;
            let armColorsValid = true;
            for (let i = 0; i < bracketsItem.children.length; ++i) {
                let rect = bracketsItem.children[i];
                let isHoriz = (rect.width === Theme.cornerBracketArmLength && rect.height === Theme.cornerBracketThickness);
                let isVert = (rect.width === Theme.cornerBracketThickness && rect.height === Theme.cornerBracketArmLength);
                if (!isHoriz && !isVert) armDimsValid = false;
                if (rect.color.toString().toLowerCase() !== Theme.acidGreen.toString().toLowerCase()) armColorsValid = false;
            }
            assert("POP.BRACKET.05", "All 8 arms match Theme.cornerBracketArmLength (7) & Theme.cornerBracketThickness (1)", armDimsValid, "dimsValid=" + armDimsValid);
            assert("POP.BRACKET.06", "All 8 arms use Theme.acidGreen color token", armColorsValid, "colorsValid=" + armColorsValid);

            // =================================================================
            // 4. Runtime Typography Inspection (100% Theme.fontFamilyMonospace)
            // =================================================================
            function collectTextElements(item, list) {
                if (!item) return;
                if (item.font && item.font.family !== undefined) {
                    list.push(item);
                }
                if (item.children) {
                    for (let c = 0; c < item.children.length; c++) {
                        collectTextElements(item.children[c], list);
                    }
                }
            }
            let instantiatedTexts = [];
            collectTextElements(popup, instantiatedTexts);
            let nonMonospaceTexts = instantiatedTexts.filter(t => t.font.family !== Theme.fontFamilyMonospace);
            assert("POP.TYPO.01", "Instantiated Text elements found in popup", instantiatedTexts.length > 0, "count=" + instantiatedTexts.length);
            assert("POP.TYPO.02", "100% of instantiated Text elements use Theme.fontFamilyMonospace (" + Theme.fontFamilyMonospace + ")",
                nonMonospaceTexts.length === 0, "violations=" + nonMonospaceTexts.length);

            // =================================================================
            // 5. Header Controls & closeRequested Signal
            // =================================================================
            let headerRow = mainCol.children[0];
            let pwrBtn = headerRow.children[0];
            let titleText = headerRow.children[1];
            let scanBtn = headerRow.children[2];
            let closeBtn = headerRow.children[3];

            assert("POP.HDR.01", "Header row has 4 elements", headerRow.children.length === 4, "count=" + headerRow.children.length);
            assert("POP.HDR.02", "Title text is 'BLUETOOTH // RADIO'", titleText.text === "BLUETOOTH // RADIO", "text=" + titleText.text);
            assert("POP.HDR.03", "Title font family is monospace", titleText.font.family === Theme.fontFamilyMonospace, "font=" + titleText.font.family);

            let closeMouse = closeBtn.children[1];
            assert("POP.CLOSE.01", "Close button MouseArea exists", closeMouse !== null && closeMouse !== undefined, "closeMouse=" + closeMouse);
            assert("POP.CLOSE.02", "closeSignalReceived initially false", testRoot.closeSignalReceived === false, "received=" + testRoot.closeSignalReceived);

            closeMouse.clicked(null);
            assert("POP.CLOSE.03", "Clicking close button emits closeRequested signal", testRoot.closeSignalReceived === true && testRoot.closeSignalCount === 1,
                "count=" + testRoot.closeSignalCount);

            closeMouse.clicked(null);
            assert("POP.CLOSE.04", "Subsequent close click increments close signal count to 2", testRoot.closeSignalCount === 2,
                "count=" + testRoot.closeSignalCount);

            // =================================================================
            // 6. Power Toggle Interaction & States
            // =================================================================
            let pwrLabel = pwrBtn.children[0];
            let pwrMouse = pwrBtn.children[1];

            // State A: Radio Powered Off
            BluetoothService._parseShowOutput("Controller AA:BB:CC:DD:EE:FF Host\n\tPowered: no\n\tPowerState: off\n");
            assert("POP.PWR.01", "Power button label is '[PWR OFF]' when powered=false", pwrLabel.text === "[PWR OFF]", "text=" + pwrLabel.text);
            assert("POP.PWR.02", "Power button enabled when service available", pwrMouse.enabled === true, "enabled=" + pwrMouse.enabled);

            // State B: Radio Powered On
            BluetoothService._parseShowOutput("Controller AA:BB:CC:DD:EE:FF Host\n\tPowered: yes\n\tPowerState: on\n");
            assert("POP.PWR.03", "Power button label transitions to '[PWR ON]' when powered=true", pwrLabel.text === "[PWR ON]", "text=" + pwrLabel.text);
            assert("POP.PWR.04", "Power button border highlights with Theme.accent when powered=true",
                pwrBtn.border.color.toString().toLowerCase() === Theme.accent.toString().toLowerCase(), "border=" + pwrBtn.border.color);

            // State C: Controller Missing / Unavailable
            BluetoothService._parseShowOutput("No default controller available\n");
            assert("POP.PWR.05", "Power button is disabled when BluetoothService.available=false", pwrMouse.enabled === false, "enabled=" + pwrMouse.enabled);
            assert("POP.PWR.06", "Power button border shows Theme.textDisabled when unavailable",
                pwrBtn.border.color.toString().toLowerCase() === Theme.textDisabled.toString().toLowerCase(), "border=" + pwrBtn.border.color);

            // Restore powered state
            BluetoothService._parseShowOutput("Controller AA:BB:CC:DD:EE:FF Host\n\tPowered: yes\n\tPowerState: on\n");

            // =================================================================
            // 7. Scan Toggle Interaction & States
            // =================================================================
            let scanLabel = scanBtn.children[0];
            let scanMouse = scanBtn.children[1];

            // Scan Idle
            BluetoothService._isScanning = false;
            assert("POP.SCAN.01", "Scan button label is '[SCAN]' when not scanning", scanLabel.text === "[SCAN]", "text=" + scanLabel.text);
            assert("POP.SCAN.02", "Scan button enabled when radio is powered", scanMouse.enabled === true, "enabled=" + scanMouse.enabled);
            assert("POP.SCAN.03", "Scan button opacity is 1.0 when radio is powered", scanBtn.opacity === 1.0, "opacity=" + scanBtn.opacity);

            // Scan Active
            BluetoothService._isScanning = true;
            assert("POP.SCAN.04", "Scan button label is '[SCANNING]' when isScanning=true", scanLabel.text === "[SCANNING]", "text=" + scanLabel.text);
            assert("POP.SCAN.05", "Scan button border highlights with Theme.accent when isScanning=true",
                scanBtn.border.color.toString().toLowerCase() === Theme.accent.toString().toLowerCase(), "border=" + scanBtn.border.color);
            assert("POP.SCAN.06", "Scan button background is Theme.surfaceSelected when scanning",
                scanBtn.color.toString().toLowerCase() === Theme.surfaceSelected.toString().toLowerCase(), "color=" + scanBtn.color);

            // Scan Disabled when Powered Off
            BluetoothService._parseShowOutput("Controller AA:BB:CC:DD:EE:FF Host\n\tPowered: no\n\tPowerState: off\n");
            assert("POP.SCAN.07", "Scan button disabled when powered=false", scanMouse.enabled === false, "enabled=" + scanMouse.enabled);
            assert("POP.SCAN.08", "Scan button dimmed (opacity 0.4) when powered=false", scanBtn.opacity === 0.4, "opacity=" + scanBtn.opacity);

            // =================================================================
            // 8. Empty States Handling
            // =================================================================
            let body = mainCol.children[2];
            let radioOffEmptyState = body.children[0];
            let noDevicesEmptyState = body.children[1];
            let deviceFlick = body.children[2];
            let footerRow = mainCol.children[4];
            let footerStatusText = footerRow.children[0];

            BluetoothService._clearAllDevices();

            // 8.1 Radio Off State
            BluetoothService._parseShowOutput("Controller AA:BB:CC:DD:EE:FF Host\n\tPowered: no\n\tPowerState: off\n");
            assert("POP.STATE.OFF.01", "Radio Off empty state container visible", radioOffEmptyState.visible === true, "visible=" + radioOffEmptyState.visible);
            assert("POP.STATE.OFF.02", "No Devices empty state container hidden", noDevicesEmptyState.visible === false, "visible=" + noDevicesEmptyState.visible);
            assert("POP.STATE.OFF.03", "Device Flickable hidden when powered=false", deviceFlick.visible === false, "visible=" + deviceFlick.visible);
            assert("POP.STATE.OFF.04", "Footer text indicates '// STATUS: OFF'", footerStatusText.text === "// STATUS: OFF", "status=" + footerStatusText.text);

            // 8.2 Powered On, No Devices Discovered
            BluetoothService._parseShowOutput("Controller AA:BB:CC:DD:EE:FF Host\n\tPowered: yes\n\tPowerState: on\n");
            BluetoothService._isScanning = false;
            assert("POP.STATE.EMPTY.01", "Radio Off empty state hidden when powered=true", radioOffEmptyState.visible === false, "visible=" + radioOffEmptyState.visible);
            assert("POP.STATE.EMPTY.02", "No Devices empty state visible when 0 devices", noDevicesEmptyState.visible === true, "visible=" + noDevicesEmptyState.visible);
            assert("POP.STATE.EMPTY.03", "Device Flickable hidden when 0 devices", deviceFlick.visible === false, "visible=" + deviceFlick.visible);
            assert("POP.STATE.EMPTY.04", "Empty prompt advises clicking [SCAN]", noDevicesEmptyState.children[1].text.indexOf("CLICK [SCAN] TO DISCOVER") !== -1,
                "text=" + noDevicesEmptyState.children[1].text);
            assert("POP.STATE.EMPTY.05", "Footer status displays '// STATUS: STANDBY'", footerStatusText.text === "// STATUS: STANDBY", "status=" + footerStatusText.text);

            // 8.3 Scanning With No Devices Discovered
            BluetoothService._isScanning = true;
            assert("POP.STATE.SCAN.01", "Empty prompt transitions to '// SCANNING FOR NEARBY DEVICES...'",
                noDevicesEmptyState.children[1].text.indexOf("SCANNING FOR NEARBY DEVICES") !== -1, "text=" + noDevicesEmptyState.children[1].text);
            assert("POP.STATE.SCAN.02", "Footer status displays '// STATUS: SCANNING...'", footerStatusText.text === "// STATUS: SCANNING...", "status=" + footerStatusText.text);
            BluetoothService._isScanning = false;

            // =================================================================
            // 9. Device Sections (Connected, Paired, Discovered)
            // =================================================================
            BluetoothService._clearAllDevices();

            // Add 1 Connected Device, 1 Paired Device, 1 Discovered Device
            BluetoothService._parseConnectedOutput("Device 11:22:33:44:55:66 Cyberdeck Audio\n");
            BluetoothService._parsePairedOutput("Device 22:33:44:55:66:77 Mechanical Keyboard\n");
            BluetoothService._parseDevicesOutput("Device 33:44:55:66:77:88 AR Neural Visor\n");

            let devCol = deviceFlick.contentItem.children[0];
            let connSection = devCol.children[0];
            let pairedSection = devCol.children[1];
            let availSection = devCol.children[2];

            assert("POP.DEV.01", "Device Flickable visible when devices present", deviceFlick.visible === true, "visible=" + deviceFlick.visible);
            assert("POP.DEV.02", "No Devices empty state hidden when devices present", noDevicesEmptyState.visible === false, "visible=" + noDevicesEmptyState.visible);
            assert("POP.DEV.03", "Connected section visible", connSection.visible === true, "visible=" + connSection.visible);
            assert("POP.DEV.04", "Paired section visible", pairedSection.visible === true, "visible=" + pairedSection.visible);
            assert("POP.DEV.05", "Available section visible", availSection.visible === true, "visible=" + availSection.visible);

            assert("POP.DEV.06", "Connected header indicates count 1", connSection.children[0].children[1].text === "// CONNECTED (1)",
                "header=" + connSection.children[0].children[1].text);
            assert("POP.DEV.07", "Paired header indicates count 1", pairedSection.children[0].children[1].text === "// PAIRED (1)",
                "header=" + pairedSection.children[0].children[1].text);
            assert("POP.DEV.08", "Discovered header indicates count 1", availSection.children[0].children[1].text === "// DISCOVERED (1)",
                "header=" + availSection.children[0].children[1].text);
            assert("POP.DEV.09", "Footer status indicates '// STATUS: CONNECTED'", footerStatusText.text === "// STATUS: CONNECTED", "status=" + footerStatusText.text);

            // =================================================================
            // 10. Action Buttons Wiring & Pending State Verification
            // =================================================================
            // 10.1 Disconnect Button
            let connTile = connSection.children[1]; // First item created by Repeater
            let connInnerCol = connTile.children[1];
            let connRow1 = connInnerCol.children[0];
            let disconnectBtn = connRow1.children[2];
            let disconnectLabel = disconnectBtn.children[0];
            let disconnectMouse = disconnectBtn.children[1];

            assert("POP.ACT.DISC.01", "Disconnect button label is '[DISCONNECT]'", disconnectLabel.text === "[DISCONNECT]", "text=" + disconnectLabel.text);
            assert("POP.ACT.DISC.02", "Disconnect button enabled initially", disconnectMouse.enabled === true, "enabled=" + disconnectMouse.enabled);

            // Test in-flight action state on disconnect
            BluetoothService._actionTargetMac = "11:22:33:44:55:66";
            BluetoothService._actionType = "disconnect";
            assert("POP.ACT.DISC.03", "Disconnect label shows '[WAIT...]' during pending action", disconnectLabel.text === "[WAIT...]", "text=" + disconnectLabel.text);
            assert("POP.ACT.DISC.04", "Disconnect button disabled during pending action", disconnectMouse.enabled === false, "enabled=" + disconnectMouse.enabled);
            BluetoothService._actionTargetMac = "";
            BluetoothService._actionType = "";

            // 10.2 Connect & Forget Buttons in Paired Section
            let pairedTile = pairedSection.children[1];
            let pairedInnerCol = pairedTile.children[0];
            let pairedRow1 = pairedInnerCol.children[0];
            let connectBtn = pairedRow1.children[2];
            let connectLabel = connectBtn.children[0];
            let connectMouse = connectBtn.children[1];
            let forgetBtn = pairedRow1.children[3];
            let forgetLabel = forgetBtn.children[0];
            let forgetMouse = forgetBtn.children[1];

            assert("POP.ACT.CONN.01", "Connect button label is '[CONNECT]'", connectLabel.text === "[CONNECT]", "text=" + connectLabel.text);
            assert("POP.ACT.FORGET.01", "Forget button label is 'x'", forgetLabel.text === "x", "text=" + forgetLabel.text);

            // Test in-flight action state on connect
            BluetoothService._actionTargetMac = "22:33:44:55:66:77";
            BluetoothService._actionType = "connect";
            assert("POP.ACT.CONN.02", "Connect label shows '[CONN...]' during pending connection", connectLabel.text === "[CONN...]", "text=" + connectLabel.text);
            assert("POP.ACT.CONN.03", "Connect button disabled during pending action", connectMouse.enabled === false, "enabled=" + connectMouse.enabled);
            assert("POP.ACT.FORGET.02", "Forget button disabled during pending action", forgetMouse.enabled === false, "enabled=" + forgetMouse.enabled);
            BluetoothService._actionTargetMac = "";
            BluetoothService._actionType = "";

            // 10.3 Pair Button in Discovered Section
            let availTile = availSection.children[1];
            let availInnerCol = availTile.children[0];
            let availRow1 = availInnerCol.children[0];
            let pairBtn = availRow1.children[2];
            let pairLabel = pairBtn.children[0];
            let pairMouse = pairBtn.children[1];

            assert("POP.ACT.PAIR.01", "Pair button label is '[PAIR]'", pairLabel.text === "[PAIR]", "text=" + pairLabel.text);
            assert("POP.ACT.PAIR.02", "Pair button enabled initially", pairMouse.enabled === true, "enabled=" + pairMouse.enabled);

            // Test in-flight action state on pair
            BluetoothService._actionTargetMac = "33:44:55:66:77:88";
            BluetoothService._actionType = "pair";
            assert("POP.ACT.PAIR.03", "Pair label shows '[PAIRING...]' during pending pairing", pairLabel.text === "[PAIRING...]", "text=" + pairLabel.text);
            assert("POP.ACT.PAIR.04", "Pair button disabled during pending action", pairMouse.enabled === false, "enabled=" + pairMouse.enabled);
            BluetoothService._actionTargetMac = "";
            BluetoothService._actionType = "";

            // 10.4 Refresh Button in Footer
            let refreshBtn = footerRow.children[1];
            let refreshLabel = refreshBtn.children[0];
            let refreshMouse = refreshBtn.children[1];
            assert("POP.ACT.REFRESH.01", "Refresh button exists in footer", refreshBtn !== null && refreshBtn !== undefined, "btn=" + refreshBtn);
            assert("POP.ACT.REFRESH.02", "Refresh button label is '[REFRESH]'", refreshLabel.text === "[REFRESH]", "text=" + refreshLabel.text);
            assert("POP.ACT.REFRESH.03", "Refresh button has clickable MouseArea", refreshMouse !== null && refreshMouse !== undefined, "mouse=" + refreshMouse);

            // =================================================================
            // 11. RF Density Stress & Geometry Clamping
            // =================================================================
            let bulkDevices = "";
            for (let i = 1; i <= 30; i++) {
                let hex = (i < 16 ? "0" : "") + i.toString(16).toUpperCase();
                bulkDevices += "Device D0:00:00:00:00:" + hex + " Stress Node #" + i + "\n";
            }
            BluetoothService._parseDevicesOutput(bulkDevices);
            assert("POP.STRESS.01", "Successfully loaded 30+ discovery devices", BluetoothService.availableDevices.length >= 30, "count=" + BluetoothService.availableDevices.length);
            assert("POP.STRESS.02", "Body container preferred height clamped to maximum 320px", body.Layout.preferredHeight <= 320, "h=" + body.Layout.preferredHeight);
            assert("POP.STRESS.03", "Device flickable clip is enabled to prevent content bleeding", deviceFlick.clip === true, "clip=" + deviceFlick.clip);

            // Cleanup
            BluetoothService._clearAllDevices();
            BluetoothService.refresh();

            // =================================================================
            // Summary
            // =================================================================
            console.log("================================================================");
            console.log("M3 CHALLENGER POPUP RESULTS: Passed=" + passCount + ", Failed=" + failCount);
            if (failCount === 0) {
                console.log("=== PASS: M3 CHALLENGER BLUETOOTH POPUP HARNESS SUCCESSFUL ===");
            } else {
                console.error("=== FAIL: M3 CHALLENGER BLUETOOTH POPUP HARNESS FAILED ===");
            }
            console.log("================================================================");

            Qt.quit();
        }
    }
}
