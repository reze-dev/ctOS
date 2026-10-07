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
    property int testStep: 0

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
        id: stressTester
        interval: 50
        repeat: true
        running: true

        onTriggered: {
            try {
                var radial = radialLoader.item;
                if (!radial) return;

                switch (root.testStep) {
                // -------------------------------------------------------------
                // Test 1: Rapid Toggle / Churn
                // -------------------------------------------------------------
                case 0:
                    console.log("--- Starting Test 1: Rapid Expand/Collapse Churn ---");
                    radial.isExpanded = true;
                    root.testStep = 1;
                    break;

                case 1:
                    // Collapse immediately before expandTimer (180ms) can fire
                    radial.isExpanded = false;
                    assertCondition("ADV.CHURN.01", "Immediate collapse cancelled branch expansion",
                        radial.branchExpanded === false);
                    root.testStep = 2;
                    break;

                case 2:
                    // Rapidly re-expand
                    radial.isExpanded = true;
                    assertCondition("ADV.CHURN.02", "Re-expansion initiated cleanly",
                        radial.wheelExpanded === true && radial.branchExpanded === false);
                    root.testStep = 3;
                    break;

                case 3:
                    // Wait for expandTimer to fire
                    if (radial.branchExpanded) {
                        assertCondition("ADV.CHURN.03", "Branch deployed after full expand delay",
                            radial.branchExpanded === true);
                        root.testStep = 4;
                    }
                    break;

                // -------------------------------------------------------------
                // Test 2: Escape Key Collapse Handling
                // -------------------------------------------------------------
                case 4:
                    console.log("--- Starting Test 2: Escape Key Press ---");
                    var handledEsc = radial.navCtrl.handleKeyPress(Qt.Key_Escape);
                    assertCondition("ADV.ESC.01", "handleKeyPress(Qt.Key_Escape) handled and returned true",
                        handledEsc === true);
                    assertCondition("ADV.ESC.02", "Escape triggered isExpanded = false",
                        radial.isExpanded === false);
                    root.testStep = 5;
                    break;

                case 5:
                    // Wait for collapse to finish
                    if (!radial.wheelExpanded && !radial.branchExpanded) {
                        assertCondition("ADV.ESC.03", "Clean collapse achieved via Escape key",
                            !radial.wheelExpanded && !radial.branchExpanded);
                        root.testStep = 6;
                    }
                    break;

                // -------------------------------------------------------------
                // Test 3: Backspace Key Collapse Handling
                // -------------------------------------------------------------
                case 6:
                    console.log("--- Starting Test 3: Backspace Key Press ---");
                    radial.isExpanded = true;
                    root.testStep = 7;
                    break;

                case 7:
                    if (radial.branchExpanded) {
                        var handledBack = radial.navCtrl.handleKeyPress(Qt.Key_Backspace);
                        assertCondition("ADV.BACKSPACE.01", "handleKeyPress(Qt.Key_Backspace) handled and returned true",
                            handledBack === true);
                        assertCondition("ADV.BACKSPACE.02", "Backspace triggered isExpanded = false",
                            radial.isExpanded === false);
                        root.testStep = 8;
                    }
                    break;

                case 8:
                    if (!radial.wheelExpanded && !radial.branchExpanded) {
                        assertCondition("ADV.BACKSPACE.03", "Clean collapse achieved via Backspace key",
                            !radial.wheelExpanded && !radial.branchExpanded);
                        root.testStep = 9;
                    }
                    break;

                // -------------------------------------------------------------
                // Test 4: Center Hub Collapse Signal
                // -------------------------------------------------------------
                case 9:
                    console.log("--- Starting Test 4: Center Hub Collapse Signal ---");
                    radial.isExpanded = true;
                    root.testStep = 10;
                    break;

                case 10:
                    if (radial.branchExpanded) {
                        radial.wheelMenu.collapseRequested();
                        assertCondition("ADV.HUB.01", "collapseRequested signal set isExpanded = false",
                            radial.isExpanded === false);
                        root.testStep = 11;
                    }
                    break;

                case 11:
                    if (!radial.wheelExpanded && !radial.branchExpanded) {
                        assertCondition("ADV.HUB.02", "Clean collapse achieved via Hub collapseRequested",
                            !radial.wheelExpanded && !radial.branchExpanded);
                        root.testStep = 12;
                    }
                    break;

                // -------------------------------------------------------------
                // Test 5: Visibility Reset
                // -------------------------------------------------------------
                case 12:
                    console.log("--- Starting Test 5: Visibility Hide and Restore ---");
                    radial.isExpanded = true;
                    root.testStep = 13;
                    break;

                case 13:
                    if (radial.branchExpanded) {
                        radial.visible = false;
                        assertCondition("ADV.VIS.01", "Hiding surface immediately resets isExpanded to false",
                            radial.isExpanded === false);
                        assertCondition("ADV.VIS.02", "Hiding surface immediately resets wheelExpanded",
                            radial.wheelExpanded === false);
                        assertCondition("ADV.VIS.03", "Hiding surface immediately resets branchExpanded",
                            radial.branchExpanded === false);

                        radial.visible = true;
                        assertCondition("ADV.VIS.04", "Restoring visibility leaves surface in clean root state",
                            !radial.isExpanded && !radial.wheelExpanded && !radial.branchExpanded);
                        root.testStep = 14;
                    }
                    break;

                case 14:
                    // Final resting state check
                    var restingX = radial.wheelMenu.wheelCenterX;
                    var expectedCenterX = testContainer.width / 2; // 960
                    assertCondition("ADV.FINAL.01", "Wheel target center is screen center (960px)",
                        radial.wheelMenu.targetCenterX === expectedCenterX,
                        "targetCenterX=" + radial.wheelMenu.targetCenterX);

                    stressTester.running = false;
                    console.log("================================================================");
                    console.log("ADVERSARIAL STRESS TEST RESULTS: Passed=" + root.passCount + ", Failed=" + root.failCount);
                    if (root.failCount === 0 && root.passCount >= 14) {
                        console.log("=== PASS: ALL ADVERSARIAL STRESS SCENARIOS RESILIENT ===");
                    } else {
                        console.error("=== FAIL: ADVERSARIAL STRESS TEST FAILED ===");
                    }
                    console.log("================================================================");
                    Qt.quit();
                    break;
                }
            } catch (err) {
                console.error("EXCEPTION in adversarial stress test: " + err);
                stressTester.running = false;
                Qt.quit();
            }
        }
    }
}
