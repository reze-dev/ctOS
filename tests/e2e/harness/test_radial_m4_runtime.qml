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
    property int step: 0
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
        id: testRunner
        interval: 50
        repeat: true
        running: true

        onTriggered: {
            try {
                var radial = radialLoader.item;

                switch (root.step) {
                case 0:
                    assertCondition("M4.RUN.01", "RadialSettings loaded successfully",
                        radial !== null && radialLoader.status === Loader.Ready);
                    root.step = 1;
                    break;

                case 1:
                    // Expand category 0 (SYSTEM)
                    radial.focusedCategoryIndex = 0;
                    radial.isExpanded = true;
                    root.waitTicks = 0;
                    root.step = 2;
                    break;

                case 2:
                    // Wait for expand choreography (expandTimer 180ms) to deploy branch
                    if (!radial.branchExpanded) {
                        root.waitTicks++;
                        if (root.waitTicks > 20) {
                            assertCondition("M4.RUN.WAIT", "Timed out waiting for branchExpanded", false);
                            testRunner.running = false;
                            Qt.quit();
                        }
                        return;
                    }

                    assertCondition("M4.RUN.02", "Default category is SYSTEM and branch is deployed",
                        radial.focusedCategoryIndex === 0 && radial.branchExpanded === true);
                    assertCondition("M4.RUN.03", "Initial node is sys-core",
                        radial.selectedNodeId === "sys-core");
                    assertCondition("M4.RUN.NODES", "Active nodes populated in expanded tree",
                        radial.navCtrl.activeNodes && radial.navCtrl.activeNodes.length >= 4,
                        "count=" + (radial.navCtrl.activeNodes ? radial.navCtrl.activeNodes.length : 0));
                    root.step = 3;
                    break;

                case 3:
                    // Test Right arrow navigation: from sys-core -> sys-cpu-hex (NEVER sys-profiler!)
                    radial.selectedNodeId = "sys-core";
                    var handledRight1 = radial.navCtrl.handleKeyPress(Qt.Key_Right);
                    assertCondition("M4.RUN.04", "Right arrow from sys-core selects sys-cpu-hex",
                        handledRight1 && radial.selectedNodeId === "sys-cpu-hex",
                        "selectedNodeId=" + radial.selectedNodeId);

                    assertCondition("M4.RUN.05", "Right arrow NEVER jumped to sys-profiler",
                        radial.selectedNodeId !== "sys-profiler");
                    root.step = 4;
                    break;

                case 4:
                    // Test Right arrow navigation from sys-cpu-hex -> sys-profiler
                    var handledRight2 = radial.navCtrl.handleKeyPress(Qt.Key_Right);
                    assertCondition("M4.RUN.06", "Right arrow from sys-cpu-hex selects sys-profiler",
                        handledRight2 && radial.selectedNodeId === "sys-profiler",
                        "selectedNodeId=" + radial.selectedNodeId);
                    root.step = 5;
                    break;

                case 5:
                    // Test Left arrow navigation from sys-profiler -> sys-cpu-hex
                    var handledLeft1 = radial.navCtrl.handleKeyPress(Qt.Key_Left);
                    assertCondition("M4.RUN.07", "Left arrow from sys-profiler returns to sys-cpu-hex",
                        handledLeft1 && radial.selectedNodeId === "sys-cpu-hex",
                        "selectedNodeId=" + radial.selectedNodeId);
                    root.step = 6;
                    break;

                case 6:
                    // Test Left arrow navigation from sys-cpu-hex -> sys-core
                    var handledLeft2 = radial.navCtrl.handleKeyPress(Qt.Key_Left);
                    assertCondition("M4.RUN.08", "Left arrow from sys-cpu-hex returns to sys-core",
                        handledLeft2 && radial.selectedNodeId === "sys-core",
                        "selectedNodeId=" + radial.selectedNodeId);
                    root.step = 7;
                    break;

                case 7:
                    // Test Scroll wheel traversal in expanded mode (down moves forward)
                    radial.navCtrl.handleWheel(-120);
                    assertCondition("M4.RUN.09", "Scroll wheel down advances node in tree order",
                        radial.selectedNodeId === "sys-cpu-hex",
                        "selectedNodeId=" + radial.selectedNodeId);

                    // Scroll wheel up moves back
                    radial.navCtrl.handleWheel(120);
                    assertCondition("M4.RUN.10", "Scroll wheel up returns to sys-core",
                        radial.selectedNodeId === "sys-core",
                        "selectedNodeId=" + radial.selectedNodeId);
                    root.step = 8;
                    break;

                case 8:
                    // Test Left arrow at root node requests collapse
                    var handledLeft3 = radial.navCtrl.handleKeyPress(Qt.Key_Left);
                    assertCondition("M4.RUN.11", "Left arrow at root node requests collapse",
                        handledLeft3);
                    radial.isExpanded = false;
                    root.waitTicks = 0;
                    root.step = 9;
                    break;

                case 9:
                    // Wait for collapse
                    if (radial.isExpanded || radial.branchExpanded) {
                        root.waitTicks++;
                        if (root.waitTicks > 20) {
                            assertCondition("M4.RUN.COLLAPSE_WAIT", "Timed out waiting for collapse", false);
                            testRunner.running = false;
                            Qt.quit();
                        }
                        return;
                    }

                    // In collapsed root mode, test wheel traversal across all 9 categories
                    radial.focusedCategoryIndex = 0;
                    radial.navCtrl.handleWheel(-120);
                    assertCondition("M4.RUN.12", "Wheel in root mode advances to category 1",
                        radial.focusedCategoryIndex === 1,
                        "focusedCategoryIndex=" + radial.focusedCategoryIndex);

                    // Scroll 8 more times (should wrap across all 9 categories: 1 -> 2 -> 3 -> 4 -> 5 -> 6 -> 7 -> 8 -> 0)
                    for (var w = 0; w < 8; ++w) {
                        radial.navCtrl.handleWheel(-120);
                    }
                    assertCondition("M4.RUN.13", "Wheel wraps cleanly across all 9 categories back to 0",
                        radial.focusedCategoryIndex === 0,
                        "focusedCategoryIndex=" + radial.focusedCategoryIndex);
                    root.step = 10;
                    break;

                case 10:
                    testRunner.running = false;
                    console.log("================================================================");
                    console.log("M4 RUNTIME TEST RESULTS: Passed=" + root.passCount + ", Failed=" + root.failCount);
                    if (root.failCount === 0 && root.passCount >= 14) {
                        console.log("=== PASS: ALL M4 RUNTIME NAVIGATION CHECKS SUCCESSFUL ===");
                    } else {
                        console.error("=== FAIL: M4 RUNTIME NAVIGATION CHECKS FAILED ===");
                    }
                    console.log("================================================================");
                    Qt.quit();
                    break;
                }
            } catch (err) {
                console.error("ASSERTION_FAILED: Exception in runtime step " + root.step + ": " + err);
                testRunner.running = false;
                Qt.quit();
            }
        }
    }
}
