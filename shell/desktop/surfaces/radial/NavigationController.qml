pragma ComponentBehavior: Bound
import QtQuick
import "RadialGeometry.js" as RadialGeometry

Item {
    id: root

    // =========================================================================
    // Properties
    // =========================================================================

    property int focusedCategoryIndex: 0
    property string selectedNodeId: ""
    property bool isExpanded: false

    property real wheelCenterX: 0
    property real wheelCenterY: 0
    property real wheelRotation: 0.0
    property real surfaceWidth: 1920
    property real surfaceHeight: 1080
    property var activeNodes: []
    property int categoryCount: 8

    property real innerDeadZone: 45.0
    property real outerMaxRadius: 360.0

    // Signals
    signal categoryChanged(int newIndex)
    signal nodeChanged(string newNodeId)
    signal expandRequested()
    signal collapseRequested()
    signal dismissRequested()
    signal activateRequested()

    // Spatial Mouse Movement Handler
    function handleMouseMove(mouseX: real, mouseY: real): void {
        if (!root.isExpanded) {
            var dist = RadialGeometry.distance(root.wheelCenterX, root.wheelCenterY, mouseX, mouseY);
            // Ignore if inside dead-center hub or far outside the wheel
            if (dist < root.innerDeadZone || dist > root.outerMaxRadius) {
                return;
            }

            var angle = RadialGeometry.angleFromCenter(root.wheelCenterX, root.wheelCenterY, mouseX, mouseY);
            var bestIdx = RadialGeometry.findClosestSegment(angle, root.categoryCount, root.focusedCategoryIndex, 4.0);
            if (bestIdx !== root.focusedCategoryIndex) {
                root.focusedCategoryIndex = bestIdx;
                root.categoryChanged(bestIdx);
            }
        } else {
            // In expanded mode, constrain hover to tree zone so moving towards ContextPanel or wheel doesn't jump nodes
            var treeMinX = root.wheelCenterX + 120.0;
            var treeMaxX = Math.max(treeMinX + 100.0, root.surfaceWidth - 480.0);

            if (mouseX < treeMinX || mouseX > treeMaxX || mouseY < 50.0 || mouseY > root.surfaceHeight - 40.0) {
                return;
            }

            if (!root.activeNodes || root.activeNodes.length === 0) return;
            var bestNode = RadialGeometry.findClosestNode(mouseX, mouseY, root.activeNodes, root.selectedNodeId, 25.0);
            if (bestNode && bestNode.id && bestNode.id !== root.selectedNodeId) {
                var d = RadialGeometry.distance(mouseX, mouseY, bestNode.screenX, bestNode.screenY);
                if (d < 160.0) {
                    root.selectedNodeId = bestNode.id;
                    root.nodeChanged(bestNode.id);
                }
            }
        }
    }

    // Mouse Wheel Handler
    function handleWheel(angleDeltaY: int): void {
        if (!root.isExpanded) {
            if (angleDeltaY > 0) {
                // Scroll up -> counter-clockwise
                var prevIdx = (root.focusedCategoryIndex - 1 + root.categoryCount) % root.categoryCount;
                root.focusedCategoryIndex = prevIdx;
                root.categoryChanged(prevIdx);
            } else if (angleDeltaY < 0) {
                // Scroll down -> clockwise
                var nextIdx = (root.focusedCategoryIndex + 1) % root.categoryCount;
                root.focusedCategoryIndex = nextIdx;
                root.categoryChanged(nextIdx);
            }
        } else {
            if (!root.activeNodes || root.activeNodes.length === 0) return;
            var curIdx = 0;
            for (var i = 0; i < root.activeNodes.length; ++i) {
                if (root.activeNodes[i].id === root.selectedNodeId) {
                    curIdx = i;
                    break;
                }
            }
            if (angleDeltaY > 0) {
                var pIdx = (curIdx - 1 + root.activeNodes.length) % root.activeNodes.length;
                root.selectedNodeId = root.activeNodes[pIdx].id;
                root.nodeChanged(root.selectedNodeId);
            } else if (angleDeltaY < 0) {
                var nIdx = (curIdx + 1) % root.activeNodes.length;
                root.selectedNodeId = root.activeNodes[nIdx].id;
                root.nodeChanged(root.selectedNodeId);
            }
        }
    }

    // Keyboard Key Press Handler
    function handleKeyPress(key: int): bool {
        // Dismissal / Back navigation
        if (key === Qt.Key_Escape) {
            if (root.isExpanded) {
                root.collapseRequested();
                return true;
            } else {
                root.dismissRequested();
                return true;
            }
        }

        if (key === Qt.Key_Backspace && root.isExpanded) {
            root.collapseRequested();
            return true;
        }

        // Activation / Expansion
        if (key === Qt.Key_Return || key === Qt.Key_Enter || key === Qt.Key_Space) {
            if (!root.isExpanded) {
                root.expandRequested();
                return true;
            } else {
                root.activateRequested();
                return true;
            }
        }

        // Spatial Direction Traversal
        if (!root.isExpanded) {
            // Root Wheel Navigation
            if (key === Qt.Key_Up || key === Qt.Key_W) {
                root.focusedCategoryIndex = 0; // SYSTEM (12 o'clock)
                root.categoryChanged(0);
                return true;
            } else if (key === Qt.Key_Right || key === Qt.Key_D) {
                var next = (root.focusedCategoryIndex + 1) % root.categoryCount;
                root.focusedCategoryIndex = next;
                root.categoryChanged(next);
                return true;
            } else if (key === Qt.Key_Down || key === Qt.Key_S) {
                root.focusedCategoryIndex = 4; // AUDIO (6 o'clock)
                root.categoryChanged(4);
                return true;
            } else if (key === Qt.Key_Left || key === Qt.Key_A) {
                var prev = (root.focusedCategoryIndex - 1 + root.categoryCount) % root.categoryCount;
                root.focusedCategoryIndex = prev;
                root.categoryChanged(prev);
                return true;
            }
        } else {
            // Category cycling in expanded mode
            if (key === Qt.Key_Tab || key === Qt.Key_PageDown || key === Qt.Key_BracketRight) {
                var nextCat = (root.focusedCategoryIndex + 1) % root.categoryCount;
                root.focusedCategoryIndex = nextCat;
                root.categoryChanged(nextCat);
                return true;
            } else if (key === Qt.Key_Backtab || key === Qt.Key_PageUp || key === Qt.Key_BracketLeft) {
                var prevCat = (root.focusedCategoryIndex - 1 + root.categoryCount) % root.categoryCount;
                root.focusedCategoryIndex = prevCat;
                root.categoryChanged(prevCat);
                return true;
            }

            // Expanded Branch Graph Directional Traversal
            var dir = -1;
            if (key === Qt.Key_Up || key === Qt.Key_W) dir = 0;
            else if (key === Qt.Key_Right || key === Qt.Key_D) dir = 1;
            else if (key === Qt.Key_Down || key === Qt.Key_S) dir = 2;
            else if (key === Qt.Key_Left || key === Qt.Key_A) dir = 3;

            if (dir !== -1 && root.activeNodes && root.activeNodes.length > 0) {
                var cur = null;
                for (var j = 0; j < root.activeNodes.length; ++j) {
                    if (root.activeNodes[j].id === root.selectedNodeId) {
                        cur = root.activeNodes[j];
                        break;
                    }
                }
                if (!cur && root.activeNodes.length > 0) {
                    cur = root.activeNodes[0];
                }

                var nextNeighbor = RadialGeometry.findSpatialNeighbor(cur, root.activeNodes, dir);
                if (nextNeighbor && nextNeighbor.id && nextNeighbor.id !== root.selectedNodeId) {
                    root.selectedNodeId = nextNeighbor.id;
                    root.nodeChanged(nextNeighbor.id);
                    return true;
                } else if (dir === 3) {
                    // Pressing left from the root node returns to wheel
                    root.collapseRequested();
                    return true;
                }
            }
        }

        return false;
    }
}
