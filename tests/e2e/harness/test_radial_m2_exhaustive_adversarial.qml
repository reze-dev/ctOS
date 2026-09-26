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
    property string failureLog: ""

    function assertCondition(testId, desc, condition, details) {
        if (condition) {
            passCount++;
            console.log("[PASS] " + testId + ": " + desc + (details ? " (" + details + ")" : ""));
        } else {
            failCount++;
            var msg = "[FAIL] " + testId + ": " + desc + (details ? " (" + details + ")" : "");
            failureLog += msg + "\n";
            console.error(msg);
        }
    }

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
        id: harnessTimer
        interval: 20
        repeat: true
        running: true

        property int phase: 0
        property int step: 0
        property double stepStartTime: 0.0
        property int currentCatIndex: 0

        // Timing measurements
        property double animStartTime: 0.0
        property var expandDurations: []
        property var collapseDurations: []

        onTriggered: {
            try {
                var radial = radialLoader.item;
                if (!radial) return;
                var wheel = radial.wheelMenu;
                var now = Date.now();

                switch (phase) {
                // =============================================================
                // PHASE 0: Pre-flight Verification
                // =============================================================
                case 0:
                    console.log("=== PHASE 0: PRE-FLIGHT CHECKS ===");
                    assertCondition("PRE.01", "Initial isExpanded is false", radial.isExpanded === false);
                    assertCondition("PRE.02", "Initial wheelExpanded is false", radial.wheelExpanded === false);
                    assertCondition("PRE.03", "Initial branchExpanded is false", radial.branchExpanded === false);
                    assertCondition("PRE.04", "Initial wheelRotation is 0.0", wheel.wheelRotation === 0.0, "actual=" + wheel.wheelRotation);
                    phase = 1;
                    step = 0;
                    stepStartTime = now;
                    break;

                // =============================================================
                // PHASE 1: Expand & Collapse Timing Across ALL 9 Categories (<700ms)
                // =============================================================
                case 1:
                    if (step === 0) {
                        // Start expand for currentCatIndex
                        radial.focusedCategoryIndex = currentCatIndex;
                        animStartTime = now;
                        radial.isExpanded = true;
                        step = 1;
                    } else if (step === 1) {
                        // Wait for expand completion: branchExpanded == true AND wheelCenterX settled
                        var dx = Math.abs(wheel.wheelCenterX - wheel.leftAnchorX);
                        if (radial.branchExpanded && dx < 2.0) {
                            var expandDur = now - animStartTime;
                            expandDurations.push(expandDur);
                            assertCondition("TIME.EXPAND.CAT" + currentCatIndex,
                                "Expand Cat " + currentCatIndex + " completed within 700ms",
                                expandDur < 700, "duration=" + expandDur + "ms");

                            // Now start collapse
                            animStartTime = now;
                            radial.isExpanded = false;
                            step = 2;
                        } else if (now - animStartTime > 1500) {
                            assertCondition("TIME.EXPAND.CAT" + currentCatIndex,
                                "Expand Cat " + currentCatIndex + " TIMED OUT (>1500ms)", false);
                            step = 2;
                        }
                    } else if (step === 2) {
                        // Wait for full collapse completion:
                        // 1) wheelExpanded == false, branchExpanded == false
                        // 2) wheelCenterX settled at screen center (960)
                        // 3) wheelRotation settled cleanly at 0.0
                        var dCenterX = Math.abs(wheel.wheelCenterX - 960);
                        var isSettled = !radial.wheelExpanded && !radial.branchExpanded && dCenterX < 0.5 && wheel.wheelRotation === 0.0;

                        if (isSettled) {
                            var collapseDur = now - animStartTime;
                            collapseDurations.push(collapseDur);
                            assertCondition("TIME.COLLAPSE.CAT" + currentCatIndex,
                                "Collapse Cat " + currentCatIndex + " completed within 700ms",
                                collapseDur < 700, "duration=" + collapseDur + "ms");
                            assertCondition("ROT.CLEAN.CAT" + currentCatIndex,
                                "Collapse Cat " + currentCatIndex + " returned wheelRotation cleanly to 0.0",
                                wheel.wheelRotation === 0.0, "actual=" + wheel.wheelRotation);

                            currentCatIndex++;
                            if (currentCatIndex < 9) {
                                step = 0;
                            } else {
                                console.log("=== PHASE 1 COMPLETE: All 9 expand/collapse durations verified < 700ms ===");
                                phase = 2;
                                step = 0;
                                stepStartTime = now;
                            }
                        } else if (now - animStartTime > 700) {
                            // Violated the 700ms requirement!
                            var collapseDur = now - animStartTime;
                            assertCondition("TIME.COLLAPSE.CAT" + currentCatIndex,
                                "Collapse Cat " + currentCatIndex + " EXCEEDED 700ms limit",
                                false, "duration=" + collapseDur + "ms, rot=" + wheel.wheelRotation + ", dCenterX=" + dCenterX);
                            assertCondition("ROT.CLEAN.CAT" + currentCatIndex,
                                "Collapse Cat " + currentCatIndex + " clean return check",
                                wheel.wheelRotation === 0.0, "actual=" + wheel.wheelRotation);
                            currentCatIndex++;
                            step = (currentCatIndex < 9) ? 0 : 3;
                            if (currentCatIndex >= 9) phase = 2;
                        }
                    }
                    break;

                // =============================================================
                // PHASE 2: Multi-Revolution Traversal (Clockwise: 2 full revolutions = -720 deg)
                // =============================================================
                case 2:
                    if (step === 0) {
                        console.log("=== PHASE 2: MULTI-REVOLUTION CLOCKWISE TRAVERSAL (2 FULL REVS) ===");
                        radial.focusedCategoryIndex = 0;
                        radial.isExpanded = true;
                        step = 1;
                        stepStartTime = now;
                    } else if (step === 1) {
                        // Wait for expand
                        if (radial.branchExpanded) {
                            step = 2;
                            currentCatIndex = 0;
                            stepStartTime = now;
                        }
                    } else if (step === 2) {
                        // Step through 18 category increments (2 full cycles 0..8..0..8..0)
                        if (now - stepStartTime > 60) {
                            currentCatIndex++;
                            radial.focusedCategoryIndex = currentCatIndex % 9;
                            stepStartTime = now;
                            if (currentCatIndex === 18) {
                                step = 3;
                                stepStartTime = now;
                            }
                        }
                    } else if (step === 3) {
                        // Wait for rotation to settle after full cycle
                        if (now - stepStartTime > 400) {
                            var expectedRot = 90.0 - 720.0; // -630.0
                            console.log("After 2 full CW cycles: wheelRotation=" + wheel.wheelRotation);
                            assertCondition("MULTI.CW.EXPANDED",
                                "Continuous rotation tracked displacement correctly",
                                Math.abs(wheel.wheelRotation - expectedRot) < 0.5,
                                "rot=" + wheel.wheelRotation + ", expected=" + expectedRot);

                            // Now initiate collapse
                            radial.isExpanded = false;
                            animStartTime = now;
                            step = 4;
                        }
                    } else if (step === 4) {
                        var dCenterX = Math.abs(wheel.wheelCenterX - 960);
                        if (!radial.wheelExpanded && !radial.branchExpanded && dCenterX < 2.0) {
                            // Give extra 50ms for onRunningChanged to reset wheelRotation
                            step = 5;
                            stepStartTime = now;
                        } else if (now - animStartTime > 1500) {
                            assertCondition("MULTI.CW.COLLAPSE", "Collapse after 2 CW revolutions TIMED OUT", false);
                            phase = 3;
                            step = 0;
                        }
                    } else if (step === 5) {
                        if (now - stepStartTime > 100) {
                            console.log("Final wheelRotation after 2 CW revs collapse: " + wheel.wheelRotation);
                            assertCondition("MULTI.CW.CLEAN_ZERO",
                                "wheelRotation returned cleanly to 0.0 after -720 deg traversal",
                                wheel.wheelRotation === 0.0, "actual=" + wheel.wheelRotation);
                            phase = 3;
                            step = 0;
                            stepStartTime = now;
                        }
                    }
                    break;

                // =============================================================
                // PHASE 3: Multi-Revolution Traversal (Counter-Clockwise: 2 full revolutions = +720 deg)
                // =============================================================
                case 3:
                    if (step === 0) {
                        console.log("=== PHASE 3: MULTI-REVOLUTION COUNTER-CLOCKWISE TRAVERSAL (+720 DEG) ===");
                        radial.focusedCategoryIndex = 0;
                        radial.isExpanded = true;
                        step = 1;
                        stepStartTime = now;
                    } else if (step === 1) {
                        if (radial.branchExpanded) {
                            step = 2;
                            currentCatIndex = 18;
                            stepStartTime = now;
                        }
                    } else if (step === 2) {
                        // Step backward 18 category increments
                        if (now - stepStartTime > 60) {
                            currentCatIndex--;
                            var cat = ((currentCatIndex % 9) + 9) % 9;
                            radial.focusedCategoryIndex = cat;
                            stepStartTime = now;
                            if (currentCatIndex === 0) {
                                step = 3;
                                stepStartTime = now;
                            }
                        }
                    } else if (step === 3) {
                        if (now - stepStartTime > 400) {
                            var expectedRot = 90.0 + 720.0; // 810.0
                            console.log("After 2 full CCW cycles: wheelRotation=" + wheel.wheelRotation);
                            assertCondition("MULTI.CCW.EXPANDED",
                                "Continuous rotation tracked CCW displacement correctly",
                                Math.abs(wheel.wheelRotation - expectedRot) < 0.5,
                                "rot=" + wheel.wheelRotation + ", expected=" + expectedRot);

                            radial.isExpanded = false;
                            animStartTime = now;
                            step = 4;
                        }
                    } else if (step === 4) {
                        var dCenterX = Math.abs(wheel.wheelCenterX - 960);
                        if (!radial.wheelExpanded && !radial.branchExpanded && dCenterX < 2.0) {
                            step = 5;
                            stepStartTime = now;
                        } else if (now - animStartTime > 1500) {
                            assertCondition("MULTI.CCW.COLLAPSE", "Collapse after 2 CCW revolutions TIMED OUT", false);
                            phase = 4;
                            step = 0;
                        }
                    } else if (step === 5) {
                        if (now - stepStartTime > 100) {
                            console.log("Final wheelRotation after 2 CCW revs collapse: " + wheel.wheelRotation);
                            assertCondition("MULTI.CCW.CLEAN_ZERO",
                                "wheelRotation returned cleanly to 0.0 after +720 deg traversal",
                                wheel.wheelRotation === 0.0, "actual=" + wheel.wheelRotation);
                            phase = 4;
                            step = 0;
                            stepStartTime = now;
                        }
                    }
                    break;

                // =============================================================
                // PHASE 4: Rapid Mid-Flight Interruption & Churn
                // =============================================================
                case 4:
                    if (step === 0) {
                        console.log("=== PHASE 4: RAPID MID-FLIGHT INTERRUPTION ===");
                        // Trigger expand
                        radial.focusedCategoryIndex = 4; // AUDIO
                        radial.isExpanded = true;
                        step = 1;
                        stepStartTime = now;
                    } else if (step === 1) {
                        // At 60ms into expand, reverse to collapse!
                        if (now - stepStartTime >= 60) {
                            radial.isExpanded = false;
                            step = 2;
                            stepStartTime = now;
                        }
                    } else if (step === 2) {
                        // At 60ms into collapse, re-expand!
                        if (now - stepStartTime >= 60) {
                            radial.isExpanded = true;
                            step = 3;
                            stepStartTime = now;
                        }
                    } else if (step === 3) {
                        // Allow to fully expand
                        if (radial.branchExpanded && Math.abs(wheel.wheelCenterX - wheel.leftAnchorX) < 2.0) {
                            assertCondition("INTERRUPT.EXPAND", "Successfully expanded after rapid churn", true);
                            radial.isExpanded = false;
                            step = 4;
                            stepStartTime = now;
                        } else if (now - stepStartTime > 1500) {
                            assertCondition("INTERRUPT.EXPAND", "Expansion after churn timed out", false);
                            step = 4;
                        }
                    } else if (step === 4) {
                        // Wait for final collapse
                        var dCenterX = Math.abs(wheel.wheelCenterX - 960);
                        if (!radial.wheelExpanded && !radial.branchExpanded && dCenterX < 2.0) {
                            step = 5;
                            stepStartTime = now;
                        } else if (now - stepStartTime > 1500) {
                            assertCondition("INTERRUPT.COLLAPSE", "Collapse after churn timed out", false);
                            phase = 5;
                            step = 0;
                        }
                    } else if (step === 5) {
                        if (now - stepStartTime > 100) {
                            assertCondition("INTERRUPT.CLEAN_ZERO",
                                "wheelRotation is 0.0 after mid-flight churn and collapse",
                                wheel.wheelRotation === 0.0, "actual=" + wheel.wheelRotation);
                            phase = 5;
                            step = 0;
                            stepStartTime = now;
                        }
                    }
                    break;

                // =============================================================
                // PHASE 5: Summary & Exit
                // =============================================================
                case 5:
                    harnessTimer.running = false;
                    console.log("================================================================");
                    console.log("EXHAUSTIVE CHALLENGER RESULTS: Passed=" + root.passCount + ", Failed=" + root.failCount);
                    if (root.failCount === 0) {
                        console.log("=== VERDICT: ALL TRANSITIONS, DURATIONS & 0.0 RETURNS CONFIRMED ===");
                    } else {
                        console.error("=== VERDICT: DEFECTS DETECTED ===");
                        console.error(root.failureLog);
                    }
                    console.log("================================================================");
                    Qt.quit();
                    break;
                }
            } catch (err) {
                console.error("EXCEPTION in exhaustive challenger harness: " + err);
                harnessTimer.running = false;
                Qt.quit();
            }
        }
    }
}
