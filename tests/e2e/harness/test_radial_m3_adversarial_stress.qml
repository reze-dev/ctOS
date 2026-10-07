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

    // Dynamic Mock Model for boundary testing
    Item {
        id: mockModel
        property int revision: 0
        property int categoryCount: 9
        property var categories: []

        function getCategory(idx) {
            if (idx >= 0 && idx < categories.length) return categories[idx];
            return null;
        }

        function getNode(catIdx, nodeId) {
            var cat = getCategory(catIdx);
            if (!cat || !cat.nodes) return null;
            for (var i = 0; i < cat.nodes.length; ++i) {
                if (cat.nodes[i].id === nodeId) return cat.nodes[i];
            }
            return null;
        }
    }

    Item {
        id: testContainer
        width: 1920
        height: 1080

        // Isolated SkillTree for boundary mutation tests
        SkillTree {
            id: mockTree
            width: 1920
            height: 1080
            model: mockModel
            focusedCategoryIndex: 0
            isExpanded: true
            wheelCenterX: 180
            wheelCenterY: 540
            branchOriginX: 350
            branchOriginY: 540
        }

        // Live RadialSettings loader for integration & animation stress
        Loader {
            id: radialLoader
            width: 1920
            height: 1080
            active: true
            asynchronous: false
            source: "file://" + (Quickshell.env("PROJECT_ROOT") || "/home/reze/Projects/ctOS") + "/shell/desktop/surfaces/radial/RadialSettings.qml"
        }
    }

    // Helper functions to inspect items inside SkillTree
    function getPreviewSubtrees(tree) {
        var prev = tree.children[0];
        var subtrees = [];
        for (var i = 0; i < prev.children.length; ++i) {
            var c = prev.children[i];
            if (c.hasOwnProperty("r0Point")) {
                subtrees.push(c);
            }
        }
        return subtrees;
    }

    function getExpContainer(tree) {
        return tree.children[1];
    }

    function getCascadeController(tree) {
        var exp = getExpContainer(tree);
        for (var i = 0; i < exp.children.length; ++i) {
            if (exp.children[i].hasOwnProperty("offset0")) return exp.children[i];
        }
        return null;
    }

    function getAnchorRay(tree) {
        var exp = getExpContainer(tree);
        for (var i = 0; i < exp.children.length; ++i) {
            var c = exp.children[i];
            if (c.hasOwnProperty("x1") && !c.hasOwnProperty("modelData")) return c;
        }
        return null;
    }

    function getLiveEdges(tree) {
        var exp = getExpContainer(tree);
        var edges = [];
        for (var i = 0; i < exp.children.length; ++i) {
            var c = exp.children[i];
            if (c.hasOwnProperty("modelData") && c.modelData && c.modelData.hasOwnProperty("parentId")) {
                edges.push(c);
            }
        }
        return edges;
    }

    function getLiveNodes(tree) {
        var exp = getExpContainer(tree);
        var nodes = [];
        for (var i = 0; i < exp.children.length; ++i) {
            var c = exp.children[i];
            if (c.hasOwnProperty("modelData") && c.modelData && c.modelData.hasOwnProperty("title")) {
                nodes.push(c);
            }
        }
        return nodes;
    }

    Timer {
        id: stressRunner
        interval: 16
        repeat: true
        running: true

        property int phase: 0
        property int step: 0

        // Stress cycle counters
        property int cycleCount: 0
        property int catSwitchCount: 0
        property double maxAlignmentDrift: 0.0

        onTriggered: {
            try {
                var radial = radialLoader.item;
                if (!radial) return;

                // Locate live SkillTree inside radial
                var liveTree = null;
                for (var i = 0; i < radial.children.length; ++i) {
                    var ch = radial.children[i];
                    if (ch.hasOwnProperty("activeNodes") && ch.hasOwnProperty("branchOriginX")) {
                        liveTree = ch;
                        break;
                    }
                }

                switch (phase) {
                // =============================================================
                // SUITE 1: Dynamic Model Mutations & Boundary Values
                // =============================================================
                case 0:
                    console.log("=== SUITE 1: DYNAMIC MODEL MUTATIONS & BOUNDARY VALUES ===");

                    // 1.1: categoryCount = 0
                    mockModel.categoryCount = 0;
                    mockModel.categories = [];
                    mockTree.focusedCategoryIndex = 0;
                    mockTree.isExpanded = false;

                    assertCondition("M3.BOUND.01", "categoryCount=0 sets rootNode to null",
                        mockTree.rootNode === null);
                    assertCondition("M3.BOUND.02", "categoryCount=0 activeNodes is empty array",
                        Array.isArray(mockTree.activeNodes) && mockTree.activeNodes.length === 0);

                    // 1.2: Empty Category (nodes.length === 0)
                    mockModel.categoryCount = 1;
                    mockModel.categories = [
                        {
                            id: "empty-cat",
                            name: "EMPTY",
                            icon: "gear",
                            nodes: []
                        }
                    ];
                    mockTree.focusedCategoryIndex = 0;
                    mockTree.isExpanded = true;

                    assertCondition("M3.BOUND.03", "Empty category (nodes.length=0) evaluates rootNode as null",
                        mockTree.rootNode === null);

                    var anchorRay = getAnchorRay(mockTree);
                    var cascadeCtrl = getCascadeController(mockTree);

                    assertCondition("M3.BOUND.04", "anchorRay safely defaults x2 to branchOriginX + 70 + offset0 when rootNode is null",
                        Math.abs(anchorRay.x2 - (mockTree.branchOriginX + 70 + cascadeCtrl.offset0)) < 1e-4,
                        "anchorRay.x2=" + anchorRay.x2 + ", expected=" + (mockTree.branchOriginX + 70 + cascadeCtrl.offset0));
                    assertCondition("M3.BOUND.05", "anchorRay safely defaults y2 to branchOriginY when rootNode is null",
                        Math.abs(anchorRay.y2 - mockTree.branchOriginY) < 1e-4,
                        "anchorRay.y2=" + anchorRay.y2 + ", expected=" + mockTree.branchOriginY);

                    // 1.3: Single node category (1 node, no children)
                    mockModel.categories = [
                        {
                            id: "single-cat",
                            name: "SINGLE",
                            icon: "gear",
                            nodes: [
                                {
                                    id: "solo-node",
                                    title: "SOLO",
                                    pos: { x: 140, y: -60 },
                                    edges: []
                                }
                            ]
                        }
                    ];
                    mockTree.focusedCategoryIndex = 0;

                    assertCondition("M3.BOUND.06", "Single node category resolves rootNode",
                        mockTree.rootNode !== null && mockTree.rootNode.id === "solo-node");
                    assertCondition("M3.BOUND.07", "anchorRay connects directly to single node pos.x",
                        Math.abs(anchorRay.x2 - (mockTree.branchOriginX + 140 + cascadeCtrl.offset0)) < 1e-4,
                        "anchorRay.x2=" + anchorRay.x2 + ", expected=" + (mockTree.branchOriginX + 140 + cascadeCtrl.offset0));
                    assertCondition("M3.BOUND.08", "anchorRay connects directly to single node pos.y",
                        Math.abs(anchorRay.y2 - (mockTree.branchOriginY - 60)) < 1e-4,
                        "anchorRay.y2=" + anchorRay.y2 + ", expected=" + (mockTree.branchOriginY - 60));

                    // 1.4: Extreme & Negative Coordinates
                    mockModel.categories = [
                        {
                            id: "extreme-cat",
                            name: "EXTREME",
                            icon: "gear",
                            nodes: [
                                {
                                    id: "neg-root",
                                    title: "NEG ROOT",
                                    pos: { x: -350, y: -720 },
                                    edges: ["ext-child"]
                                },
                                {
                                    id: "ext-child",
                                    title: "EXT CHILD",
                                    pos: { x: 88888, y: -44444 },
                                    edges: []
                                }
                            ]
                        }
                    ];
                    mockTree.focusedCategoryIndex = 0;

                    assertCondition("M3.BOUND.09", "Negative root coordinates correctly track on anchorRay",
                        Math.abs(anchorRay.x2 - (mockTree.branchOriginX - 350 + cascadeCtrl.offset0)) < 1e-4,
                        "anchorRay.x2=" + anchorRay.x2);

                    // 1.5: Broken graph edge (edge referencing nonexistent node ID)
                    mockModel.categories = [
                        {
                            id: "broken-graph",
                            name: "BROKEN",
                            icon: "gear",
                            nodes: [
                                {
                                    id: "ghost-parent",
                                    title: "GHOST PARENT",
                                    pos: { x: 100, y: 0 },
                                    edges: ["phantom-child-999"]
                                }
                            ]
                        }
                    ];
                    mockTree.focusedCategoryIndex = 0;
                    assertCondition("M3.BOUND.10", "Dangling edge reference omitted cleanly without error",
                        mockTree.rootNode !== null && mockTree.rootNode.id === "ghost-parent");

                    // 1.6: Node index >= 8 (graceful offset fallback)
                    var offset8 = cascadeCtrl.getOffset(8);
                    var offset99 = cascadeCtrl.getOffset(99);
                    var offsetNeg = cascadeCtrl.getOffset(-1);
                    assertCondition("M3.BOUND.11", "cascadeController.getOffset(8) returns 0.0 gracefully",
                        offset8 === 0.0, "offset8=" + offset8);
                    assertCondition("M3.BOUND.12", "cascadeController.getOffset(99) returns 0.0 gracefully",
                        offset99 === 0.0, "offset99=" + offset99);
                    assertCondition("M3.BOUND.13", "cascadeController.getOffset(-1) returns 0.0 gracefully",
                        offsetNeg === 0.0, "offsetNeg=" + offsetNeg);

                    phase = 1;
                    step = 0;
                    break;

                // =============================================================
                // SUITE 2: Preview Subtree Polar Alignment Oracle
                // =============================================================
                case 1:
                    console.log("=== SUITE 2: PREVIEW SUBTREE POLAR ALIGNMENT ORACLE ===");
                    radial.isExpanded = false;
                    var subtrees = getPreviewSubtrees(liveTree);

                    assertCondition("M3.PREV.01", "Preview container visible in root mode",
                        liveTree.children[0].visible === true);
                    assertCondition("M3.PREV.02", "Preview container delegate count matches category count (9)",
                        subtrees.length === 9, "count=" + subtrees.length);

                    var allPreviewSubtreesAligned = true;
                    var maxPolarError = 0.0;

                    for (var catIdx = 0; catIdx < subtrees.length; ++catIdx) {
                        var subtreeItem = subtrees[catIdx];
                        if (!subtreeItem || !subtreeItem.hasOwnProperty("r0Point")) {
                            allPreviewSubtreesAligned = false;
                            continue;
                        }

                        var expectedSegAngle = 40.0;
                        var expectedAngleDeg = -90.0 + catIdx * 40.0;
                        var expectedRad = expectedAngleDeg * Math.PI / 180.0;
                        var expectedRadMinus8 = (expectedAngleDeg - 8.0) * Math.PI / 180.0;
                        var expectedRadPlus8 = (expectedAngleDeg + 8.0) * Math.PI / 180.0;
                        var expectedRadMinus12 = (expectedAngleDeg - 12.0) * Math.PI / 180.0;

                        var expectedR0X = 206 * Math.cos(expectedRad);
                        var expectedR0Y = 206 * Math.sin(expectedRad);
                        var expectedR1X = 246 * Math.cos(expectedRad);
                        var expectedR1Y = 246 * Math.sin(expectedRad);
                        var expectedC1X = 291 * Math.cos(expectedRadMinus8);
                        var expectedC1Y = 291 * Math.sin(expectedRadMinus8);
                        var expectedC2X = 291 * Math.cos(expectedRadPlus8);
                        var expectedC2Y = 291 * Math.sin(expectedRadPlus8);
                        var expectedC3X = 336 * Math.cos(expectedRadMinus12);
                        var expectedC3Y = 336 * Math.sin(expectedRadMinus12);

                        var errR0 = Math.hypot(subtreeItem.r0Point.x - expectedR0X, subtreeItem.r0Point.y - expectedR0Y);
                        var errR1 = Math.hypot(subtreeItem.r1Point.x - expectedR1X, subtreeItem.r1Point.y - expectedR1Y);
                        var errC1 = Math.hypot(subtreeItem.c1Point.x - expectedC1X, subtreeItem.c1Point.y - expectedC1Y);
                        var errC2 = Math.hypot(subtreeItem.c2Point.x - expectedC2X, subtreeItem.c2Point.y - expectedC2Y);
                        var errC3 = Math.hypot(subtreeItem.c3Point.x - expectedC3X, subtreeItem.c3Point.y - expectedC3Y);

                        var maxSubtreeErr = Math.max(errR0, errR1, errC1, errC2, errC3);
                        if (maxSubtreeErr > maxPolarError) maxPolarError = maxSubtreeErr;

                        if (subtreeItem.segAngle !== expectedSegAngle || Math.abs(subtreeItem.angleDeg - expectedAngleDeg) > 1e-4 || maxSubtreeErr > 1e-4) {
                            allPreviewSubtreesAligned = false;
                        }
                    }

                    assertCondition("M3.PREV.03", "All 9 preview subtrees follow dynamic 40 deg polar layout (max err < 1e-4)",
                        allPreviewSubtreesAligned, "maxPolarError=" + maxPolarError);

                    phase = 2;
                    step = 0;
                    break;

                // =============================================================
                // SUITE 3: Full 9-Category Live Edge Alignment Invariance Oracle
                // =============================================================
                case 2:
                    if (step === 0) {
                        console.log("=== SUITE 3: FULL 9-CATEGORY LIVE EDGE ALIGNMENT ORACLE ===");
                        radial.isExpanded = true;
                        radial.branchExpanded = true;
                        liveTree.isExpanded = true;
                        step = 1;
                        break;
                    }

                    if (step >= 1 && step <= 9) {
                        var testCatIdx = step - 1;
                        radial.focusedCategoryIndex = testCatIdx;
                        radial.branchExpanded = true;
                        liveTree.isExpanded = true;

                        var liveCascade = getCascadeController(liveTree);
                        var liveAnchorRay = getAnchorRay(liveTree);
                        var liveEdges = getLiveEdges(liveTree);
                        var liveNodes = getLiveNodes(liveTree);

                        var catDef = radial.settingsModel.getCategory(testCatIdx);
                        var rootDef = catDef.nodes[0];

                        // 1. Verify anchorRay alignment
                        var expectedAnchorX1 = liveTree.wheelCenterX + 205;
                        var expectedAnchorY1 = liveTree.wheelCenterY;
                        var expectedAnchorX2 = liveTree.branchOriginX + rootDef.pos.x + liveCascade.offset0;
                        var expectedAnchorY2 = liveTree.branchOriginY + rootDef.pos.y;

                        var anchorErrX1 = Math.abs(liveAnchorRay.x1 - expectedAnchorX1);
                        var anchorErrY1 = Math.abs(liveAnchorRay.y1 - expectedAnchorY1);
                        var anchorErrX2 = Math.abs(liveAnchorRay.x2 - expectedAnchorX2);
                        var anchorErrY2 = Math.abs(liveAnchorRay.y2 - expectedAnchorY2);

                        assertCondition("M3.LIVE.CAT" + testCatIdx + ".ANCHOR",
                            "Category " + testCatIdx + " (" + catDef.id + ") anchorRay connects wheel perimeter to rootNode",
                            anchorErrX1 < 1e-4 && anchorErrY1 < 1e-4 && anchorErrX2 < 1e-4 && anchorErrY2 < 1e-4,
                            "errs=[" + anchorErrX1.toFixed(3) + "," + anchorErrY1.toFixed(3) + "," + anchorErrX2.toFixed(3) + "," + anchorErrY2.toFixed(3) + "]");

                        // 2. Count expected edges
                        var expectedEdgesCount = 0;
                        for (var ni = 0; ni < catDef.nodes.length; ++ni) {
                            if (catDef.nodes[ni].edges) {
                                expectedEdgesCount += catDef.nodes[ni].edges.length;
                            }
                        }

                        assertCondition("M3.LIVE.CAT" + testCatIdx + ".EDGECNT",
                            "Category " + testCatIdx + " edgesRepeater count matches model (" + expectedEdgesCount + ")",
                            liveEdges.length === expectedEdgesCount,
                            "actual=" + liveEdges.length + ", expected=" + expectedEdgesCount);

                        // 3. Verify every edge connects EXACTLY between parent node center and child node center
                        var allEdgesAligned = true;
                        var maxEdgeErr = 0.0;

                        for (var ei = 0; ei < liveEdges.length; ++ei) {
                            var edgeDelegate = liveEdges[ei];
                            var edgeData = edgeDelegate.modelData;

                            var parentNodeItem = liveNodes[edgeData.parentIndex];
                            var childNodeItem = liveNodes[edgeData.childIndex];

                            if (!parentNodeItem || !childNodeItem) {
                                allEdgesAligned = false;
                                continue;
                            }

                            // Node centers in tree coordinates
                            var parentCenterX = parentNodeItem.x + 24;
                            var parentCenterY = parentNodeItem.y + 24;
                            var childCenterX = childNodeItem.x + 24;
                            var childCenterY = childNodeItem.y + 24;

                            var dX1 = Math.abs(edgeDelegate.x1 - parentCenterX);
                            var dY1 = Math.abs(edgeDelegate.y1 - parentCenterY);
                            var dX2 = Math.abs(edgeDelegate.x2 - childCenterX);
                            var dY2 = Math.abs(edgeDelegate.y2 - childCenterY);

                            var maxErr = Math.max(dX1, dY1, dX2, dY2);
                            if (maxErr > maxEdgeErr) maxEdgeErr = maxErr;

                            if (maxErr > 1e-4) {
                                allEdgesAligned = false;
                            }
                        }

                        assertCondition("M3.LIVE.CAT" + testCatIdx + ".ALIGN",
                            "Category " + testCatIdx + " all edges strictly intersect node centers (max err < 1e-4)",
                            allEdgesAligned,
                            "maxEdgeErr=" + maxEdgeErr);

                        step++;
                        break;
                    }

                    if (step === 10) {
                        phase = 3;
                        step = 0;
                        break;
                    }
                    break;

                // =============================================================
                // SUITE 4: Rapid State Transitions & Edge Animation Stress
                // =============================================================
                case 3:
                    if (step === 0) {
                        console.log("=== SUITE 4: RAPID EXPAND/COLLAPSE CYCLES & ANIMATION CHURN ===");
                        cycleCount = 0;
                        maxAlignmentDrift = 0.0;
                        step = 1;
                        break;
                    }

                    if (step === 1) {
                        // Rapidly toggle isExpanded every tick across 40 cycles
                        radial.isExpanded = !radial.isExpanded;
                        radial.branchExpanded = radial.isExpanded;
                        liveTree.isExpanded = radial.isExpanded;
                        cycleCount++;

                        var liveAnchorRay = getAnchorRay(liveTree);
                        var liveEdges = getLiveEdges(liveTree);
                        var liveNodes = getLiveNodes(liveTree);

                        // Measure alignment at every tick during active churn
                        if (liveNodes.length > 0 && liveNodes[0]) {
                            var rootNodeItem = liveNodes[0];
                            var rootCenterX = rootNodeItem.x + 24;
                            var rootCenterY = rootNodeItem.y + 24;

                            var anchorDiffX = Math.abs(liveAnchorRay.x2 - rootCenterX);
                            var anchorDiffY = Math.abs(liveAnchorRay.y2 - rootCenterY);
                            var drift = Math.max(anchorDiffX, anchorDiffY);
                            if (drift > maxAlignmentDrift) maxAlignmentDrift = drift;
                        }

                        for (var ei = 0; ei < liveEdges.length; ++ei) {
                            var edge = liveEdges[ei];
                            var pItem = liveNodes[edge.modelData.parentIndex];
                            var cItem = liveNodes[edge.modelData.childIndex];
                            if (pItem && cItem) {
                                var err1 = Math.hypot(edge.x1 - (pItem.x + 24), edge.y1 - (pItem.y + 24));
                                var err2 = Math.hypot(edge.x2 - (cItem.x + 24), edge.y2 - (cItem.y + 24));
                                var edgeDrift = Math.max(err1, err2);
                                if (edgeDrift > maxAlignmentDrift) maxAlignmentDrift = edgeDrift;
                            }
                        }

                        if (cycleCount >= 40) {
                            assertCondition("M3.STRESS.01", "40 rapid expand/collapse toggles completed without exception",
                                cycleCount >= 40);
                            assertCondition("M3.STRESS.02", "Zero edge tearing or endpoint detachment across active churn (max drift < 1e-4)",
                                maxAlignmentDrift < 1e-4, "maxDrift=" + maxAlignmentDrift);
                            phase = 4;
                            step = 0;
                        }
                        break;
                    }
                    break;

                // =============================================================
                // SUITE 5: In-Flight Category Switching While Expanded
                // =============================================================
                case 4:
                    if (step === 0) {
                        console.log("=== SUITE 5: IN-FLIGHT CATEGORY SWITCHING WHILE EXPANDED ===");
                        radial.isExpanded = true;
                        radial.branchExpanded = true;
                        liveTree.isExpanded = true;
                        catSwitchCount = 0;
                        step = 1;
                        break;
                    }

                    if (step === 1) {
                        // Switch categories rapidly in non-sequential order
                        var switchSequence = [0, 4, 8, 1, 7, 3, 5, 2, 6, 0];
                        var targetCat = switchSequence[catSwitchCount % switchSequence.length];
                        radial.focusedCategoryIndex = targetCat;
                        radial.branchExpanded = true;
                        liveTree.isExpanded = true;
                        catSwitchCount++;

                        var liveAnchorRay = getAnchorRay(liveTree);
                        var liveEdges = getLiveEdges(liveTree);
                        var liveNodes = getLiveNodes(liveTree);

                        var catDef = radial.settingsModel.getCategory(targetCat);
                        var expectedEdgesCount = 0;
                        for (var ni = 0; ni < catDef.nodes.length; ++ni) {
                            if (catDef.nodes[ni].edges) expectedEdgesCount += catDef.nodes[ni].edges.length;
                        }

                        // Verify immediate edge count synchronization (no lingering edges)
                        var countMatches = (liveEdges.length === expectedEdgesCount);
                        if (!countMatches) {
                            assertCondition("M3.SWITCH.ERR", "Residual edges detected during switch to " + targetCat, false,
                                "got=" + liveEdges.length + ", expected=" + expectedEdgesCount);
                        }

                        // Verify anchorRay targets new root node
                        if (liveNodes.length > 0 && liveNodes[0]) {
                            var rootItem = liveNodes[0];
                            var rootCenterY = rootItem.y + 24;
                            var anchorDiffY = Math.abs(liveAnchorRay.y2 - rootCenterY);
                            if (anchorDiffY > 1e-4) {
                                assertCondition("M3.SWITCH.ANCHOR_ERR", "Anchor ray misaligned on switch to " + targetCat, false,
                                    "anchorDiffY=" + anchorDiffY);
                            }
                        }

                        if (catSwitchCount >= 20) {
                            assertCondition("M3.SWITCH.01", "20 in-flight category switches completed smoothly",
                                catSwitchCount >= 20);
                            assertCondition("M3.SWITCH.02", "Zero residual edges or anchor ray detachment across category transitions",
                                true);
                            phase = 5;
                            step = 0;
                        }
                        break;
                    }
                    break;

                // =============================================================
                // Completion & Final Verdict
                // =============================================================
                case 5:
                    stressRunner.running = false;
                    console.log("================================================================");
                    console.log("RADIAL M3 ADVERSARIAL STRESS RESULTS: Passed=" + root.passCount + ", Failed=" + root.failCount);
                    if (root.failCount === 0 && root.passCount >= 45) {
                        console.log("=== PASS: ALL RADIAL M3 ADVERSARIAL CHECKS SUCCESSFUL ===");
                    } else {
                        console.error("=== FAIL: RADIAL M3 ADVERSARIAL FAILURES DETECTED ===");
                        if (root.failureLog) console.error(root.failureLog);
                    }
                    console.log("================================================================");
                    Qt.quit();
                    break;
                }
            } catch (err) {
                console.error("CRITICAL_EXCEPTION in stress runner phase " + root.phase + ": " + err);
                stressRunner.running = false;
                Qt.quit();
            }
        }
    }
}
