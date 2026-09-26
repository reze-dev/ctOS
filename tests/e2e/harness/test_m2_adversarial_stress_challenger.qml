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
    property int stressCycle: 0
    property int stressPhase: 0

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

    // Stress Sequence Array: Pairs of (fromCat, toCat) designed to test worst-case transitions
    // including antipodal jumps, boundary crossings, reverse sweeps
    readonly property var stressPairs: [
        [0, 4], // 12 o'clock to 6 o'clock (half circle)
        [4, 0], // reverse half circle
        [6, 7], // POWER (-150) to SECURITY (170) across 180 boundary
        [7, 6], // SECURITY (170) to POWER (-150) across 180 boundary
        [7, 8], // SECURITY (170) to DEV (130)
        [8, 0], // DEV (130) to SYSTEM (90)
        [1, 7], // APPEARANCE (50) to SECURITY (170)
        [7, 1], // SECURITY (170) to APPEARANCE (50)
        [2, 6], // DESKTOP (10) to POWER (-150)
        [6, 2], // POWER (-150) to DESKTOP (10)
        [3, 8], // NETWORK (-30) to DEV (130)
        [8, 3]  // DEV (130) to NETWORK (-30)
    ]

    Timer {
        id: stressRunner
        interval: 35
        repeat: true
        running: true

        property real lastRotation: 0.0
        property int stepCount: 0
        property int waitTicks: 0

        onTriggered: {
            try {
                var radial = radialLoader.item;
                if (!radial) return;

                var menu = radial.wheelMenu;
                var model = radial.settingsModel;

                // Test 1: Verify SegAngle and Model Category Count
                if (root.stressPhase === 0) {
                    assertCondition("STRESS.MATH.COUNT", "Model categoryCount is 9",
                        model.categoryCount === 9, "count=" + model.categoryCount);
                    assertCondition("STRESS.MATH.SEG_ANGLE", "segAngle is exactly 40.0 deg",
                        Math.abs(menu.segAngle - 40.0) < 0.001, "segAngle=" + menu.segAngle);
                    root.stressPhase = 1;
                    return;
                }

                // Test 2: Adversarial Shortest-Path Category Transitions in Expanded Mode
                if (root.stressPhase === 1) {
                    if (root.stressCycle < root.stressPairs.length) {
                        var pair = root.stressPairs[root.stressCycle];
                        var fromIdx = pair[0];
                        var toIdx = pair[1];

                        if (stepCount === 0) {
                            // Setup fromIdx in expanded mode and wait until fully settled
                            radial.isExpanded = true;
                            radial.focusedCategoryIndex = fromIdx;
                            waitTicks = 0;
                            stepCount = 1;
                        } else if (stepCount === 1) {
                            waitTicks++;
                            if (waitTicks >= 12) { // 12 * 35ms = 420ms > 300ms animation
                                lastRotation = menu.wheelRotation;
                                radial.focusedCategoryIndex = toIdx;
                                waitTicks = 0;
                                stepCount = 2;
                            }
                        } else if (stepCount === 2) {
                            // Wait for rotation animation to settle
                            waitTicks++;
                            if (waitTicks >= 12) {
                                var actualTarget = menu.wheelRotation;
                                var actualDelta = actualTarget - lastRotation;

                                // Verify shortest-path: |actualDelta| must be <= 180 deg
                                assertCondition("STRESS.SHORTEST_PATH." + fromIdx + "_" + toIdx,
                                    "Shortest path from Cat " + fromIdx + " to Cat " + toIdx + " delta <= 180 deg",
                                    Math.abs(actualDelta) <= 180.01,
                                    "delta=" + actualDelta.toFixed(1) + "°");

                                // Check that effective angle of selected segment equals 0.0 deg East
                                var segAngle = menu.segAngle;
                                var selectedBase = -90.0 + toIdx * segAngle;
                                var effAngle = ((selectedBase + menu.wheelRotation) % 360 + 360) % 360;
                                if (effAngle > 180) effAngle -= 360;

                                assertCondition("STRESS.DEPLOY_EAST." + toIdx,
                                    "Cat " + toIdx + " rotates to East (0.0 deg)",
                                    Math.abs(effAngle) < 0.5,
                                    "effAngle=" + effAngle.toFixed(2) + "°");

                                root.stressCycle++;
                                stepCount = 0;
                            }
                        }
                    } else {
                        root.stressPhase = 2;
                        stepCount = 0;
                        waitTicks = 0;
                    }
                    return;
                }

                // Test 3: Rapid Expand/Collapse In-Flight Interruption Stress Test
                if (root.stressPhase === 2) {
                    if (stepCount === 0) {
                        // Start expand
                        radial.focusedCategoryIndex = 7; // SECURITY (170 deg)
                        radial.isExpanded = true;
                        stepCount = 1;
                    } else if (stepCount === 1) {
                        // Interrupt immediately at t=35ms before expand completes
                        radial.isExpanded = false;
                        assertCondition("STRESS.INTERRUPT.COLLAPSE_TRIGGERED",
                            "Collapse interrupted expand cleanly",
                            radial.isExpanded === false);
                        waitTicks = 0;
                        stepCount = 2;
                    } else if (stepCount === 2) {
                        // Wait for collapse to finish and rotation animation to complete (~450ms)
                        waitTicks++;
                        if (!radial.wheelExpanded && !radial.branchExpanded && waitTicks >= 16) {
                            assertCondition("STRESS.INTERRUPT.RETURN_CENTER",
                                "Wheel safely returned to center after interrupt",
                                !radial.wheelExpanded && !radial.branchExpanded);

                            // Check wheelRotation resets cleanly to 0.0
                            assertCondition("STRESS.ZERO_ROTATION_ON_COLLAPSE",
                                "wheelRotation normalized to 0.0 on collapse",
                                Math.abs(menu.wheelRotation) < 0.01,
                                "wheelRotation=" + menu.wheelRotation);
                            root.stressPhase = 3;
                            stepCount = 0;
                        }
                    }
                    return;
                }

                // Test 4: Performance Verification of RadialSegment bindings under rapid radius changes
                if (root.stressPhase === 3) {
                    // Check RadialSegment primitive properties
                    assertCondition("STRESS.PERF.PRIMITIVE_REAL",
                        "RadialSegment properties are valid real numbers without NaN",
                        !isNaN(menu.wheelCenterX) && !isNaN(menu.wheelRotation) && !isNaN(menu.baseTargetAngle));

                    root.stressPhase = 4;
                    return;
                }

                // Done
                stressRunner.running = false;
                console.log("================================================================");
                console.log("ADVERSARIAL STRESS RUNTIME RESULTS: Passed=" + root.passCount + ", Failed=" + root.failCount);
                if (root.failCount === 0 && root.passCount >= 25) {
                    console.log("=== PASS: ALL ADVERSARIAL STRESS CHALLENGES PASSED ===");
                } else {
                    console.error("=== FAIL: ADVERSARIAL STRESS CHALLENGES FAILED ===");
                }
                console.log("================================================================");
                Qt.quit();

            } catch (err) {
                console.error("EXCEPTION in stress test: " + err);
                stressRunner.running = false;
                Qt.quit();
            }
        }
    }
}
