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
            console.log("=== EMPIRICAL CHALLENGER: BLUETOOTH POPUP RUNTIME TEST (M3) ===");
            console.log("================================================================");

            // =================================================================
            // 1. Root Component Geometry & Theme Tokens
            // =================================================================
            assert("POP.GEO.01", "Popup instantiates successfully", popup !== null && popup !== undefined, "popup=" + popup);
            assert("POP.GEO.02", "Popup width is 320", popup.width === 320, "width=" + popup.width);
            assert("POP.GEO.03", "Popup implicitWidth is 320", popup.implicitWidth === 320, "implicitWidth=" + popup.implicitWidth);
            assert("POP.GEO.04", "Popup surface color matches Theme.gray900", popup.color.toString().toLowerCase() === Theme.gray900.toString().toLowerCase(), "color=" + popup.color);
            assert("POP.GEO.05", "Popup border color matches Theme.borderMuted", popup.border.color.toString().toLowerCase() === Theme.borderMuted.toString().toLowerCase(), "border=" + popup.border.color);
            assert("POP.GEO.06", "Popup border width matches Theme.borderWidth", popup.border.width === Theme.borderWidth, "width=" + popup.border.width);
            assert("POP.GEO.07", "Popup corner radius matches Theme.radiusSmall", popup.radius === Theme.radiusSmall, "radius=" + popup.radius);

            // =================================================================
            // 2. Backdrop Shield MouseArea
            // =================================================================
            let shieldMouse = popup.children[0];
            assert("POP.SHIELD.01", "Shield MouseArea exists", shieldMouse !== null && shieldMouse !== undefined, "shield=" + shieldMouse);
            assert("POP.SHIELD.02", "Shield MouseArea fills parent", shieldMouse.anchors.fill === popup, "fill=" + shieldMouse.anchors.fill);
            assert("POP.SHIELD.03", "Shield MouseArea has preventStealing enabled", shieldMouse.preventStealing === true, "preventStealing=" + shieldMouse.preventStealing);

            // =================================================================
            // 3. Cyberpunk Corner Brackets
            // =================================================================
            let bracketsItem = popup.children[1];
            assert("POP.BRACKET.01", "Corner brackets container item exists", bracketsItem !== null && bracketsItem !== undefined, "brackets=" + bracketsItem);
            assert("POP.BRACKET.02", "Corner brackets z-index is 10", bracketsItem.z === 10, "z=" + bracketsItem.z);
            assert("POP.BRACKET.03", "Corner brackets bracketColor is Theme.acidGreen", bracketsItem.bracketColor.toString().toLowerCase() === Theme.acidGreen.toString().toLowerCase(), "color=" + bracketsItem.bracketColor);
            assert("POP.BRACKET.04", "Corner brackets has 8 arm rectangles (4 pairs)", bracketsItem.children.length === 8, "count=" + bracketsItem.children.length);

            let armDimsValid = true;
            let armColorsValid = true;
            for (let i = 0; i < bracketsItem.children.length; ++i) {
                let rect = bracketsItem.children[i];
                let isHoriz = (rect.width === Theme.cornerBracketArmLength && rect.height === Theme.cornerBracketThickness);
                let isVert = (rect.width === Theme.cornerBracketThickness && rect.height === Theme.cornerBracketArmLength);
                if (!isHoriz && !isVert) armDimsValid = false;
                if (rect.color.toString().toLowerCase() !== Theme.acidGreen.toString().toLowerCase()) armColorsValid = false;
            }
            assert("POP.BRACKET.05", "All 8 arms match corner bracket arm length & thickness tokens", armDimsValid, "dims=" + armDimsValid);
            assert("POP.BRACKET.06", "All 8 arms use Theme.acidGreen", armColorsValid, "colors=" + armColorsValid);

            // =================================================================
            // 4. Header Row Controls & closeRequested Signal
            // =================================================================
            let mainCol = popup.children[2];
            let headerRow = mainCol.children[0];
            let pwrBtn = headerRow.children[0];
            let titleText = headerRow.children[1];
            let scanBtn = headerRow.children[2];
            let closeBtn = headerRow.children[3];

            assert("POP.HDR.01", "Power toggle button exists in header", pwrBtn !== null && pwrBtn !== undefined, "pwrBtn=" + pwrBtn);
            assert("POP.HDR.02", "Title text is 'BLUETOOTH // RADIO'", titleText.text === "BLUETOOTH // RADIO", "text=" + titleText.text);
            assert("POP.HDR.03", "Title uses Theme.fontFamilyMonospace", titleText.font.family === Theme.fontFamilyMonospace, "font=" + titleText.font.family);
            assert("POP.HDR.04", "Scan button exists in header", scanBtn !== null && scanBtn !== undefined, "scanBtn=" + scanBtn);
            assert("POP.HDR.05", "Close button exists in header", closeBtn !== null && closeBtn !== undefined, "closeBtn=" + closeBtn);

            // Test closeRequested emission
            let closeMouse = closeBtn.children[1];
            assert("POP.CLOSE.01", "Close button MouseArea exists", closeMouse !== null && closeMouse !== undefined, "closeMouse=" + closeMouse);
            assert("POP.CLOSE.02", "closeSignalReceived initially false", testRoot.closeSignalReceived === false, "sig=" + testRoot.closeSignalReceived);

            closeMouse.clicked(null);
            assert("POP.CLOSE.03", "Clicking close button emits closeRequested", testRoot.closeSignalReceived === true && testRoot.closeSignalCount === 1, "received=" + testRoot.closeSignalReceived + ", count=" + testRoot.closeSignalCount);

            // =================================================================
            // 5. Empty State: Radio Powered Off
            // =================================================================
            BluetoothService._clearAllDevices();
            BluetoothService._parseShowOutput("Controller AA:BB:CC:DD:EE:FF Host\n\tPowered: no\n\tPowerState: off\n");
            let body = mainCol.children[2];
            let radioOffState = body.children[0];
            let noDevicesState = body.children[1];
            let deviceFlick = body.children[2];
            let footerRow = mainCol.children[4];
            let footerText = footerRow.children[0];

            assert("POP.OFF.01", "BluetoothService reports powered=false", BluetoothService.powered === false, "powered=" + BluetoothService.powered);
            assert("POP.OFF.02", "Radio Powered Off empty state is visible", radioOffState.visible === true, "visible=" + radioOffState.visible);
            assert("POP.OFF.03", "No Devices empty state is hidden", noDevicesState.visible === false, "visible=" + noDevicesState.visible);
            assert("POP.OFF.04", "Device Flickable is hidden when powered off", deviceFlick.visible === false, "visible=" + deviceFlick.visible);
            assert("POP.OFF.05", "Footer status displays '// STATUS: OFF'", footerText.text === "// STATUS: OFF", "status=" + footerText.text);
            assert("POP.OFF.06", "Power button label displays '[PWR OFF]'", pwrBtn.children[0].text === "[PWR OFF]", "label=" + pwrBtn.children[0].text);

            // =================================================================
            // 6. Empty State: Powered On, No Devices Discovered
            // =================================================================
            BluetoothService._clearAllDevices();
            BluetoothService._parseShowOutput("Controller AA:BB:CC:DD:EE:FF Host\n\tPowered: yes\n\tPowerState: on\n");

            assert("POP.EMPTY.01", "BluetoothService reports powered=true", BluetoothService.powered === true, "powered=" + BluetoothService.powered);
            assert("POP.EMPTY.02", "Radio Powered Off state is hidden", radioOffState.visible === false, "visible=" + radioOffState.visible);
            assert("POP.EMPTY.03", "No Devices empty state is visible", noDevicesState.visible === true, "visible=" + noDevicesState.visible);
            assert("POP.EMPTY.04", "Device Flickable is hidden when device count is 0", deviceFlick.visible === false, "visible=" + deviceFlick.visible);
            assert("POP.EMPTY.05", "No Devices state text prompts click to discover", noDevicesState.children[1].text.indexOf("NO DEVICES FOUND") !== -1, "text=" + noDevicesState.children[1].text);
            assert("POP.EMPTY.06", "Footer status displays '// STATUS: STANDBY'", footerText.text === "// STATUS: STANDBY", "status=" + footerText.text);
            assert("POP.EMPTY.07", "Power button label displays '[PWR ON]'", pwrBtn.children[0].text === "[PWR ON]", "label=" + pwrBtn.children[0].text);

            // =================================================================
            // 7. Scanning State Invariants
            // =================================================================
            BluetoothService._isScanning = true;
            assert("POP.SCAN.01", "Scan button label updates to '[SCANNING]'", scanBtn.children[0].text === "[SCANNING]", "label=" + scanBtn.children[0].text);
            assert("POP.SCAN.02", "No Devices state text updates to '// SCANNING FOR NEARBY DEVICES...'", noDevicesState.children[1].text.indexOf("SCANNING FOR NEARBY DEVICES") !== -1, "text=" + noDevicesState.children[1].text);
            assert("POP.SCAN.03", "Footer status displays '// STATUS: SCANNING...'", footerText.text === "// STATUS: SCANNING...", "status=" + footerText.text);
            BluetoothService._isScanning = false;

            // =================================================================
            // 8. Connected Devices List & Actions
            // =================================================================
            BluetoothService._clearAllDevices();
            BluetoothService._parseConnectedOutput("Device 11:22:33:44:55:66 Cyberdeck Audio\n");
            let devCol = deviceFlick.contentItem.children[0];
            let connSection = devCol.children[0];
            let pairedSection = devCol.children[1];
            let availSection = devCol.children[2];

            assert("POP.CONN.01", "Device Flickable becomes visible when devices present", deviceFlick.visible === true, "visible=" + deviceFlick.visible);
            assert("POP.CONN.02", "No Devices empty state becomes hidden", noDevicesState.visible === false, "visible=" + noDevicesState.visible);
            assert("POP.CONN.03", "Connected section is visible when connected devices > 0", connSection.visible === true, "visible=" + connSection.visible);
            assert("POP.CONN.04", "Connected section title shows count 1", connSection.children[0].children[1].text === "// CONNECTED (1)", "title=" + connSection.children[0].children[1].text);
            assert("POP.CONN.05", "Footer status displays '// STATUS: CONNECTED'", footerText.text === "// STATUS: CONNECTED", "status=" + footerText.text);

            // =================================================================
            // 9. Paired Devices List & Actions
            // =================================================================
            BluetoothService._parsePairedOutput("Device AA:BB:CC:11:22:33 Ergonomic Keeb\n");
            assert("POP.PAIR.01", "Paired section is visible when paired devices > 0", pairedSection.visible === true, "visible=" + pairedSection.visible);
            assert("POP.PAIR.02", "Paired section title shows count 1", pairedSection.children[0].children[1].text === "// PAIRED (1)", "title=" + pairedSection.children[0].children[1].text);

            // =================================================================
            // 10. Available Discovered Devices List & Actions
            // =================================================================
            BluetoothService._parseDevicesOutput("Device 99:88:77:66:55:44 AR Visor\nDevice 99:88:77:66:55:55 Neural Link\n");
            assert("POP.AVAIL.01", "Available section is visible when available devices > 0", availSection.visible === true, "visible=" + availSection.visible);
            assert("POP.AVAIL.02", "Available section title shows count 2", availSection.children[0].children[1].text === "// DISCOVERED (2)", "title=" + availSection.children[0].children[1].text);

            // =================================================================
            // 11. RF Density Stress & Geometry Bounding
            // =================================================================
            let manyDevices = "";
            for (let i = 1; i <= 25; i++) {
                let hex = (i < 16 ? "0" : "") + i.toString(16).toUpperCase();
                manyDevices += "Device E0:00:00:00:00:" + hex + " Peripheral #" + i + "\n";
            }
            BluetoothService._parseDevicesOutput(manyDevices);

            assert("POP.STRESS.01", "Available devices parsed 25 peripherals", BluetoothService.availableDevices.length >= 25, "count=" + BluetoothService.availableDevices.length);
            assert("POP.STRESS.02", "Body container preferred height clamped to max 320px", body.Layout.preferredHeight <= 320, "prefH=" + body.Layout.preferredHeight);
            assert("POP.STRESS.03", "Device flickable clip is enabled", deviceFlick.clip === true, "clip=" + deviceFlick.clip);

            // =================================================================
            // 12. Refresh Button Action
            // =================================================================
            let refreshBtn = footerRow.children[1];
            assert("POP.REFRESH.01", "Refresh button exists in footer", refreshBtn !== null && refreshBtn !== undefined, "refreshBtn=" + refreshBtn);
            assert("POP.REFRESH.02", "Refresh button label is '[REFRESH]'", refreshBtn.children[0].text === "[REFRESH]", "text=" + refreshBtn.children[0].text);

            // =================================================================
            // Summary
            // =================================================================
            console.log("================================================================");
            console.log("M3 BLUETOOTH POPUP RESULTS: Passed=" + passCount + ", Failed=" + failCount);
            if (failCount === 0) {
                console.log("=== PASS: M3 BLUETOOTH POPUP CHALLENGER RUNTIME SUCCESSFUL ===");
            } else {
                console.error("=== FAIL: M3 BLUETOOTH POPUP CHALLENGER RUNTIME FAILED ===");
            }
            console.log("================================================================");

            Qt.quit();
        }
    }
}
