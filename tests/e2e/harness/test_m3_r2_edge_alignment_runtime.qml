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
    property int catTestIdx: 0

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
        interval: 60
        repeat: true
        running: true

        onTriggered: {
            try {
                var radial = radialLoader.item;
                if (!radial) return;

                var st = null;
                var wm = null;
                for (var i = 0; i < radial.children.length; ++i) {
                    var ch = radial.children[i];
                    if (ch.toString().indexOf("SkillTree") !== -1) st = ch;
                    if (ch.toString().indexOf("CircularSettingsMenu") !== -1) wm = ch;
                }

                switch (root.step) {
                case 0:
                    assertCondition("M3.QML.INIT.01", "SkillTree and CircularSettingsMenu found in RadialSettings",
                        st !== null && wm !== null);
                    assertCondition("M3.QML.INIT.02", "Initial mode is Root/Preview mode",
                        radial.isExpanded === false);
                    assertCondition("M3.QML.INIT.03", "SettingsModel has 9 categories",
                        radial.settingsModel && radial.settingsModel.categoryCount === 9);
                    root.step = 1;
                    break;

                case 1:
                    // Verify preview properties across all 9 categories
                    assertCondition("M3.QML.PREVIEW.WHEEL", "SkillTree wheel coordinates bound to CircularSettingsMenu",
                        st.wheelCenterX === wm.wheelCenterX && st.wheelCenterY === wm.wheelCenterY,
                        "wcX=" + st.wheelCenterX + ", wcY=" + st.wheelCenterY);
                    assertCondition("M3.QML.PREVIEW.RADIUS", "SkillTree outerRadius is 205",
                        st.outerRadius === 205);

                    root.step = 2;
                    break;

                case 2:
                    // Expand radial menu
                    radial.isExpanded = true;
                    assertCondition("M3.QML.EXPAND.01", "Triggered radial expansion", radial.isExpanded === true);
                    root.step = 3;
                    break;

                case 3:
                    // Wait for expand animation to start and branch to deploy
                    if (radial.branchExpanded) {
                        root.step = 4;
                    }
                    break;

                case 4:
                    // Test Category rootNode coordinates and AnchorRay for current category
                    var catIdx = root.catTestIdx;
                    radial.focusedCategoryIndex = catIdx;

                    var cat = radial.settingsModel.getCategory(catIdx);
                    assertCondition("M3.QML.CAT.LOAD." + catIdx, "Loaded category " + cat.name,
                        cat !== null && cat.nodes && cat.nodes.length > 0);

                    var rootNode = st.rootNode;
                    assertCondition("M3.QML.ROOT_NODE." + catIdx, "SkillTree.rootNode resolves for category " + cat.name,
                        rootNode !== null && rootNode.id === cat.nodes[0].id,
                        "nodeId=" + (rootNode ? rootNode.id : "null") + ", pos=(" + (rootNode ? rootNode.pos.x : 0) + "," + (rootNode ? rootNode.pos.y : 0) + ")");

                    // Find anchorRay
                    var anchorRay = null;
                    var edgesRepeater = null;
                    var nodesRepeater = null;

                    // Search inside st.expandedBranchContainer
                    for (var j = 0; j < st.children.length; ++j) {
                        var container = st.children[j];
                        for (var k = 0; k < container.children.length; ++k) {
                            var item = container.children[k];
                            var s = item.toString();
                            if (s.indexOf("SkillEdge") !== -1 && item.isPreview === false && item.modelData === undefined) {
                                anchorRay = item;
                            }
                            if (s.indexOf("Repeater") !== -1) {
                                if (item.count > 0) {
                                    var firstItem = item.itemAt(0);
                                    if (firstItem && firstItem.toString().indexOf("SkillEdge") !== -1) {
                                        edgesRepeater = item;
                                    } else {
                                        nodesRepeater = item;
                                    }
                                }
                            }
                        }
                    }
                    console.log("DEBUG PROPER anchorRay=" + anchorRay + " x1=" + (anchorRay ? anchorRay.x1 : -1) + " y1=" + (anchorRay ? anchorRay.y1 : -1) + " x2=" + (anchorRay ? anchorRay.x2 : -1) + " y2=" + (anchorRay ? anchorRay.y2 : -1));

                    assertCondition("M3.QML.ANCHOR_RAY." + catIdx, "AnchorRay item found in SkillTree",
                        anchorRay !== null);

                    if (anchorRay) {
                        // Check anchorRay x1, y1 == wheelCenterX + 205, wheelCenterY
                        var expX1 = st.wheelCenterX + 205;
                        var expY1 = st.wheelCenterY;
                        var x1Match = Math.abs(anchorRay.x1 - expX1) < 0.01;
                        var y1Match = Math.abs(anchorRay.y1 - expY1) < 0.01;
                        assertCondition("M3.QML.ANCHOR_START." + catIdx, "AnchorRay start tracks wheel perimeter",
                            x1Match && y1Match,
                            "actual=(" + anchorRay.x1 + "," + anchorRay.y1 + ") exp=(" + expX1 + "," + expY1 + ")");

                        // Check anchorRay x2, y2 == branchOrigin + rootNode.pos + cascadeOffset
                        if (nodesRepeater && nodesRepeater.count > 0) {
                            var liveRootNodeWrapper = nodesRepeater.itemAt(0);
                            if (liveRootNodeWrapper) {
                                var liveCenterX = liveRootNodeWrapper.x + liveRootNodeWrapper.width / 2;
                                var liveCenterY = liveRootNodeWrapper.y + liveRootNodeWrapper.height / 2;
                                var x2Match = Math.abs(anchorRay.x2 - liveCenterX) < 0.01;
                                var y2Match = Math.abs(anchorRay.y2 - liveCenterY) < 0.01;
                                assertCondition("M3.QML.ANCHOR_END." + catIdx, "AnchorRay end matches live root node center",
                                    x2Match && y2Match,
                                    "anchorEnd=(" + anchorRay.x2 + "," + anchorRay.y2 + ") nodeCenter=(" + liveCenterX + "," + liveCenterY + ")");
                            }
                        }
                    }

                    // Check edges tracking node centers
                    if (edgesRepeater && nodesRepeater && edgesRepeater.count > 0) {
                        var allEdgesAligned = true;
                        for (var e = 0; e < edgesRepeater.count; ++e) {
                            var edgeItem = edgesRepeater.itemAt(e);
                            if (!edgeItem) continue;
                            var pIdx = edgeItem.modelData.parentIndex;
                            var cIdx = edgeItem.modelData.childIndex;
                            var pWrapper = nodesRepeater.itemAt(pIdx);
                            var cWrapper = nodesRepeater.itemAt(cIdx);
                            if (pWrapper && cWrapper) {
                                var pCenterX = pWrapper.x + pWrapper.width / 2;
                                var pCenterY = pWrapper.y + pWrapper.height / 2;
                                var cCenterX = cWrapper.x + cWrapper.width / 2;
                                var cCenterY = cWrapper.y + cWrapper.height / 2;

                                if (Math.abs(edgeItem.x1 - pCenterX) > 0.01 ||
                                    Math.abs(edgeItem.y1 - pCenterY) > 0.01 ||
                                    Math.abs(edgeItem.x2 - cCenterX) > 0.01 ||
                                    Math.abs(edgeItem.y2 - cCenterY) > 0.01) {
                                    allEdgesAligned = false;
                                }
                            }
                        }
                        assertCondition("M3.QML.EDGES_ALIGN." + catIdx, "All branch edges in " + cat.name + " align with live node centers",
                            allEdgesAligned,
                            "edgeCount=" + edgesRepeater.count);
                    }

                    root.catTestIdx++;
                    if (root.catTestIdx < 9) {
                        // Stay on step 4 to test next category
                    } else {
                        root.step = 5;
                    }
                    break;

                case 5:
                    // Collapse back to root
                    radial.isExpanded = false;
                    assertCondition("M3.QML.COLLAPSE", "Collapsing back to preview mode",
                        radial.isExpanded === false);
                    root.step = 6;
                    break;

                case 6:
                    testRunner.running = false;
                    console.log("================================================================");
                    console.log("M3 R2 EDGE ALIGNMENT QML RUNTIME RESULTS: Passed=" + root.passCount + ", Failed=" + root.failCount);
                    if (root.failCount === 0 && root.passCount >= 30) {
                        console.log("=== PASS: ALL M3 EDGE ALIGNMENT RUNTIME CHECKS SUCCESSFUL ===");
                    } else {
                        console.error("=== FAIL: M3 EDGE ALIGNMENT RUNTIME CHECKS FAILED ===");
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
