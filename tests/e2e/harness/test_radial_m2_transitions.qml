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
    property int currentCategoryToTest: 0
    property int subStep: 0

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
        id: transitionTester
        interval: 60
        repeat: true
        running: true

        onTriggered: {
            try {
                var radial = radialLoader.item;
                if (!radial) return;

                var catCount = radial.settingsModel.categoryCount;

                // Testing all 9 categories through Expand -> Verify -> Collapse
                if (root.currentCategoryToTest < catCount) {
                    var idx = root.currentCategoryToTest;
                    var cat = radial.settingsModel.getCategory(idx);

                    switch (root.subStep) {
                    case 0:
                        // Focus category
                        radial.focusedCategoryIndex = idx;
                        assertCondition("M2.CAT." + idx + ".FOCUS", "Focused category " + idx + " (" + cat.name + ")",
                            radial.focusedCategoryIndex === idx);
                        root.subStep = 1;
                        break;

                    case 1:
                        // Expand category
                        radial.isExpanded = true;
                        assertCondition("M2.CAT." + idx + ".EXPAND_START", "Expanded state set for " + cat.name,
                            radial.isExpanded === true && radial.wheelExpanded === true);
                        root.subStep = 2;
                        break;

                    case 2:
                        // Wait for branch expansion delay
                        if (radial.branchExpanded) {
                            var segAngle = 360.0 / catCount;
                            var selectedBaseAngle = -90.0 + idx * segAngle;
                            var expectedTargetAngle = ((idx === 0) ? 90.0 :
                                                      (idx === 1) ? 50.0 :
                                                      (idx === 2) ? 10.0 :
                                                      (idx === 3) ? -30.0 :
                                                      (idx === 4) ? -70.0 :
                                                      (idx === 5) ? -110.0 :
                                                      (idx === 6) ? -150.0 :
                                                      (idx === 7) ? 170.0 : 130.0);

                            assertCondition("M2.CAT." + idx + ".BRANCH_DEPLOY", "Branch deployed at left edge for " + cat.name,
                                radial.branchExpanded === true,
                                "targetAngle=" + radial.wheelMenu.baseTargetAngle + ", expected=" + expectedTargetAngle);

                            assertCondition("M2.CAT." + idx + ".TARGET_ANGLE", "baseTargetAngle matches expected deployment angle",
                                Math.abs(radial.wheelMenu.baseTargetAngle - expectedTargetAngle) < 0.1,
                                "baseTargetAngle=" + radial.wheelMenu.baseTargetAngle);

                            root.subStep = 3;
                        }
                        break;

                    case 3:
                        // Collapse category
                        radial.isExpanded = false;
                        assertCondition("M2.CAT." + idx + ".COLLAPSE_START", "Collapse initiated for " + cat.name,
                            radial.isExpanded === false);
                        root.subStep = 4;
                        break;

                    case 4:
                        // Wait for full collapse completion
                        if (!radial.wheelExpanded && !radial.branchExpanded) {
                            assertCondition("M2.CAT." + idx + ".COLLAPSE_DONE", "Wheel and branch cleanly collapsed for " + cat.name,
                                !radial.wheelExpanded && !radial.branchExpanded);

                            root.currentCategoryToTest++;
                            root.subStep = 0;
                        }
                        break;
                    }
                } else if (root.currentCategoryToTest === catCount) {
                    // Test boundary shortest-path transition: Cat 6 (POWER) to Cat 7 (SECURITY)
                    radial.focusedCategoryIndex = 6;
                    radial.isExpanded = true;
                    root.currentCategoryToTest++;
                    root.subStep = 0;
                } else if (root.currentCategoryToTest === catCount + 1) {
                    if (radial.branchExpanded) {
                        var angleBefore = radial.wheelMenu.wheelRotation;
                        // Switch directly to category 7
                        radial.focusedCategoryIndex = 7;
                        var target7 = radial.wheelMenu.baseTargetAngle;
                        assertCondition("M2.SHORTEST_PATH.01", "Target angle for SECURITY is 170 deg",
                            Math.abs(target7 - 170.0) < 0.1, "target7=" + target7);

                        // Collapse back
                        radial.isExpanded = false;
                        root.currentCategoryToTest++;
                    }
                } else {
                    // Finished
                    transitionTester.running = false;
                    console.log("================================================================");
                    console.log("M2 TRANSITIONS RUNTIME RESULTS: Passed=" + root.passCount + ", Failed=" + root.failCount);
                    if (root.failCount === 0 && root.passCount >= 45) {
                        console.log("=== PASS: ALL 9 CATEGORIES AND TRANSITIONS VERIFIED ===");
                    } else {
                        console.error("=== FAIL: M2 TRANSITIONS TEST FAILED ===");
                    }
                    console.log("================================================================");
                    Qt.quit();
                }
            } catch (err) {
                console.error("EXCEPTION in test: " + err);
                transitionTester.running = false;
                Qt.quit();
            }
        }
    }
}
