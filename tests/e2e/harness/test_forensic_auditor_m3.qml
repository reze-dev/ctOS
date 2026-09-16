pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import desktop.core
import desktop.services
import desktop.surfaces
import desktop.surfaces.components

Scope {
    id: root

    property int passCount: 0
    property int failCount: 0
    property bool closeSignalReceived: false
    property bool barToggleBluetoothReceived: false

    function record(checkId, desc, cond, details) {
        if (cond) {
            passCount++;
            console.log("[PASS] " + checkId + ": " + desc + (details ? " (" + details + ")" : ""));
        } else {
            failCount++;
            console.error("[FAIL] " + checkId + ": " + desc + (details ? " (" + details + ")" : ""));
        }
    }

    BluetoothPopup {
        id: testPopup

        onCloseRequested: {
            root.closeSignalReceived = true;
        }
    }

    AmbientBar {
        id: testBar

        screen: Quickshell.screens[0] || null

        onToggleBluetooth: {
            root.barToggleBluetoothReceived = true;
        }
    }

    Timer {
        interval: 150
        running: true
        repeat: false

        onTriggered: {
            console.log("================================================================");
            console.log("=== FORENSIC RUNTIME VERIFICATION: BLUETOOTH POPUP (M3) ===");
            console.log("================================================================");

            // 1. Instantiation and Geometry
            record("M3.POP.01", "BluetoothPopup instantiates cleanly", testPopup !== null, "popup=" + testPopup);
            record("M3.POP.02", "BluetoothPopup width is 320", testPopup.width === 320, "width=" + testPopup.width);
            record("M3.POP.03", "BluetoothPopup implicitWidth is 320", testPopup.implicitWidth === 320, "implicitWidth=" + testPopup.implicitWidth);
            record("M3.POP.04", "BluetoothPopup color is Theme.gray900", testPopup.color == Theme.gray900, "color=" + testPopup.color);
            record("M3.POP.05", "BluetoothPopup border.color is Theme.borderMuted", testPopup.border.color == Theme.borderMuted, "border=" + testPopup.border.color);
            record("M3.POP.06", "BluetoothPopup radius is Theme.radiusSmall", testPopup.radius === Theme.radiusSmall, "radius=" + testPopup.radius);

            // 2. Corner Brackets & Shield
            let shield = testPopup.children[0];
            record("M3.POP.07", "Click shield MouseArea has preventStealing enabled", shield.preventStealing === true, "preventStealing=" + shield.preventStealing);

            let brackets = testPopup.children[1];
            record("M3.POP.08", "Corner brackets z-index is 10", brackets.z === 10, "z=" + brackets.z);
            record("M3.POP.09", "Corner brackets item contains 8 arm rectangles", brackets.children.length === 8, "count=" + brackets.children.length);

            // 3. Layout and Header
            let mainCol = testPopup.children[2];
            record("M3.POP.10", "Main ColumnLayout exists", mainCol !== null, "mainCol=" + mainCol);

            let headerRow = mainCol.children[0];
            record("M3.POP.11", "Header RowLayout exists", headerRow !== null, "headerRow=" + headerRow);

            let pwrBtn = headerRow.children[0];
            let pwrMouse = pwrBtn.children[1];
            record("M3.POP.12", "Power button MouseArea exists", pwrMouse !== null && pwrMouse !== undefined, "pwrMouse=" + pwrMouse);

            let scanBtn = headerRow.children[2];
            let scanMouse = scanBtn.children[1];
            record("M3.POP.13", "Scan button MouseArea exists", scanMouse !== null && scanMouse !== undefined, "scanMouse=" + scanMouse);

            let closeBtn = headerRow.children[3];
            let closeMouse = closeBtn.children[1];
            record("M3.POP.14", "Close button MouseArea exists", closeMouse !== null && closeMouse !== undefined, "closeMouse=" + closeMouse);

            // 4. Signal and Method Invocations
            root.closeSignalReceived = false;
            closeMouse.clicked(null);
            record("M3.POP.15", "Close button click emits closeRequested signal", root.closeSignalReceived === true, "received=" + root.closeSignalReceived);

            // 5. AmbientBar Wiring
            record("M3.BAR.01", "AmbientBar instantiates cleanly", testBar !== null, "testBar=" + testBar);
            let rightSecs = testBar.contentItem.children[2];
            let btSec = rightSecs.children[3];
            let btMouseArea = btSec.children[1];
            record("M3.BAR.02", "AmbientBar bluetoothMouseArea exists", btMouseArea !== null, "btMouseArea=" + btMouseArea);
            record("M3.BAR.03", "AmbientBar bluetoothMouseArea accepts Left and Right buttons",
                (btMouseArea.acceptedButtons & Qt.LeftButton) !== 0 && (btMouseArea.acceptedButtons & Qt.RightButton) !== 0,
                "acceptedButtons=" + btMouseArea.acceptedButtons);

            root.barToggleBluetoothReceived = false;
            // Left click triggers root.toggleBluetooth()
            btSec.children[1].clicked({ button: Qt.LeftButton, accepted: false });
            record("M3.BAR.04", "Left click on AmbientBar bluetooth section emits toggleBluetooth",
                root.barToggleBluetoothReceived === true, "emitted=" + root.barToggleBluetoothReceived);

            console.log("================================================================");
            console.log("FORENSIC RESULTS: Passed=" + root.passCount + ", Failed=" + root.failCount);
            if (root.failCount === 0) {
                console.log("=== PASS: M3 FORENSIC RUNTIME HARNESS SUCCESSFUL ===");
            } else {
                console.error("=== FAIL: M3 FORENSIC RUNTIME HARNESS FAILED ===");
            }
            console.log("================================================================");

            Qt.quit();
        }
    }
}
