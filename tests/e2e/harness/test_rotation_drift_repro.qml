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
        id: reproTimer
        interval: 50
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
                // Pre-flight
                console.log("=== STEP 0: Initial state ===");
                console.log("wheelRotation: " + wheel.wheelRotation);
                step = 1;
                stepStart = Date.now();
                // Expand category 0 (SYSTEM, target: 90)
                radial.focusedCategoryIndex = 0;
                radial.isExpanded = true;
                break;

            case 1:
                // Wait for expand to finish (600ms)
                if (Date.now() - stepStart > 600) {
                    console.log("=== STEP 1: Expanded at Cat 0 ===");
                    console.log("wheelRotation: " + wheel.wheelRotation + " (expected: 90)");
                    // Collapse
                    step = 2;
                    stepStart = Date.now();
                    radial.isExpanded = false;
                }
                break;

            case 2:
                // Wait for collapse to finish (600ms)
                if (Date.now() - stepStart > 600) {
                    console.log("=== STEP 2: Collapsed after Cat 0 ===");
                    console.log("wheelRotation: " + wheel.wheelRotation + " (expected exactly: 0.0)");
                    if (wheel.wheelRotation === 0.0) {
                        console.log("[PASS] Cat 0 collapse returned to 0.0");
                    } else {
                        console.error("[FAIL] Cat 0 collapse DID NOT return cleanly to 0.0! actual=" + wheel.wheelRotation);
                    }

                    // Now reproduce multi-revolution / drift:
                    // Expand Cat 6 (-150°), then switch to Cat 7 (170°), then Cat 8 (130°), then Cat 0 (90°)
                    step = 3;
                    stepStart = Date.now();
                    radial.focusedCategoryIndex = 6;
                    radial.isExpanded = true;
                }
                break;

            case 3:
                if (Date.now() - stepStart > 400) {
                    radial.focusedCategoryIndex = 7;
                    step = 4;
                    stepStart = Date.now();
                }
                break;

            case 4:
                if (Date.now() - stepStart > 400) {
                    radial.focusedCategoryIndex = 8;
                    step = 5;
                    stepStart = Date.now();
                }
                break;

            case 5:
                if (Date.now() - stepStart > 400) {
                    radial.focusedCategoryIndex = 0;
                    step = 6;
                    stepStart = Date.now();
                }
                break;

            case 6:
                if (Date.now() - stepStart > 400) {
                    console.log("=== STEP 6: Full cycle traversed ===");
                    console.log("wheelRotation: " + wheel.wheelRotation + " (visually 90 deg, raw value=" + wheel.wheelRotation + ")");
                    // Now collapse
                    step = 7;
                    stepStart = Date.now();
                    radial.isExpanded = false;
                }
                break;

            case 7:
                if (Date.now() - stepStart > 800) {
                    console.log("=== STEP 7: Fully settled after multi-category cycle ===");
                    console.log("Final wheelRotation: " + wheel.wheelRotation);
                    console.log("Final isExpanded: " + radial.isExpanded + ", wheelExpanded: " + radial.wheelExpanded);
                    if (wheel.wheelRotation === 0.0) {
                        console.log("[PASS] Rotation returned to 0.0");
                    } else {
                        console.error("[FAIL] CRITICAL DEFECT: Wheel rotation failed to return cleanly to 0.0! It is resting at: " + wheel.wheelRotation);
                    }
                    reproTimer.running = false;
                    Qt.quit();
                }
                break;
            }
        }
    }
}
