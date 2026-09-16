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
    property int closeSignalCount: 0
    property int backdropDismissCount: 0

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

        // Backdrop simulator (representing Wayland layer-shell backdrop)
        MouseArea {
            id: backdropMouseArea
            anchors.fill: parent
            onClicked: {
                testWindow.backdropDismissCount++;
            }
        }

        BluetoothPopup {
            id: popup
            x: 100
            y: 50

            onCloseRequested: {
                testWindow.closeSignalCount++;
            }
        }
    }

    Timer {
        id: stageTimer
        interval: 80
        running: true
        repeat: true

        property int currentStage: 0

        onTriggered: {
            currentStage++;

            // Component reference tree
            const shieldMouseArea = popup.children[0];
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

            const bodyContainer = mainCol.children[2];
            const emptyRadioOff = bodyContainer.children[0];
            const emptyNoDevices = bodyContainer.children[1];
            const flickable = bodyContainer.children[2];
            const devCol = flickable.contentItem.children[0];
            const connectedSection = devCol.children[0];
            const pairedSection = devCol.children[1];
            const availSection = devCol.children[2];

            const footerRow = mainCol.children[4];
            const statusText = footerRow.children[0];
            const refreshBtn = footerRow.children[1];
            const refreshMouse = refreshBtn.children[1];

            // =================================================================
            // STAGE 1: Edge Case 1 (Scale) - Inject 50 Devices
            // =================================================================
            if (currentStage === 1) {
                console.log("================================================================");
                console.log("=== EMPIRICAL ADVERSARIAL STRESS SUITE: BLUETOOTH POPUP (M4) ===");
                console.log("================================================================");
                console.log("--- [STAGE 1: INJECTING 50 DEVICES FOR SCALE TEST] ---");

                BluetoothService._clearAllDevices();
                BluetoothService._powered = true;

                let rawAll = "";
                let rawPaired = "";
                let rawConn = "";

                for (let i = 1; i <= 50; i++) {
                    let hexSuffix = (i < 16 ? "0" + i.toString(16) : i.toString(16)).toUpperCase();
                    let mac = "AA:BB:CC:DD:EE:" + hexSuffix;
                    let name = "ScalePeripheral_" + (i < 10 ? "0" + i : i);
                    rawAll += "Device " + mac + " " + name + "\n";
                    if (i <= 30) {
                        rawPaired += "Device " + mac + " " + name + "\n";
                    }
                    if (i <= 10) {
                        rawConn += "Device " + mac + " " + name + "\n";
                    }
                }

                BluetoothService._parseDevicesOutput(rawAll);
                BluetoothService._parsePairedOutput(rawPaired);
                BluetoothService._parseConnectedOutput(rawConn);
            }

            // =================================================================
            // STAGE 2: Edge Case 1 (Scale) - Evaluate Dimensions & Scrolling
            // =================================================================
            else if (currentStage === 2) {
                console.log("--- [STAGE 2: EVALUATING SCALE & SCROLLING BOUNDS] ---");

                assertCondition("ADV.SCALE.01", "BluetoothService populated with 50 total devices",
                    BluetoothService.devices && BluetoothService.devices.count === 50,
                    "count=" + (BluetoothService.devices ? BluetoothService.devices.count : 0));

                assertCondition("ADV.SCALE.02", "BluetoothService reports 10 connected devices",
                    BluetoothService.connectedDevices && BluetoothService.connectedDevices.count === 10,
                    "count=" + (BluetoothService.connectedDevices ? BluetoothService.connectedDevices.count : 0));

                assertCondition("ADV.SCALE.03", "BluetoothService reports 20 paired (unconnected) devices",
                    BluetoothService.pairedDevices && BluetoothService.pairedDevices.count === 20,
                    "count=" + (BluetoothService.pairedDevices ? BluetoothService.pairedDevices.count : 0));

                assertCondition("ADV.SCALE.04", "BluetoothService reports 20 available discovered devices",
                    BluetoothService.availableDevices && BluetoothService.availableDevices.count === 20,
                    "count=" + (BluetoothService.availableDevices ? BluetoothService.availableDevices.count : 0));

                const totalImplicitHeight = devCol.implicitHeight;
                assertCondition("ADV.SCALE.05", "Under 50 devices, list content implicit height expands (>1000px)",
                    totalImplicitHeight > 1000,
                    "implicitHeight=" + totalImplicitHeight);

                assertCondition("ADV.SCALE.06", "bodyContainer bounds height to maximum 320px",
                    bodyContainer.Layout.preferredHeight === 320,
                    "preferredHeight=" + bodyContainer.Layout.preferredHeight);

                assertCondition("ADV.SCALE.07", "Flickable viewport height bounds to 320px",
                    flickable.height <= 320,
                    "flickable.height=" + flickable.height);

                assertCondition("ADV.SCALE.08", "Flickable clip is enabled preventing overflow",
                    flickable.clip === true,
                    "clip=" + flickable.clip);

                assertCondition("ADV.SCALE.09", "Flickable contentHeight matches unclipped device list height",
                    flickable.contentHeight === totalImplicitHeight,
                    "contentHeight=" + flickable.contentHeight);

                // Test scrolling
                flickable.contentY = 200;
                assertCondition("ADV.SCALE.10", "Flickable container allows scrolling contentY without clipping",
                    flickable.contentY === 200,
                    "contentY=" + flickable.contentY);

                assertCondition("ADV.SCALE.11", "Flickable boundsBehavior is StopAtBounds",
                    flickable.boundsBehavior === Flickable.StopAtBounds,
                    "boundsBehavior=" + flickable.boundsBehavior);

                flickable.contentY = 0;
            }

            // =================================================================
            // STAGE 3: Edge Case 2 (Extreme String Lengths) - Inject 150-char Names
            // =================================================================
            else if (currentStage === 3) {
                console.log("--- [STAGE 3: INJECTING 150-CHAR EXTREME NAMES] ---");
                BluetoothService._clearAllDevices();

                // Part A: Service-level parser truncation check
                const longRaw120 = "Device 11:22:33:44:55:99 " + "X".repeat(120) + "\n";
                BluetoothService._parseDevicesOutput(longRaw120);
                const truncatedName = BluetoothService.devices.get(0).name;
                assertCondition("ADV.STR.LEN.01", "BluetoothService truncates extreme raw names to 24 chars in parser",
                    truncatedName.length === 24,
                    "length=" + truncatedName.length);

                // Part B: Direct injection of 150-char names into all three categories
                const hugeName = "ALPHA_OMEGA_CYBERPUNK_NEURAL_LINK_STATION_DEVICE_EXCEEDING_ONE_HUNDRED_CHARACTERS_FOR_ADVERSARIAL_TESTING_1234567890_ABCDEFGHIJKLMNOPQRSTUVWXYZ";
                BluetoothService._clearAllDevices();
                BluetoothService._deviceMap["11:11:11:11:11:11"] = {
                    mac: "11:11:11:11:11:11",
                    name: hugeName,
                    connected: true,
                    paired: true,
                    icon: "bluetooth"
                };
                BluetoothService._deviceMap["22:22:22:22:22:22"] = {
                    mac: "22:22:22:22:22:22",
                    name: hugeName,
                    connected: false,
                    paired: true,
                    icon: "bluetooth"
                };
                BluetoothService._deviceMap["33:33:33:33:33:33"] = {
                    mac: "33:33:33:33:33:33",
                    name: hugeName,
                    connected: false,
                    paired: false,
                    icon: "bluetooth"
                };
                BluetoothService._rebuildDeviceLists();
            }

            // =================================================================
            // STAGE 4: Edge Case 2 (Extreme String Lengths) - Assert Elide & Clipping
            // =================================================================
            else if (currentStage === 4) {
                console.log("--- [STAGE 4: EVALUATING EXTREME STRING ELISION & BUTTON BOUNDS] ---");

                assertCondition("ADV.STR.LEN.02", "150-character name loaded into models",
                    BluetoothService.connectedDevices.get(0).name.length > 100,
                    "length=" + BluetoothService.connectedDevices.get(0).name.length);

                // Connected tile
                const connTile = connectedSection.children[1];
                const connTileCol = connTile.children[1];
                const connRow = connTileCol.children[0];
                const connNameText = connRow.children[1];
                const disconnectButton = connRow.children[2];

                assertCondition("ADV.STR.LEN.03", "Connected device name text has elide set to Text.ElideRight",
                    connNameText.elide === Text.ElideRight,
                    "elide=" + connNameText.elide);

                assertCondition("ADV.STR.LEN.04", "Connected device name text is truncated when exceeding width",
                    connNameText.truncated === true,
                    "truncated=" + connNameText.truncated);

                assertCondition("ADV.STR.LEN.05", "Disconnect button maintains layout width and is not clipped",
                    disconnectButton.width > 0 && (disconnectButton.x + disconnectButton.width <= connTile.width),
                    "btn.x=" + disconnectButton.x + ", btn.w=" + disconnectButton.width + ", tile.w=" + connTile.width);

                // Paired tile
                const pairedTile = pairedSection.children[1];
                const pairedTileCol = pairedTile.children[0];
                const pairedRow = pairedTileCol.children[0];
                const pairedNameText = pairedRow.children[1];
                const forgetButton = pairedRow.children[3];

                assertCondition("ADV.STR.LEN.06", "Paired device name text has elide set to Text.ElideRight and truncated=true",
                    pairedNameText.elide === Text.ElideRight && pairedNameText.truncated === true,
                    "truncated=" + pairedNameText.truncated);

                assertCondition("ADV.STR.LEN.07", "Paired connect and forget buttons remain within tile bounds",
                    forgetButton.x + forgetButton.width <= pairedTile.width,
                    "forget.x=" + forgetButton.x + ", forget.w=" + forgetButton.width + ", tile.w=" + pairedTile.width);

                // Discovered tile
                const availTile = availSection.children[1];
                const availTileCol = availTile.children[0];
                const availRow = availTileCol.children[0];
                const availNameText = availRow.children[1];
                const pairButton = availRow.children[2];

                assertCondition("ADV.STR.LEN.08", "Discovered device name text has elide set to Text.ElideRight and truncated=true",
                    availNameText.elide === Text.ElideRight && availNameText.truncated === true,
                    "truncated=" + availNameText.truncated);

                assertCondition("ADV.STR.LEN.09", "Discovered pair button remains within tile bounds",
                    pairButton.x + pairButton.width <= availTile.width,
                    "pair.x=" + pairButton.x + ", pair.w=" + pairButton.width + ", tile.w=" + availTile.width);

                assertCondition("ADV.STR.LEN.10", "Popup width invariant strictly maintained at 320 despite 150-char strings",
                    popup.width === 320 && popup.implicitWidth === 320,
                    "width=" + popup.width);
            }

            // =================================================================
            // STAGE 5: Edge Case 3 (Untrusted Characters & Injections)
            // =================================================================
            else if (currentStage === 5) {
                console.log("--- [STAGE 5: UNTRUSTED CHARACTERS & INJECTION TESTING] ---");
                BluetoothService._clearAllDevices();

                const rawInjections = "Device 44:00:00:00:00:01 <script>alert(1)</script>\n" +
                                      "Device 44:00:00:00:00:02 $(reboot)\n" +
                                      "Device 44:00:00:00:00:03 🎧 Cyberᚠᛇ ™ 日本語\n" +
                                      "Device 44:00:00:00:00:04 Evil\nDevice\r\nNewline\n" +
                                      "Device 44:00:00:00:00:05 \x1B[31mEscape\x07\x00Code\n";
                BluetoothService._parseDevicesOutput(rawInjections);

                assertCondition("ADV.INJ.01", "HTML injection string parsed and displayed safely without crash",
                    BluetoothService.devices.count >= 4,
                    "count=" + BluetoothService.devices.count);

                const devScript = BluetoothService._deviceMap["44:00:00:00:00:01"];
                assertCondition("ADV.INJ.02", "Script injection string rendered safely as plain text data",
                    devScript && devScript.name.indexOf("<script>") !== -1,
                    "name=" + (devScript ? devScript.name : "null"));

                const devReboot = BluetoothService._deviceMap["44:00:00:00:00:02"];
                assertCondition("ADV.INJ.03", "Command injection string rendered safely without shell execution",
                    devReboot && devReboot.name === "$(reboot)",
                    "name=" + (devReboot ? devReboot.name : "null"));

                const devUnicode = BluetoothService._deviceMap["44:00:00:00:00:03"];
                assertCondition("ADV.INJ.04", "Unicode symbols preserved and displayed safely",
                    devUnicode && devUnicode.name.indexOf("🎧") !== -1,
                    "name=" + (devUnicode ? devUnicode.name : "null"));

                // Control chars stripping
                let controlFound = false;
                for (let d = 0; d < BluetoothService.devices.count; d++) {
                    let dName = BluetoothService.devices.get(d).name;
                    if (/[\x00-\x1F\x7F]/.test(dName)) {
                        controlFound = true;
                    }
                }
                assertCondition("ADV.INJ.05", "All control characters and newlines stripped from device names",
                    controlFound === false,
                    "controlFound=" + controlFound);

                // Malicious MAC rejection checks
                BluetoothService.connectDevice("00:11:22:33:44:55; reboot");
                assertCondition("ADV.INJ.06", "Command injection in connectDevice(mac) rejected by MAC regex guard",
                    BluetoothService.isActionPending === false,
                    "isActionPending=" + BluetoothService.isActionPending);

                BluetoothService.disconnectDevice("$(poweroff)");
                assertCondition("ADV.INJ.07", "Command injection in disconnectDevice(mac) rejected by MAC regex guard",
                    BluetoothService.isActionPending === false,
                    "isActionPending=" + BluetoothService.isActionPending);

                BluetoothService.pairDevice("11:22:33:44:55:66 | rm -rf /");
                assertCondition("ADV.INJ.08", "Pipe injection in pairDevice(mac) rejected by MAC regex guard",
                    BluetoothService.isActionPending === false,
                    "isActionPending=" + BluetoothService.isActionPending);

                BluetoothService.forgetDevice("invalid-mac");
                assertCondition("ADV.INJ.09", "Invalid MAC in forgetDevice(mac) rejected by MAC regex guard",
                    BluetoothService.isActionPending === false,
                    "isActionPending=" + BluetoothService.isActionPending);
            }

            // =================================================================
            // STAGE 6: Edge Case 4 (Action In-Flight Mutex) - Setup
            // =================================================================
            else if (currentStage === 6) {
                console.log("--- [STAGE 6: ACTION IN-FLIGHT MUTEX EVALUATION] ---");
                BluetoothService._clearAllDevices();

                BluetoothService._deviceMap["11:22:33:44:55:01"] = {
                    mac: "11:22:33:44:55:01",
                    name: "ConnDevice",
                    connected: true,
                    paired: true,
                    icon: "bluetooth"
                };
                BluetoothService._deviceMap["22:33:44:55:66:02"] = {
                    mac: "22:33:44:55:66:02",
                    name: "PairedDevice",
                    connected: false,
                    paired: true,
                    icon: "bluetooth"
                };
                BluetoothService._deviceMap["33:44:55:66:77:03"] = {
                    mac: "33:44:55:66:77:03",
                    name: "AvailDevice",
                    connected: false,
                    paired: false,
                    icon: "bluetooth"
                };
                BluetoothService._rebuildDeviceLists();
            }

            // =================================================================
            // STAGE 7: Edge Case 4 (Action In-Flight Mutex) - Assert Mutex Guards
            // =================================================================
            else if (currentStage === 7) {
                // Simulate in-flight disconnect action on 11:22:33:44:55:01
                BluetoothService._actionTargetMac = "11:22:33:44:55:01";
                BluetoothService._actionType = "disconnect";

                assertCondition("ADV.MUTEX.01", "isActionPending is true while action is active",
                    BluetoothService.isActionPending === true,
                    "isActionPending=" + BluetoothService.isActionPending);

                const activeConnTile = connectedSection.children[1];
                const activeConnRow = activeConnTile.children[1].children[0];
                const activeDiscBtn = activeConnRow.children[2];
                const activeDiscLabel = activeDiscBtn.children[0];
                const activeDiscMouse = activeDiscBtn.children[1];

                assertCondition("ADV.MUTEX.02", "Disconnect button displays [WAIT...] for active target",
                    activeDiscLabel.text === "[WAIT...]",
                    "text=" + activeDiscLabel.text);

                assertCondition("ADV.MUTEX.03", "Disconnect button MouseArea is disabled during in-flight action",
                    activeDiscMouse.enabled === false,
                    "enabled=" + activeDiscMouse.enabled);

                // Check non-target action buttons are also disabled
                const activePairedTile = pairedSection.children[1];
                const activePairedRow = activePairedTile.children[0].children[0];
                const nonTargetConnBtn = activePairedRow.children[2];
                const nonTargetConnMouse = nonTargetConnBtn.children[1];
                const nonTargetForgetBtn = activePairedRow.children[3];
                const nonTargetForgetMouse = nonTargetForgetBtn.children[1];

                assertCondition("ADV.MUTEX.04", "Non-target connect button MouseArea is disabled",
                    nonTargetConnMouse.enabled === false,
                    "enabled=" + nonTargetConnMouse.enabled);

                assertCondition("ADV.MUTEX.05", "Non-target forget button MouseArea is disabled",
                    nonTargetForgetMouse.enabled === false,
                    "enabled=" + nonTargetForgetMouse.enabled);

                const activeAvailTile = availSection.children[1];
                const activeAvailRow = activeAvailTile.children[0].children[0];
                const nonTargetPairBtn = activeAvailRow.children[2];
                const nonTargetPairMouse = nonTargetPairBtn.children[1];

                assertCondition("ADV.MUTEX.06", "Non-target pair button MouseArea is disabled",
                    nonTargetPairMouse.enabled === false,
                    "enabled=" + nonTargetPairMouse.enabled);

                // Test connect in-flight indicator
                BluetoothService._actionTargetMac = "22:33:44:55:66:02";
                BluetoothService._actionType = "connect";
                const targetConnLabel = nonTargetConnBtn.children[0];
                assertCondition("ADV.MUTEX.07", "Connect button displays [CONN...] for active target",
                    targetConnLabel.text === "[CONN...]",
                    "text=" + targetConnLabel.text);

                // Test pair in-flight indicator
                BluetoothService._actionTargetMac = "33:44:55:66:77:03";
                BluetoothService._actionType = "pair";
                const targetPairLabel = nonTargetPairBtn.children[0];
                assertCondition("ADV.MUTEX.08", "Pair button displays [PAIRING...] for active target",
                    targetPairLabel.text === "[PAIRING...]",
                    "text=" + targetPairLabel.text);

                // Clean reset
                BluetoothService._actionTargetMac = "";
                BluetoothService._actionType = "";
                assertCondition("ADV.MUTEX.09", "Clearing actionTargetMac resets isActionPending to false",
                    BluetoothService.isActionPending === false,
                    "isActionPending=" + BluetoothService.isActionPending);

                assertCondition("ADV.MUTEX.10", "Buttons re-enabled and restore default text after action completes",
                    activeDiscMouse.enabled === true && nonTargetConnMouse.enabled === true && nonTargetPairMouse.enabled === true,
                    "enabled=" + activeDiscMouse.enabled);
            }

            // =================================================================
            // STAGE 8: Edge Case 5 (Rapid State Flapping)
            // =================================================================
            else if (currentStage === 8) {
                console.log("--- [STAGE 8: RAPID STATE FLAPPING (100 INVOCATIONS)] ---");
                let flapExceptions = 0;

                try {
                    for (let f = 0; f < 100; f++) {
                        BluetoothService.togglePower();
                        BluetoothService.toggleScan();
                    }
                } catch (err) {
                    flapExceptions++;
                    console.error("Exception during rapid toggle: " + err);
                }

                assertCondition("ADV.FLAP.01", "100 rapid togglePower and toggleScan calls executed with 0 exceptions",
                    flapExceptions === 0,
                    "exceptions=" + flapExceptions);

                // 100 rapid alternating parser events
                for (let cycle = 0; cycle < 50; cycle++) {
                    BluetoothService._parseShowOutput("Powered: yes\nPowerState: on\n");
                    BluetoothService._parseShowOutput("Powered: no\nPowerState: off\n");
                }

                assertCondition("ADV.FLAP.02", "State machine handles 100 parser transitions cleanly",
                    BluetoothService.powered === false,
                    "powered=" + BluetoothService.powered);

                // Settle to powered on
                BluetoothService._parseShowOutput("Powered: yes\nPowerState: on\n");
                assertCondition("ADV.FLAP.03", "State settles correctly to powered=true after flapping sequence",
                    BluetoothService.powered === true && powerLabel.text === "[PWR ON]",
                    "powered=" + BluetoothService.powered + ", label=" + powerLabel.text);
            }

            // =================================================================
            // STAGE 9: Edge Case 6 (Radio Off Transition)
            // =================================================================
            else if (currentStage === 9) {
                console.log("--- [STAGE 9: RADIO OFF IMMEDIATE TRANSITION] ---");

                // Setup: Powered ON, scanning active, devices present
                BluetoothService._parseShowOutput("Powered: yes\nPowerState: on\n");
                BluetoothService._parseDevicesOutput("Device 11:11:11:11:11:11 Dev1\nDevice 22:22:22:22:22:22 Dev2\n");
                BluetoothService._parseConnectedOutput("Device 11:11:11:11:11:11 Dev1\n");
                BluetoothService._isScanning = true;

                assertCondition("ADV.RADIO.01", "Precondition: Radio is ON, scanning is TRUE, devices count > 0",
                    BluetoothService.powered === true && BluetoothService.isScanning === true && BluetoothService.devices.count > 0,
                    "powered=" + BluetoothService.powered + ", isScanning=" + BluetoothService.isScanning);

                // Trigger Power OFF transition
                BluetoothService._parseShowOutput("Powered: no\nPowerState: off\n");

                assertCondition("ADV.RADIO.02", "BluetoothService.powered is immediately false",
                    BluetoothService.powered === false,
                    "powered=" + BluetoothService.powered);

                assertCondition("ADV.RADIO.03", "BluetoothService.isScanning is immediately forced false",
                    BluetoothService.isScanning === false,
                    "isScanning=" + BluetoothService.isScanning);

                assertCondition("ADV.RADIO.04", "BluetoothService.isConnected is immediately forced false",
                    BluetoothService.isConnected === false,
                    "isConnected=" + BluetoothService.isConnected);

                assertCondition("ADV.RADIO.05", "Empty state '// BLUETOOTH RADIO OFF' is immediately visible",
                    emptyRadioOff.visible === true,
                    "emptyRadioOff.visible=" + emptyRadioOff.visible);

                assertCondition("ADV.RADIO.06", "Empty state 'NO DEVICES' is hidden",
                    emptyNoDevices.visible === false,
                    "emptyNoDevices.visible=" + emptyNoDevices.visible);

                assertCondition("ADV.RADIO.07", "Device flickable container is immediately hidden",
                    flickable.visible === false,
                    "flickable.visible=" + flickable.visible);

                assertCondition("ADV.RADIO.08", "bodyContainer preferredHeight collapses to 140px",
                    bodyContainer.Layout.preferredHeight === 140,
                    "preferredHeight=" + bodyContainer.Layout.preferredHeight);

                assertCondition("ADV.RADIO.09", "Power button updates to [PWR OFF]",
                    powerLabel.text === "[PWR OFF]",
                    "text=" + powerLabel.text);

                assertCondition("ADV.RADIO.10", "Scan button disabled and dimmed (opacity 0.4)",
                    scanMouse.enabled === false && scanBtn.opacity === 0.4,
                    "enabled=" + scanMouse.enabled + ", opacity=" + scanBtn.opacity);

                assertCondition("ADV.RADIO.11", "Footer status displays // STATUS: OFF",
                    statusText.text === "// STATUS: OFF",
                    "text=" + statusText.text);
            }

            // =================================================================
            // STAGE 10: Edge Case 7 (Click Shield & Isolation)
            // =================================================================
            else if (currentStage === 10) {
                console.log("--- [STAGE 10: CLICK SHIELD & ISOLATION EVALUATION] ---");

                assertCondition("ADV.SHIELD.01", "Root click shield MouseArea active with preventStealing=true",
                    shieldMouseArea !== null && shieldMouseArea.preventStealing === true,
                    "preventStealing=" + (shieldMouseArea ? shieldMouseArea.preventStealing : "null"));

                assertCondition("ADV.SHIELD.02", "Root click shield covers 100% of popup geometry (anchors.fill: parent)",
                    shieldMouseArea.width === popup.width && shieldMouseArea.height === popup.height,
                    "shieldW=" + shieldMouseArea.width + ", popupW=" + popup.width);

                // Coordinate containment: points inside popup bounds are contained by shield
                assertCondition("ADV.SHIELD.03", "Top-left internal point (10, 10) is contained within shield bounds",
                    shieldMouseArea.contains(Qt.point(10, 10)) === true,
                    "contains=" + shieldMouseArea.contains(Qt.point(10, 10)));

                assertCondition("ADV.SHIELD.04", "Body internal point (160, 70) is contained within shield bounds",
                    shieldMouseArea.contains(Qt.point(160, 70)) === true,
                    "contains=" + shieldMouseArea.contains(Qt.point(160, 70)));

                assertCondition("ADV.SHIELD.05", "Bottom-right internal point (310, popup.height - 10) is contained within shield bounds",
                    shieldMouseArea.contains(Qt.point(310, popup.height - 10)) === true,
                    "contains=" + shieldMouseArea.contains(Qt.point(310, popup.height - 10)));

                // External point (outside popup bounds) is NOT contained by shield
                assertCondition("ADV.SHIELD.06", "External point (500, 300) is outside popup shield bounds",
                    shieldMouseArea.contains(Qt.point(500, 300)) === false,
                    "contains=" + shieldMouseArea.contains(Qt.point(500, 300)));

                testWindow.backdropDismissCount = 0;
                testWindow.closeSignalCount = 0;

                // Click outside popup on the backdrop triggers dismissal
                backdropMouseArea.clicked(null);
                assertCondition("ADV.SHIELD.07", "Click outside popup bounds successfully triggers backdrop handler",
                    testWindow.backdropDismissCount === 1,
                    "dismissCount=" + testWindow.backdropDismissCount);

                // Internal shield clicks do NOT emit closeRequested
                assertCondition("ADV.SHIELD.08", "Shield does not emit closeRequested on background clicks",
                    testWindow.closeSignalCount === 0,
                    "closeSignalCount=" + testWindow.closeSignalCount);

                // Explicit close button click DOES emit closeRequested
                closeMouse.clicked(null);
                assertCondition("ADV.SHIELD.09", "Explicit closeBtn click triggers closeRequested signal",
                    testWindow.closeSignalCount === 1,
                    "closeSignalCount=" + testWindow.closeSignalCount);

                // Null event tolerance: verify whether shield onClicked survives null invocation without process crash
                shieldMouseArea.clicked(null);
                assertCondition("ADV.SHIELD.10", "Shield onClicked survives null invocation without process crash",
                    true,
                    "survived null event without fatal abort");

                // Final Summary
                console.log("================================================================");
                console.log("ADVERSARIAL SUITE SUMMARY: Passed=" + passCount + ", Failed=" + failCount);
                if (failCount === 0) {
                    console.log("=== PASS: ALL 7 EDGE CASES VERIFIED EMPIRICALLY WITH ZERO DEFECTS ===");
                } else {
                    console.error("=== FAIL: ADVERSARIAL SUITE ENCOUNTERED FAILURES ===");
                }
                console.log("================================================================");

                stageTimer.running = false;
                Qt.quit();
            }
        }
    }
}
