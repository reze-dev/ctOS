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
            list.push({
                id: n.id,
                title: n.title,
                subtitle: n.subtitle,
                icon: n.icon,
                locked: n.locked,
                lockReason: n.lockReason,
                controlType: n.controlType,
                pos: n.pos,
                screenX: root.branchOriginX + n.pos.x,
                screenY: root.branchOriginY + n.pos.y
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
            NumberAnimation { duration: Theme.durationSlow; easing.type: Easing.OutCubic }
        }

        Repeater {
            model: root.model ? root.model.categoryCount : 0
            delegate: Item {
                id: previewSubtree
                required property int index
                readonly property int categoryIdx: previewSubtree.index
                
                property real _lastTargetAngle: -90.0 + previewSubtree.index * (360.0 / Math.max(1, root.model ? root.model.categoryCount : 8))
                property var layoutInfo: RadialGeometry.getSegmentTargetLayout(
                    previewSubtree.index, 
                    root.focusedCategoryIndex, 
                    root.model ? Math.max(1, root.model.categoryCount) : 8, 
                    2.0, 
                    90.0, 
                    _lastTargetAngle
                )

                onLayoutInfoChanged: {
                    if (layoutInfo && layoutInfo.centerAngle !== undefined) {
                        _lastTargetAngle = layoutInfo.centerAngle;
                    }
                }

                property real angleDeg: layoutInfo.centerAngle
                
                Behavior on angleDeg {
                    NumberAnimation { duration: Theme.durationSlow; easing.type: Easing.OutCubic }
                }
                readonly property real rad: previewSubtree.angleDeg * Math.PI / 180.0
                readonly property real radMinus8: (previewSubtree.angleDeg - 8.0) * Math.PI / 180.0
                readonly property real radPlus8: (previewSubtree.angleDeg + 8.0) * Math.PI / 180.0
                readonly property real radMinus12: (previewSubtree.angleDeg - 12.0) * Math.PI / 180.0

                readonly property bool isCatFocused: root.focusedCategoryIndex === previewSubtree.categoryIdx
                readonly property var cat: (root.model && root.model.categories[previewSubtree.categoryIdx]) ? root.model.categories[previewSubtree.categoryIdx] : null

                // Subtree polar anchor points (reactive trigonometric properties)
                readonly property var r0Point: ({ x: 150 * Math.cos(previewSubtree.rad), y: 150 * Math.sin(previewSubtree.rad) })
                readonly property var r1Point: ({ x: 320 * Math.cos(previewSubtree.rad), y: 320 * Math.sin(previewSubtree.rad) })
                readonly property var c1Point: ({ x: 380 * Math.cos(previewSubtree.radMinus8), y: 380 * Math.sin(previewSubtree.radMinus8) })
                readonly property var c2Point: ({ x: 380 * Math.cos(previewSubtree.radPlus8), y: 380 * Math.sin(previewSubtree.radPlus8) })
                readonly property var c3Point: ({ x: 440 * Math.cos(previewSubtree.radMinus12), y: 440 * Math.sin(previewSubtree.radMinus12) })

                // Trunk edge
                SkillEdge {
                    x1: root.wheelCenterX
                    y1: root.wheelCenterY
                    x2: (root.wheelCenterX + previewSubtree.r1Point.x)
                    y2: (root.wheelCenterY + previewSubtree.r1Point.y)
                    node1Radius: root.outerRadius + 15
                    node2Radius: 15
                    isActive: previewSubtree.isCatFocused
                    isPreview: true
                }

                // Branch edge 1
                SkillEdge {
                    x1: (root.wheelCenterX + previewSubtree.r1Point.x)
                    y1: (root.wheelCenterY + previewSubtree.r1Point.y)
                    x2: (root.wheelCenterX + previewSubtree.c1Point.x)
                    y2: (root.wheelCenterY + previewSubtree.c1Point.y)
                    node1Radius: 10
                    node2Radius: 10
                    isActive: previewSubtree.isCatFocused
                    isPreview: true
                }

                // Branch edge 2
                SkillEdge {
                    x1: (root.wheelCenterX + previewSubtree.r1Point.x)
                    y1: (root.wheelCenterY + previewSubtree.r1Point.y)
                    x2: (root.wheelCenterX + previewSubtree.c2Point.x)
                    y2: (root.wheelCenterY + previewSubtree.c2Point.y)
                    node1Radius: 10
                    node2Radius: 10
                    isActive: previewSubtree.isCatFocused
                    isPreview: true
                }

                // Branch edge 3 (Leaf extension)
                SkillEdge {
                    x1: (root.wheelCenterX + previewSubtree.c1Point.x)
                    y1: (root.wheelCenterY + previewSubtree.c1Point.y)
                    x2: (root.wheelCenterX + previewSubtree.c3Point.x)
                    y2: (root.wheelCenterY + previewSubtree.c3Point.y)
                    node1Radius: 10
                    node2Radius: 10
                    isActive: previewSubtree.isCatFocused
                    isPreview: true
                }

                // Root Preview Node
                SkillNode {
                    x: (root.wheelCenterX + previewSubtree.r1Point.x) - width / 2
                    y: (root.wheelCenterY + previewSubtree.r1Point.y) - height / 2
                    isPreview: true
                    isSelected: previewSubtree.isCatFocused
                    iconName: previewSubtree.cat ? previewSubtree.cat.icon : "gear"
                }

                // Child Preview Node 1
                SkillNode {
                    x: (root.wheelCenterX + previewSubtree.c1Point.x) - width / 2
                    y: (root.wheelCenterY + previewSubtree.c1Point.y) - height / 2
                    isPreview: true
                    isSelected: previewSubtree.isCatFocused
                    iconName: (previewSubtree.cat && previewSubtree.cat.nodes && previewSubtree.cat.nodes[1]) ? previewSubtree.cat.nodes[1].icon : (previewSubtree.cat ? previewSubtree.cat.icon : "gear")
                }

                // Child Preview Node 2
                SkillNode {
                    x: (root.wheelCenterX + previewSubtree.c2Point.x) - width / 2
                    y: (root.wheelCenterY + previewSubtree.c2Point.y) - height / 2
                    isPreview: true
                    isSelected: previewSubtree.isCatFocused
                    iconName: (previewSubtree.cat && previewSubtree.cat.nodes && previewSubtree.cat.nodes[2]) ? previewSubtree.cat.nodes[2].icon : (previewSubtree.cat ? previewSubtree.cat.icon : "gear")
                }

                // Child Preview Node 3
                SkillNode {
                    x: (root.wheelCenterX + previewSubtree.c3Point.x) - width / 2
                    y: (root.wheelCenterY + previewSubtree.c3Point.y) - height / 2
                    isPreview: true
                    isSelected: previewSubtree.isCatFocused
                    iconName: (previewSubtree.cat && previewSubtree.cat.nodes && previewSubtree.cat.nodes[3]) ? previewSubtree.cat.nodes[3].icon : (previewSubtree.cat ? previewSubtree.cat.icon : "gear")
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

        Behavior on opacity {
            NumberAnimation { duration: Theme.durationSlow; easing.type: Easing.OutCubic }
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

            NumberAnimation { id: cascadeAnim0; target: cascadeController; property: "offset0"; from: -30.0; to: 0.0; duration: Theme.durationSlow + 0; running: root.isExpanded; easing.type: Easing.OutBack }
            NumberAnimation { id: cascadeAnim1; target: cascadeController; property: "offset1"; from: -30.0; to: 0.0; duration: Theme.durationSlow + 60; running: root.isExpanded; easing.type: Easing.OutBack }
            NumberAnimation { id: cascadeAnim2; target: cascadeController; property: "offset2"; from: -30.0; to: 0.0; duration: Theme.durationSlow + 120; running: root.isExpanded; easing.type: Easing.OutBack }
            NumberAnimation { id: cascadeAnim3; target: cascadeController; property: "offset3"; from: -30.0; to: 0.0; duration: Theme.durationSlow + 180; running: root.isExpanded; easing.type: Easing.OutBack }
            NumberAnimation { id: cascadeAnim4; target: cascadeController; property: "offset4"; from: -30.0; to: 0.0; duration: Theme.durationSlow + 240; running: root.isExpanded; easing.type: Easing.OutBack }
            NumberAnimation { id: cascadeAnim5; target: cascadeController; property: "offset5"; from: -30.0; to: 0.0; duration: Theme.durationSlow + 300; running: root.isExpanded; easing.type: Easing.OutBack }
            NumberAnimation { id: cascadeAnim6; target: cascadeController; property: "offset6"; from: -30.0; to: 0.0; duration: Theme.durationSlow + 360; running: root.isExpanded; easing.type: Easing.OutBack }
            NumberAnimation { id: cascadeAnim7; target: cascadeController; property: "offset7"; from: -30.0; to: 0.0; duration: Theme.durationSlow + 420; running: root.isExpanded; easing.type: Easing.OutBack }
        }

        // Horizontal Anchor Ray from Wheel to Root Node
        SkillEdge {
            id: anchorRay
            x1: root.wheelCenterX
            y1: root.wheelCenterY
            x2: root.branchOriginX + (root.rootNode ? root.rootNode.pos.x : 70) + cascadeController.offset0
            y2: root.branchOriginY + (root.rootNode ? root.rootNode.pos.y : 0)
            node1Radius: 225
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
        Repeater {
            id: edgesRepeater
            model: {
                if (!root.model || !root.isExpanded) return [];
                var cat = root.model.getCategory(root.focusedCategoryIndex);
                if (!cat || !cat.nodes) return [];
                var edgesList = [];
                for (var i = 0; i < cat.nodes.length; ++i) {
                    var parentNode = cat.nodes[i];
                    if (!parentNode.edges) continue;
                    for (var j = 0; j < parentNode.edges.length; ++j) {
                        var childId = parentNode.edges[j];
                        var childNode = root.model.getNode(root.focusedCategoryIndex, childId);
                        if (childNode) {
                            var childIdx = -1;
                            for (var k = 0; k < cat.nodes.length; ++k) {
                                if (cat.nodes[k].id === childId) {
                                    childIdx = k;
                                    break;
                                }
                            }
                            edgesList.push({
                                parentId: parentNode.id,
                                childId: childId,
                                parentIndex: i,
                                childIndex: childIdx,
                                parentPosX: parentNode.pos.x,
                                parentPosY: parentNode.pos.y,
                                childPosX: childNode.pos.x,
                                childPosY: childNode.pos.y,
                                x1: root.branchOriginX + parentNode.pos.x,
                                y1: root.branchOriginY + parentNode.pos.y,
                                x2: root.branchOriginX + childNode.pos.x,
                                y2: root.branchOriginY + childNode.pos.y
                            });
                        }
                    }
                }
                return edgesList;
            }

            delegate: SkillEdge {
                id: edgeItem
                required property var modelData
                x1: root.branchOriginX + edgeItem.modelData.parentPosX + cascadeController.getOffset(edgeItem.modelData.parentIndex)
                y1: root.branchOriginY + edgeItem.modelData.parentPosY
                x2: root.branchOriginX + edgeItem.modelData.childPosX + cascadeController.getOffset(edgeItem.modelData.childIndex)
                y2: root.branchOriginY + edgeItem.modelData.childPosY
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
                x: root.branchOriginX + nodeWrapper.modelData.pos.x - 24 + nodeWrapper.cascadeOffset
                y: root.branchOriginY + nodeWrapper.modelData.pos.y - 24
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
                    isSelected: root.selectedNodeId === nodeWrapper.modelData.id
                    isActive: {
                        var _ = root.model ? root.model.revision : 0;
                        return typeof nodeWrapper.modelData.value === "function" && Boolean(nodeWrapper.modelData.value());
                    }

                    onClicked: {
                        root.selectedNodeId = nodeWrapper.modelData.id;
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
