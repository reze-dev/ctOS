pragma ComponentBehavior: Bound
import QtQuick
import "../../core"
import "RadialGeometry.js" as RadialGeometry

Item {
    id: root

    // =========================================================================
    // Properties
    // =========================================================================

    property var model: null
    property int focusedCategoryIndex: 0
    property string selectedNodeId: ""
    property bool isExpanded: false

    property real wheelCenterX: width / 2
    property real wheelCenterY: height / 2
    property real outerRadius: 210
    property real branchOriginX: 300
    property real branchOriginY: height / 2

    readonly property var rootNode: (root.model && root.model.categories[root.focusedCategoryIndex]?.nodes?.length > 0) ? root.model.categories[root.focusedCategoryIndex].nodes[0] : null

    // -------------------------------------------------------------------------
    // One topology, one layout, two renderings.
    // -------------------------------------------------------------------------

    readonly property string focusedCategoryId: (root.model && root.model.categories[root.focusedCategoryIndex]) ? root.model.categories[root.focusedCategoryIndex].id : ""

    // Roots to lay out: the category's declared tree, plus any model node the
    // topology does not declare.
    //
    // Those extras are the reason this is not just RadialTopology.treeFor(). A
    // node added to the model without a matching entry in the topology would
    // otherwise have no coordinates and silently disappear -- and the whole
    // promise of this file is that adding a node anywhere shows up. Parked as
    // extra roots, they land on the layout's orphan arc and stay visible.
    readonly property var categoryTree: {
        var declared = RadialTopology.treeFor(root.focusedCategoryId);
        var roots = (declared && declared.length > 0) ? declared.slice() : [];
        var known = RadialTopology.idsFor(root.focusedCategoryId);

        if (root.model) {
            var cat = root.model.getCategory(root.focusedCategoryIndex);
            if (cat && cat.nodes) {
                for (var i = 0; i < cat.nodes.length; ++i) {
                    if (known.indexOf(cat.nodes[i].id) < 0)
                        roots.push({ id: cat.nodes[i].id });
                }
            }
        }
        return roots;
    }

    // Step size for the expanded branch. 140 puts a four-deep tree (audio) inside
    // ~670px, which clears both the 1080px height and the ContextPanel edge; a
    // deeper category would want this smaller, not the algorithm changed.
    readonly property real expandedStep: 140.0

    readonly property var expandedLayout: RadialGeometry.layoutTree(
        root.categoryTree, { step: root.expandedStep, flatten: 0.15 })

    function posOf(nodeId: string): var {
        var p = root.expandedLayout[nodeId];
        return p ? p : { x: 0.0, y: 0.0, depth: 0, spoke: -1, parent: "" };
    }

    signal nodeSelected(string nodeId)
    signal nodeHovered(string nodeId)
    signal nodeActivated(string nodeId)

    // Track active nodes with calculated screen coordinates for spatial navigation
    readonly property var activeNodes: {
        if (!model || !isExpanded) return [];
        var cat = model.getCategory(focusedCategoryIndex);
        if (!cat || !cat.nodes) return [];
        var list = [];
        for (var i = 0; i < cat.nodes.length; ++i) {
            var n = cat.nodes[i];
            var p = root.posOf(n.id);
            list.push({
                id: n.id,
                title: n.title,
                subtitle: n.subtitle,
                icon: n.icon,
                locked: n.locked,
                lockReason: n.lockReason,
                controlType: n.controlType,
                pos: p,
                // The layout puts the root at (0,0), so there is no rootY to
                // subtract the way there was with hand-placed `pos` values.
                screenX: root.branchOriginX + p.x,
                screenY: root.branchOriginY + p.y
            });
        }
        return list;
    }

    // =========================================================================
    // 1. Preview Trees (Root Mode)
    // 8 Subtrees Radiating Outward Around Wheel
    // =========================================================================

    Item {
        id: previewTreesContainer
        anchors.fill: parent
        opacity: root.isExpanded ? 0.0 : 1.0
        visible: opacity > 0.01

        Behavior on opacity {
            NumberAnimation { duration: Settings.reducedMotion ? 0 : Theme.durationSlow; easing.type: Easing.OutCubic }
        }

        Repeater {
            model: root.model ? root.model.categoryCount : 0
            delegate: Item {
                id: previewSubtree
                required property int index
                readonly property int categoryIdx: previewSubtree.index
                // Referenced by onFocusedCategoryIndexChanged below.
                readonly property int focusedCategoryIndex: root.focusedCategoryIndex
                
                property real _lastTargetAngle: -90.0 + previewSubtree.index * (360.0 / Math.max(1, root.model ? root.model.categoryCount : 8))
                property var layoutInfo: RadialGeometry.getSegmentTargetLayout(
                    previewSubtree.index, 
                    root.focusedCategoryIndex, 
                    root.model ? Math.max(1, root.model.categoryCount) : 8, 
                    2.0, 
                    90.0, 
                    _lastTargetAngle
                )

                // Continuity hint for the shortest angular path. This used to
                // be written from onLayoutInfoChanged, which made layoutInfo
                // depend on a property its own change handler mutated -- a
                // binding loop that fired continuously on every load. Latch on
                // the category change instead, which is when the target
                // actually moves.
                onFocusedCategoryIndexChanged: {
                    if (layoutInfo && layoutInfo.centerAngle !== undefined) {
                        _lastTargetAngle = layoutInfo.centerAngle;
                    }
                }

                property real angleDeg: layoutInfo.centerAngle
                
                Behavior on angleDeg {
                    NumberAnimation { duration: Settings.reducedMotion ? 0 : Theme.durationSlow; easing.type: Easing.OutCubic }
                }
                readonly property real rad: previewSubtree.angleDeg * Math.PI / 180.0
                readonly property real radMinus12: (previewSubtree.angleDeg - 12.0) * Math.PI / 180.0

                readonly property bool isCatFocused: root.focusedCategoryIndex === previewSubtree.categoryIdx
                readonly property var cat: (root.model && root.model.categories[previewSubtree.categoryIdx]) ? root.model.categories[previewSubtree.categoryIdx] : null

                // Subtree polar anchor points (reactive trigonometric properties)
                readonly property var r0Point: ({ x: 150 * Math.cos(previewSubtree.rad), y: 150 * Math.sin(previewSubtree.rad) })

                // How far out the preview tree's base node sits. The wheel's
                // outerRadius is 180, so this is how much trunk shows before the
                // tree starts.
                //
                // Measured off the reference rather than guessed: its ring has an
                // outer radius of 119px, its tree roots sit at ~160, and its depth
                // step is 28. Scaled to our 180px ring that is 241 and 42, which
                // are the two numbers below.
                //
                // These were 320 and 48 before, and 320 in particular left a trunk
                // longer than the tree it introduced, so the branches read as
                // floating clear of the wheel.
                readonly property var r1Point: ({ x: 241 * Math.cos(previewSubtree.rad), y: 241 * Math.sin(previewSubtree.rad) })

                // Preview tree: the same layout the expanded branch draws,
                // projected small and rotated so it points outward from its own
                // segment.
                //
                // This replaces a rule that was entirely its own -- each child
                // offset by +/-8 degrees at a fixed radius, parented two slots
                // back. That packed a whole subtree into a 16-degree wedge, and
                // worse, it was free to disagree with the expanded view about how
                // many branches a category had. Nothing connected the two, which
                // is how the audio and security trees came to look different
                // depending on which view you were in.
                //
                // Step 42 against a 30px node is the reference's own ratio: its depth step is
                // 28px on a 119px ring, which scales to 42 here. The previous 48
                // was close but loose enough that the edges read as long lines
                // with a gap at each end rather than as a tree.
                //
                // The fan angles are deliberately the same as the expanded view's.
                // The reference's base trees are not a different *shape* -- their
                // forks are short perpendicular pairs because everything is small,
                // not because the geometry differs. Compressing it is a smaller
                // step, not a second set of angles.
                readonly property var previewChildren: {
                    var nodes = previewSubtree.cat && previewSubtree.cat.nodes ? previewSubtree.cat.nodes : [];
                    if (nodes.length === 0) return [];

                    var tree = RadialTopology.treeFor(previewSubtree.cat.id);
                    var known = RadialTopology.idsFor(previewSubtree.cat.id);
                    var roots = (tree && tree.length > 0) ? tree.slice() : [];
                    for (var w = 0; w < nodes.length; ++w)
                        if (known.indexOf(nodes[w].id) < 0)
                            roots.push({ id: nodes[w].id });

                    var small = RadialGeometry.layoutTree(roots, { step: 42.0, flatten: 0.15 });
                    var origin = previewSubtree.r1Point;
                    var slots = [];

                    for (var i = 1; i < nodes.length; ++i) {
                        var p = small[nodes[i].id];
                        if (!p || p.depth < 1) continue;
                        var parent = small[p.parent] ? small[p.parent] : { x: 0.0, y: 0.0 };
                        slots.push({
                            nodeIndex: i,
                            icon: nodes[i] ? nodes[i].icon : previewSubtree.cat.icon,
                            point: RadialGeometry.projectPoint(p, previewSubtree.angleDeg, 1.0, origin),
                            parentPoint: RadialGeometry.projectPoint(parent, previewSubtree.angleDeg, 1.0, origin)
                        });
                    }
                    return slots;
                }

                // Trunk edge
                SkillEdge {
                    x1: root.wheelCenterX
                    y1: root.wheelCenterY
                    x2: (root.wheelCenterX + previewSubtree.r1Point.x)
                    y2: (root.wheelCenterY + previewSubtree.r1Point.y)
                    node1Radius: root.outerRadius + 10
                    node2Radius: 15
                    isActive: previewSubtree.isCatFocused
                    isPreview: true
                }

                // Branch edges, one per generated child slot
                Repeater {
                    model: previewSubtree.previewChildren

                    delegate: SkillEdge {
                        required property var modelData
                        x1: root.wheelCenterX + modelData.parentPoint.x
                        y1: root.wheelCenterY + modelData.parentPoint.y
                        x2: root.wheelCenterX + modelData.point.x
                        y2: root.wheelCenterY + modelData.point.y
                        node1Radius: 10
                        node2Radius: 10
                        isActive: previewSubtree.isCatFocused
                        isPreview: true
                    }
                }

                // Root Preview Node
                SkillNode {
                    x: (root.wheelCenterX + previewSubtree.r1Point.x) - width / 2
                    y: (root.wheelCenterY + previewSubtree.r1Point.y) - height / 2
                    isPreview: true
                    isSelected: previewSubtree.isCatFocused
                    iconName: previewSubtree.cat ? previewSubtree.cat.icon : "gear"
                }

                // Child Preview Nodes
                Repeater {
                    model: previewSubtree.previewChildren

                    delegate: SkillNode {
                        required property var modelData
                        x: (root.wheelCenterX + modelData.point.x) - width / 2
                        y: (root.wheelCenterY + modelData.point.y) - height / 2
                        isPreview: true
                        isSelected: previewSubtree.isCatFocused
                        iconName: modelData.icon
                    }
                }
            }
        }
    }

    // =========================================================================
    // 2. Expanded Branch (Interactive Mode)
    // Cascading Horizontal Graph Extending From Left-Anchored Wheel
    // =========================================================================

    Item {
        id: expandedBranchContainer
        anchors.fill: parent
        opacity: root.isExpanded ? 1.0 : 0.0
        visible: opacity > 0.01

        // The layout puts the root at (0, 0), so there is no rootY offset to
        // apply. This used to read cat.nodes[0].pos.y and subtract it from every
        // node, which existed only because the old `pos` values were hand-placed
        // rather than computed from a known origin.
        readonly property real currentRootPosY: 0.0

        Behavior on opacity {
            NumberAnimation { duration: Settings.reducedMotion ? 0 : Theme.durationSlow; easing.type: Easing.OutCubic }
        }

        // Staggered cascade controller for nodes and connecting edges
        Item {
            id: cascadeController

            property real offset0: 0.0
            property real offset1: 0.0
            property real offset2: 0.0
            property real offset3: 0.0
            property real offset4: 0.0
            property real offset5: 0.0
            property real offset6: 0.0
            property real offset7: 0.0

            function getOffset(nodeIndex: int): real {
                if (nodeIndex === 0) return cascadeController.offset0;
                if (nodeIndex === 1) return cascadeController.offset1;
                if (nodeIndex === 2) return cascadeController.offset2;
                if (nodeIndex === 3) return cascadeController.offset3;
                if (nodeIndex === 4) return cascadeController.offset4;
                if (nodeIndex === 5) return cascadeController.offset5;
                if (nodeIndex === 6) return cascadeController.offset6;
                if (nodeIndex === 7) return cascadeController.offset7;
                return 0.0;
            }

            function restartCascade(): void {
                cascadeAnim0.restart();
                cascadeAnim1.restart();
                cascadeAnim2.restart();
                cascadeAnim3.restart();
                cascadeAnim4.restart();
                cascadeAnim5.restart();
                cascadeAnim6.restart();
                cascadeAnim7.restart();
            }

            NumberAnimation { id: cascadeAnim0; target: cascadeController; property: "offset0"; from: -30.0; to: 0.0; duration: Settings.reducedMotion ? 0 : Theme.durationSlow + 0; running: root.isExpanded; easing.type: Easing.OutBack }
            NumberAnimation { id: cascadeAnim1; target: cascadeController; property: "offset1"; from: -30.0; to: 0.0; duration: Settings.reducedMotion ? 0 : Theme.durationSlow + 60; running: root.isExpanded; easing.type: Easing.OutBack }
            NumberAnimation { id: cascadeAnim2; target: cascadeController; property: "offset2"; from: -30.0; to: 0.0; duration: Settings.reducedMotion ? 0 : Theme.durationSlow + 120; running: root.isExpanded; easing.type: Easing.OutBack }
            NumberAnimation { id: cascadeAnim3; target: cascadeController; property: "offset3"; from: -30.0; to: 0.0; duration: Settings.reducedMotion ? 0 : Theme.durationSlow + 180; running: root.isExpanded; easing.type: Easing.OutBack }
            NumberAnimation { id: cascadeAnim4; target: cascadeController; property: "offset4"; from: -30.0; to: 0.0; duration: Settings.reducedMotion ? 0 : Theme.durationSlow + 240; running: root.isExpanded; easing.type: Easing.OutBack }
            NumberAnimation { id: cascadeAnim5; target: cascadeController; property: "offset5"; from: -30.0; to: 0.0; duration: Settings.reducedMotion ? 0 : Theme.durationSlow + 300; running: root.isExpanded; easing.type: Easing.OutBack }
            NumberAnimation { id: cascadeAnim6; target: cascadeController; property: "offset6"; from: -30.0; to: 0.0; duration: Settings.reducedMotion ? 0 : Theme.durationSlow + 360; running: root.isExpanded; easing.type: Easing.OutBack }
            NumberAnimation { id: cascadeAnim7; target: cascadeController; property: "offset7"; from: -30.0; to: 0.0; duration: Settings.reducedMotion ? 0 : Theme.durationSlow + 420; running: root.isExpanded; easing.type: Easing.OutBack }
        }

        // Horizontal Anchor Ray from Wheel to Root Node
        SkillEdge {
            id: anchorRay
            x1: root.wheelCenterX
            y1: root.wheelCenterY
            x2: root.branchOriginX + (root.rootNode ? root.posOf(root.rootNode.id).x : 0) + cascadeController.offset0
            y2: root.wheelCenterY
            node1Radius: root.outerRadius + 10
            node2Radius: 16
            isActive: true
            isPreview: false
        }

        Connections {
            target: root
            function onIsExpandedChanged(): void {
                if (root.isExpanded) {
                    anchorRay.triggerPulse();
                    cascadeController.restartCascade();
                }
            }
            function onFocusedCategoryIndexChanged(): void {
                if (root.isExpanded) {
                    cascadeController.restartCascade();
                }
            }
            function onNodeSelected(nodeId): void {
                var cat = root.model ? root.model.getCategory(root.focusedCategoryIndex) : null;
                if (cat && cat.nodes && cat.nodes.length > 0 && cat.nodes[0].id === nodeId) {
                    anchorRay.triggerPulse();
                }
            }
        }

        // Inter-Node Edges
        //
        // Built by walking the layout rather than each node's `edges` list, so
        // the parent-child pairs here and the ones the preview draws are the same
        // pairs. Two lists that both claimed to describe the tree is how they came
        // to describe different ones.
        Repeater {
            id: edgesRepeater
            model: {
                if (!root.model || !root.isExpanded) return [];
                var cat = root.model.getCategory(root.focusedCategoryIndex);
                if (!cat || !cat.nodes) return [];

                var layout = root.expandedLayout;
                var edgesList = [];
                for (var i = 0; i < cat.nodes.length; ++i) {
                    var id = cat.nodes[i].id;
                    var p = layout[id];
                    if (!p || !p.parent) continue;

                    var parentPos = layout[p.parent];
                    if (!parentPos) continue;

                    var childIdx = -1;
                    for (var k = 0; k < cat.nodes.length; ++k) {
                        if (cat.nodes[k].id === id) { childIdx = k; break; }
                    }

                    edgesList.push({
                        parentId: p.parent,
                        childId: id,
                        parentIndex: -1,
                        childIndex: childIdx,
                        parentPosX: parentPos.x,
                        parentPosY: parentPos.y,
                        childPosX: p.x,
                        childPosY: p.y
                    });
                }
                return edgesList;
            }

            delegate: SkillEdge {
                id: edgeItem
                required property var modelData
                // The parent's stagger is keyed off the layout's depth rather
                // than the model's array index: the two orders differ (the
                // topology nests, the model lists flat), and keying off array
                // position made the cascade run in an order that had nothing to
                // do with how the tree reads.
                readonly property int parentIndex: root.expandedLayout[edgeItem.modelData.parentId]
                    ? root.expandedLayout[edgeItem.modelData.parentId].depth : 0
                x1: root.branchOriginX + edgeItem.modelData.parentPosX + cascadeController.getOffset(edgeItem.parentIndex)
                y1: root.branchOriginY + edgeItem.modelData.parentPosY - expandedBranchContainer.currentRootPosY
                x2: root.branchOriginX + edgeItem.modelData.childPosX + cascadeController.getOffset(edgeItem.modelData.childIndex)
                y2: root.branchOriginY + edgeItem.modelData.childPosY - expandedBranchContainer.currentRootPosY
                node1Radius: 16
                node2Radius: 16
                isActive: root.selectedNodeId === edgeItem.modelData.childId || root.selectedNodeId === edgeItem.modelData.parentId
                isPreview: false

                Connections {
                    target: root
                    function onNodeSelected(nodeId): void {
                        if (nodeId === edgeItem.modelData.childId) {
                            edgeItem.triggerPulse();
                        }
                    }
                }
            }
        }

        // Graph Nodes
        Repeater {
            id: nodesRepeater
            model: {
                if (!root.model || !root.isExpanded) return [];
                var cat = root.model.getCategory(root.focusedCategoryIndex);
                return (cat && cat.nodes) ? cat.nodes : [];
            }

            delegate: Item {
                id: nodeWrapper
                required property var modelData
                required property int index
                readonly property real cascadeOffset: cascadeController.getOffset(nodeWrapper.index)
                readonly property var pos: root.posOf(nodeWrapper.modelData.id)
                x: root.branchOriginX + nodeWrapper.pos.x - 24 + nodeWrapper.cascadeOffset
                y: root.branchOriginY + nodeWrapper.pos.y - expandedBranchContainer.currentRootPosY - 24
                width: 48
                height: 48

                SkillNode {
                    id: skillNode
                    anchors.centerIn: parent
                    nodeId: nodeWrapper.modelData.id
                    title: nodeWrapper.modelData.title
                    subtitle: nodeWrapper.modelData.subtitle
                    iconName: nodeWrapper.modelData.icon
                    locked: nodeWrapper.modelData.locked
                    controlType: nodeWrapper.modelData.controlType
                    isSelected: root.selectedNodeId === nodeWrapper.modelData.id
                    isActive: {
                        var _ = root.model ? root.model.revision : 0;
                        return typeof nodeWrapper.modelData.value === "function" && Boolean(nodeWrapper.modelData.value());
                    }

                    onClicked: {
                        root.nodeSelected(nodeWrapper.modelData.id);
                    }

                    onHovered: {
                        root.nodeHovered(nodeWrapper.modelData.id);
                    }
                }
            }
        }
    }
}
