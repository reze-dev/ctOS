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

    property bool origFlowVisible: false

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
                    assertCondition("RADIAL.RUN.01", "RadialSettings component loaded successfully",
                        radial !== null && radialLoader.status === Loader.Ready);
                    root.step = 1;
                    break;

                case 1:
                    assertCondition("RADIAL.RUN.02", "Default focused category is SYSTEM (0)",
                        radial.focusedCategoryIndex === 0,
                        "focusedCategoryIndex=" + radial.focusedCategoryIndex);

                    assertCondition("RADIAL.RUN.03", "Default selected node is sys-core",
                        radial.selectedNodeId === "sys-core",
                        "selectedNodeId=" + radial.selectedNodeId);

                    assertCondition("RADIAL.RUN.04", "Default mode is ROOT_MENU (not expanded)",
                        radial.isExpanded === false);

                    root.step = 2;
                    break;

                case 2:
                    // Change category to NETWORK (index 3)
                    radial.focusedCategoryIndex = 3;

                    assertCondition("RADIAL.RUN.05", "Category switched to NETWORK (index 3)",
                        radial.focusedCategoryIndex === 3);

                    assertCondition("RADIAL.RUN.06", "Selected node updated to net-core on category switch",
                        radial.selectedNodeId === "net-core",
                        "selectedNodeId=" + radial.selectedNodeId);

                    root.step = 3;
                    break;

                case 3:
                    // Expand category
                    radial.isExpanded = true;

                    assertCondition("RADIAL.RUN.07", "isExpanded transitions to true",
                        radial.isExpanded === true);

                    root.step = 4;
                    break;

                case 4:
                    // Select child node net-flow
                    radial.selectedNodeId = "net-flow";

                    assertCondition("RADIAL.RUN.08", "Child node net-flow selected",
                        radial.selectedNodeId === "net-flow");

                    root.origFlowVisible = Settings.widgetNetworkFlowVisible;
                    root.step = 5;
                    break;

                case 5:
                    // Test interactive toggle mutation
                    Settings.widgetNetworkFlowVisible = !root.origFlowVisible;
                    assertCondition("RADIAL.RUN.09", "Settings state mutation verified",
                        Settings.widgetNetworkFlowVisible === !root.origFlowVisible);

                    // Restore original value
                    Settings.widgetNetworkFlowVisible = root.origFlowVisible;
                    Settings.save();

                    root.step = 6;
                    break;

                case 6:
                    // Test Slider NaN immunity: execute app-bar-height with no arguments
                    var origBarHeight = Settings.barHeight;
                    var appCat = radial.settingsModel.getCategory(1); // APPEARANCE
                    var barNode = radial.settingsModel.getNode(1, "app-bar-height");
                    assertCondition("RADIAL.SLIDER.01", "app-bar-height node retrieved", barNode !== null);

                    // Call execute() with no args (simulating Enter key)
                    barNode.execute();
                    assertCondition("RADIAL.SLIDER.02", "barHeight remains a valid finite number and NOT NaN",
                        typeof Settings.barHeight === "number" && !isNaN(Settings.barHeight) &&
                        Settings.barHeight >= 28 && Settings.barHeight <= 48,
                        "barHeight=" + Settings.barHeight);

                    // Restore original bar height
                    Settings.barHeight = origBarHeight;
                    Settings.save();

                    root.step = 7;
                    break;

                case 7:
                    // Test Mouse boundary guard in expanded mode:
                    // When cursor is inside ContextPanel area (x=1600, y=400), tree node selection must NOT change!
                    radial.selectedNodeId = "net-core";
                    radial.navCtrl.handleMouseMove(1600, 400);

                    assertCondition("RADIAL.HOVER.01", "Cursor inside ContextPanel zone does not hijack selected node",
                        radial.selectedNodeId === "net-core",
                        "selectedNodeId=" + radial.selectedNodeId);

                    root.step = 8;
                    break;

                case 8:
                    // Test Keyboard category cycling in expanded mode (Tab advances category)
                    var prevCatIdx = radial.focusedCategoryIndex;
                    var handledTab = radial.navCtrl.handleKeyPress(Qt.Key_Tab);
                    assertCondition("RADIAL.KEY.01", "Tab key advances category in expanded mode",
                        handledTab && radial.focusedCategoryIndex === (prevCatIdx + 1) % 8,
                        "focusedCategoryIndex=" + radial.focusedCategoryIndex);

                    root.step = 9;
                    break;

                case 9:
                    // Test Keyboard Left arrow on root node collapses to wheel menu
                    var curCat = radial.settingsModel.getCategory(radial.focusedCategoryIndex);
                    radial.selectedNodeId = curCat.nodes[0].id;
                    var handledLeft = radial.navCtrl.handleKeyPress(Qt.Key_Left);

                    assertCondition("RADIAL.KEY.02", "Left arrow at root node requests collapse",
                        handledLeft);

                    root.step = 10;
                    break;

                case 10:
                    // Collapse back to ROOT_MENU
                    radial.isExpanded = false;

                    assertCondition("RADIAL.RUN.10", "isExpanded collapses cleanly to false",
                        radial.isExpanded === false);

                    root.step = 11;
                    break;

                case 11:
                    testRunner.running = false;
                    console.log("================================================================");
                    console.log("RADIAL SETTINGS RUNTIME RESULTS: Passed=" + root.passCount + ", Failed=" + root.failCount);
                    if (root.failCount === 0 && root.passCount >= 15) {
                        console.log("=== PASS: ALL RADIAL SETTINGS RUNTIME CHECKS SUCCESSFUL ===");
                    } else {
                        console.error("=== FAIL: RADIAL SETTINGS RUNTIME HARNESS FAILED ===");
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
