import QtQuick
import Quickshell
import desktop.core
import desktop.services
import desktop.surfaces.radial

Scope {
    id: root

    property int passCount: 0
    property int failCount: 0

    Item {
        id: testContainer
        width: 1920
        height: 1080

        Loader {
            id: radialLoader
            anchors.fill: parent
            active: true
            asynchronous: false
            source: "file://" + (Quickshell.env("PROJECT_ROOT") || "/home/reze/Projects/ctOS") + "/shell/desktop/surfaces/radial/RadialSettings.qml"
        }
    }

    Timer {
        id: inflightTimer
        interval: 10
        repeat: true
        running: true
        property int step: 0
        property double stepStart: 0.0

        onTriggered: {
            var radial = radialLoader.item;
            if (!radial) return;
            var wheel = radial.wheelMenu;

            switch (step) {
            case 0:
                console.log("=== IN-FLIGHT TEST START ===");
                console.log("Initial rotation: " + wheel.wheelRotation);
                // Expand Cat 0 (target 90)
                radial.focusedCategoryIndex = 0;
                radial.isExpanded = true;
                stepStart = Date.now();
                step = 1;
                break;

            case 1:
                // At 50ms (wheel is around ~30-40 deg, in flight), switch to Cat 3 (target -30)
                if (Date.now() - stepStart >= 50) {
                    console.log("Mid-flight switch to Cat 3 at rot=" + wheel.wheelRotation);
                    radial.focusedCategoryIndex = 3;
                    stepStart = Date.now();
                    step = 2;
                }
                break;

            case 2:
                // At 60ms (wheel is moving towards target, in flight), switch to Cat 5 (target -110)
                if (Date.now() - stepStart >= 60) {
                    console.log("Mid-flight switch to Cat 5 at rot=" + wheel.wheelRotation);
                    radial.focusedCategoryIndex = 5;
                    stepStart = Date.now();
                    step = 3;
                }
                break;

            case 3:
                // Wait for wheel to settle at Cat 5 (1000ms)
                if (Date.now() - stepStart >= 1000) {
                    console.log("Settled at Cat 5: rotation=" + wheel.wheelRotation + " (target was -110.0)");
                    var modRot = ((wheel.wheelRotation % 360) + 360) % 360;
                    var expectedMod = ((-110.0 % 360) + 360) % 360; // 250
                    var diff = Math.abs(modRot - expectedMod);
                    if (diff > 180) diff = 360 - diff;
                    console.log("Angular difference from expected: " + diff + " deg");
                    if (diff < 0.01) {
                        console.log("[PASS] Rotation matches exact angle without fractional drift");
                    } else {
                        console.error("[FAIL] ROTATIONAL DRIFT OCCURRED: diff=" + diff + " deg, actual=" + wheel.wheelRotation);
                    }

                    // Now collapse
                    stepStart = Date.now();
                    radial.isExpanded = false;
                    step = 4;
                }
                break;

            case 4:
                // Wait for collapse to finish (1000ms)
                if (Date.now() - stepStart >= 1000) {
                    console.log("Final collapsed rotation: " + wheel.wheelRotation);
                    if (wheel.wheelRotation === 0.0) {
                        console.log("[PASS] Collapsed cleanly to 0.0");
                    } else {
                        console.error("[FAIL] Did NOT return cleanly to 0.0! actual=" + wheel.wheelRotation);
                    }
                    inflightTimer.running = false;
                    Qt.quit();
                }
                break;
            }
        }
    }
}
