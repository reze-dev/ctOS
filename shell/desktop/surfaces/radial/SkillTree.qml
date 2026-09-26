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
    property real branchOriginX: 300
    property real branchOriginY: height / 2

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
                readonly property real angleDeg: -90.0 + previewSubtree.categoryIdx * (360.0 / (root.model ? root.model.categoryCount : 8))
                readonly property bool isCatFocused: root.focusedCategoryIndex === previewSubtree.categoryIdx
                readonly property var cat: (root.model && root.model.categories[previewSubtree.categoryIdx]) ? root.model.categories[previewSubtree.categoryIdx] : null

                // Subtree polar anchor points
                property var r0Point: ({x: 0, y: 0})
                property var r1Point: ({x: 0, y: 0})
                property var c1Point: ({x: 0, y: 0})
                property var c2Point: ({x: 0, y: 0})
                property var c3Point: ({x: 0, y: 0})

                Component.onCompleted: {
                    var a = previewSubtree.angleDeg;
                    r0Point = RadialGeometry.pointOnCircle(0, 0, 206, a);
                    r1Point = RadialGeometry.pointOnCircle(0, 0, 246, a);
                    c1Point = RadialGeometry.pointOnCircle(0, 0, 291, a - 8.0);
                    c2Point = RadialGeometry.pointOnCircle(0, 0, 291, a + 8.0);
                    c3Point = RadialGeometry.pointOnCircle(0, 0, 336, a - 12.0);
                }

                // Trunk edge
                SkillEdge {
                    x1: (root.wheelCenterX + previewSubtree.r0Point.x)
                    y1: (root.wheelCenterY + previewSubtree.r0Point.y)
                    x2: (root.wheelCenterX + previewSubtree.r1Point.x)
                    y2: (root.wheelCenterY + previewSubtree.r1Point.y)
                    isActive: previewSubtree.isCatFocused
                    isPreview: true
                }

                // Branch edge 1
                SkillEdge {
                    x1: (root.wheelCenterX + previewSubtree.r1Point.x)
                    y1: (root.wheelCenterY + previewSubtree.r1Point.y)
                    x2: (root.wheelCenterX + previewSubtree.c1Point.x)
                    y2: (root.wheelCenterY + previewSubtree.c1Point.y)
                    isActive: previewSubtree.isCatFocused
                    isPreview: true
                }

                // Branch edge 2
                SkillEdge {
                    x1: (root.wheelCenterX + previewSubtree.r1Point.x)
                    y1: (root.wheelCenterY + previewSubtree.r1Point.y)
                    x2: (root.wheelCenterX + previewSubtree.c2Point.x)
                    y2: (root.wheelCenterY + previewSubtree.c2Point.y)
                    isActive: previewSubtree.isCatFocused
                    isPreview: true
                }

                // Branch edge 3 (Leaf extension)
                SkillEdge {
                    x1: (root.wheelCenterX + previewSubtree.c1Point.x)
                    y1: (root.wheelCenterY + previewSubtree.c1Point.y)
                    x2: (root.wheelCenterX + previewSubtree.c3Point.x)
                    y2: (root.wheelCenterY + previewSubtree.c3Point.y)
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

        // Horizontal Anchor Ray from Wheel to Root Node
        SkillEdge {
            id: anchorRay
            x1: root.branchOriginX
            y1: root.branchOriginY
            x2: root.branchOriginX + 70
            y2: root.branchOriginY
            isActive: true
            isPreview: false
        }

        Connections {
            target: root
            function onIsExpandedChanged(): void {
                if (root.isExpanded) {
                    anchorRay.triggerPulse();
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
                            edgesList.push({
                                parentId: parentNode.id,
                                childId: childId,
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
                x1: edgeItem.modelData.x1
                y1: edgeItem.modelData.y1
                x2: edgeItem.modelData.x2
                y2: edgeItem.modelData.y2
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
                x: root.branchOriginX + nodeWrapper.modelData.pos.x - 24 + cascadeOffset.offset
                y: root.branchOriginY + nodeWrapper.modelData.pos.y - 24
                width: 48
                height: 48

                // Staggered cascade entrance on branch expansion
                QtObject {
                    id: cascadeOffset
                    property real offset: 0.0
                }

                NumberAnimation {
                    target: cascadeOffset
                    property: "offset"
                    from: -30.0
                    to: 0.0
                    duration: Theme.durationSlow + (nodeWrapper.index * 60)
                    running: root.isExpanded
                    easing.type: Easing.OutBack
                }

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
