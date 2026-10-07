pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import desktop.core
import desktop.services
import desktop.surfaces.radial

Scope {
    id: root

    property int passCount: 0
    property int failCount: 0
    property int testState: 0
    property int waitTicks: 0

    function assertCondition(testId, desc, condition, details) {
        if (condition) {
            passCount++;
            console.log("[PASS] " + testId + ": " + desc + (details ? " (" + details + ")" : ""));
        } else {
            failCount++;
            console.error("[FAIL] " + testId + ": " + desc + (details ? " (" + details + ")" : ""));
        }
    }

    Item {
        id: container
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
        id: testLoop
        interval: 30
        repeat: true
        running: true

        property int currentCat: 0
        property real startRotation: 0.0
        property real initialTimestamp: 0

        onTriggered: {
            try {
                var radial = radialLoader.item;
                if (!radial) return;
                var menu = radial.wheelMenu;

                switch (root.testState) {
                case 0:
                    // State 0: Expand with category 7 (SECURITY: selectedBaseAngle = 190, target = 170)
                    radial.focusedCategoryIndex = 7;
                    radial.isExpanded = true;
                    initialTimestamp = Date.now();
                    root.testState = 1;
                    break;

                case 1:
                    // State 1: Wait for full expand (branchExpanded == true, wheel at left)
                    if (radial.branchExpanded) {
                        var elapsed = Date.now() - initialTimestamp;
                        assertCondition("EXPAND.TIMING", "Expand completes in under 700ms",
                            elapsed < 700, "elapsed=" + elapsed + "ms");
                        assertCondition("EXPAND.TARGET_ANGLE", "Security target angle is 170 deg",
                            Math.abs(menu.baseTargetAngle - 170.0) < 0.1, "baseTargetAngle=" + menu.baseTargetAngle);

                        // Now initiate collapse
                        radial.isExpanded = false;
                        initialTimestamp = Date.now();
                        root.testState = 2;
                        waitTicks = 0;
                    }
                    break;

                case 2:
                    // State 2: Wait for full collapse completion (collapse animation finished + durationSlow elapsed)
                    waitTicks++;
                    // Theme.durationSlow is 300ms, collapseTimerWheelReturn is 140ms -> total collapse time ~440ms
                    // At 30ms per tick, 20 ticks = 600ms, ample time for full finish
                    if (!radial.wheelExpanded && !radial.branchExpanded && waitTicks >= 20) {
                        var collapseElapsed = Date.now() - initialTimestamp;
                        assertCondition("COLLAPSE.TIMING", "Collapse completes smoothly in under 700ms",
                            collapseElapsed < 700, "collapseElapsed=" + collapseElapsed + "ms");

                        // Verify wheelRotation is strictly 0.0
                        assertCondition("COLLAPSE.ZERO_ROTATION", "Wheel rotation resets to 0.0 on collapse finish",
                            Math.abs(menu.wheelRotation) < 0.001, "wheelRotation=" + menu.wheelRotation);

                        // Move to shortest-path test across boundary in expanded mode
                        radial.focusedCategoryIndex = 6; // POWER (-150)
                        radial.isExpanded = true;
                        root.testState = 3;
                        waitTicks = 0;
                    }
                    break;

                case 3:
                    // State 3: Wait until POWER is fully settled at -150
                    waitTicks++;
                    if (radial.branchExpanded && waitTicks >= 15) {
                        assertCondition("POWER.SETTLED", "Power settled at -150 deg",
                            Math.abs(menu.wheelRotation - (-150.0)) < 1.0, "wheelRotation=" + menu.wheelRotation);

                        // Now switch directly to SECURITY (index 7, target 170)
                        startRotation = menu.wheelRotation;
                        radial.focusedCategoryIndex = 7;
                        root.testState = 4;
                        waitTicks = 0;
                    }
                    break;

                case 4:
                    // State 4: Wait for transition from POWER to SECURITY to finish
                    waitTicks++;
                    if (waitTicks >= 15) {
                        // In shortest-path rotation:
                        // from -150 to +170:
                        // delta is -40 deg (CW rotation)
                        // start was -150, so final wheelRotation should be -150 + (-40) = -190!
                        // AND normalized angle should be +170!
                        var normRot = ((menu.wheelRotation % 360) + 360) % 360;
                        if (normRot > 180) normRot -= 360;

                        assertCondition("BOUNDARY.SHORTEST_PATH_VALUE",
                            "Continuous shortest-path rotation from -150 to 170 took -40 deg delta (-190 total)",
                            Math.abs(menu.wheelRotation - (-190.0)) < 1.0,
                            "wheelRotation=" + menu.wheelRotation + ", norm=" + normRot);

                        assertCondition("BOUNDARY.EFFECTIVE_NORM",
                            "Effective normalized wheel rotation is 170 deg",
                            Math.abs(normRot - 170.0) < 1.0,
                            "normRot=" + normRot);

                        // Now switch BACK from SECURITY (index 7) to POWER (index 6)
                        startRotation = menu.wheelRotation;
                        radial.focusedCategoryIndex = 6;
                        root.testState = 5;
                        waitTicks = 0;
                    }
                    break;

                case 5:
                    // State 5: Wait for transition back from SECURITY to POWER
                    waitTicks++;
                    if (waitTicks >= 15) {
                        // From -190 (effective 170) back to -150:
                        // delta is +40 deg
                        // start was -190, so final wheelRotation should be -190 + 40 = -150!
                        var normRot2 = ((menu.wheelRotation % 360) + 360) % 360;
                        if (normRot2 > 180) normRot2 -= 360;

                        assertCondition("BOUNDARY.REVERSE_SHORTEST_PATH",
                            "Reverse shortest-path rotation from 170 to -150 took +40 deg delta (-150 total)",
                            Math.abs(menu.wheelRotation - (-150.0)) < 1.0,
                            "wheelRotation=" + menu.wheelRotation + ", norm=" + normRot2);

                        // Collapse back
                        radial.isExpanded = false;
                        root.testState = 6;
                        waitTicks = 0;
                    }
                    break;

                case 6:
                    // State 6: Wait for final collapse
                    waitTicks++;
                    if (!radial.wheelExpanded && !radial.branchExpanded && waitTicks >= 20) {
                        assertCondition("FINAL.COLLAPSE_ZERO",
                            "Final wheel rotation normalized to 0.0",
                            Math.abs(menu.wheelRotation) < 0.001,
                            "wheelRotation=" + menu.wheelRotation);

                        testLoop.running = false;
                        console.log("================================================================");
                        console.log("EMPIRICAL TEST RESULTS: Passed=" + root.passCount + ", Failed=" + root.failCount);
                        if (root.failCount === 0 && root.passCount >= 8) {
                            console.log("=== PASS: ALL EMPIRICAL CHALLENGER TESTS VERIFIED ===");
                        } else {
                            console.error("=== FAIL: EMPIRICAL TESTS FAILED ===");
                        }
                        console.log("================================================================");
                        Qt.quit();
                    }
                    break;
                }
            } catch (err) {
                console.error("EXCEPTION: " + err);
                testLoop.running = false;
                Qt.quit();
            }
        }
    }
}
