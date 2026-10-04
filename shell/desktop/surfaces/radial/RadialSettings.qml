import QtQuick
import QtQuick.Layouts
import "../../core"
import "../../services"
import "RadialGeometry.js" as RadialGeometry

FocusScope {
    id: root

    anchors.fill: parent
    focus: true

    // =========================================================================
    // State Properties
    // =========================================================================

    property int focusedCategoryIndex: 0
    property string selectedNodeId: "sys-core"
    property bool isExpanded: false
    property bool debugMode: false

    property alias settingsModel: settingsModel
    property alias navCtrl: navCtrl
    property alias wheelMenu: wheelMenu

    // Data-Driven Settings Model
    RadialSettingsModel {
        id: settingsModel
    }

    // Keep selectedNodeId in sync when focused category changes
    onFocusedCategoryIndexChanged: {
        var cat = settingsModel.getCategory(focusedCategoryIndex);
        if (cat && cat.nodes && cat.nodes.length > 0) {
            selectedNodeId = cat.nodes[0].id;
        }
    }

    // Surface Focus Scope Registration
    Component.onCompleted: {
        OverlayController.registerFocusTarget(OverlayController.Surface.RadialSettings, root);
        root.forceActiveFocus();
    }

    Component.onDestruction: {
        OverlayController.unregisterFocusTarget(OverlayController.Surface.RadialSettings);
    }

    // Phased Transition State Coordination
    property bool wheelExpanded: false
    property bool branchExpanded: false

    // NumberAnimation for smooth branch retraction
    NumberAnimation {
        id: branchFadeAnim
        target: skillTree
        property: "opacity"
        from: 1.0
        to: 0.0
        duration: 130
        easing.type: Easing.OutCubic
    }

    // Expand Choreography: Wheel translates left first, branch deploys once wheel nears left edge
    Timer {
        id: expandTimer
        interval: 180
        repeat: false
        onTriggered: {
            if (root.isExpanded) {
                root.branchExpanded = true;
            }
        }
    }

    // Collapse Choreography: Branch retracts first (140ms), then wheel returns to center
    Timer {
        id: collapseTimerWheelReturn
        interval: 140
        repeat: false
        onTriggered: {
            if (!root.isExpanded) {
                root.branchExpanded = false;
                root.wheelExpanded = false;
            }
        }
    }

    // Preview trees blossom back in as the wheel approaches screen center
    Timer {
        id: collapseTimerPreviewRestore
        interval: 320
        repeat: false
        onTriggered: {
            if (!root.isExpanded) {
                skillTree.opacity = 1.0;
            }
        }
    }

    onIsExpandedChanged: {
        if (root.isExpanded) {
            collapseTimerWheelReturn.stop();
            collapseTimerPreviewRestore.stop();
            branchFadeAnim.stop();
            skillTree.opacity = 1.0;

            root.wheelExpanded = true;
            root.branchExpanded = false;
            expandTimer.restart();
        } else {
            expandTimer.stop();
            branchFadeAnim.restart();
            collapseTimerWheelReturn.restart();
            collapseTimerPreviewRestore.restart();
        }
    }

    onVisibleChanged: {
        if (visible) {
            root.forceActiveFocus();
        } else {
            root.isExpanded = false;
            expandTimer.stop();
            collapseTimerWheelReturn.stop();
            collapseTimerPreviewRestore.stop();
            branchFadeAnim.stop();
            root.wheelExpanded = false;
            root.branchExpanded = false;
            skillTree.opacity = 1.0;
        }
    }

    // =========================================================================
    // Background Scrim & Tactical Grid
    // =========================================================================

Rectangle {
          id: scrimBackdrop
          anchors.fill: parent
          // Was a hardcoded rgb(13, 58, 143) navy -- the one surface that was
          // never routed through Theme, so it kept the previous palette through
          // every theme change. palBase carries that same role as the backdrop
          // tone; the grid canvas below is drawn on top of it.
          color: Theme.palBase
          opacity: 0.95
      }

    // Cybernetic Grid Background
    Canvas {
        id: gridCanvas
        anchors.fill: parent
        opacity: 0.35

        onPaint: {
            var ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);

            var step = 48;
            ctx.fillStyle = Qt.rgba(0, 0, 0, 0.15);
            for (var y = 0; y < height; y += step) {
                for (var x = 0; x < width; x += step) {
                    if (((x / step) + (y / step)) % 2 === 0) {
                        ctx.fillRect(x, y, step, step);
                    }
                }
            }

            ctx.strokeStyle = Theme.gray700;
            ctx.lineWidth = 0.5;

            for (var x2 = step; x2 < width; x2 += step) {
                ctx.beginPath();
                ctx.moveTo(x2, 0);
                ctx.lineTo(x2, height);
                ctx.stroke();
            }
            for (var y2 = step; y2 < height; y2 += step) {
                ctx.beginPath();
                ctx.moveTo(0, y2);
                ctx.lineTo(width, y2);
                ctx.stroke();
            }
        }
    }

    // =========================================================================
    // Top HUD Telemetry Bar
    // =========================================================================

    Rectangle {
        id: topHudBar
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 44
        color: Theme.gray900
        border.color: Theme.gray700
        border.width: 1
        z: 20

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Theme.paddingXl
            anchors.rightMargin: Theme.paddingXl
            spacing: Theme.spacingLarge

            // Left System Designation
            RowLayout {
                spacing: Theme.spacingSmall

                Rectangle {
                    Layout.preferredWidth: 8
                    Layout.preferredHeight: 14
                    color: Theme.acidGreen
                }

                Text {
                    text: "ctOS // SETTINGS MATRIX // SPEC-v4.2"
                    font.family: Theme.fontFamilyMonospace
                    font.pixelSize: Theme.fontSizeCaption
                    font.weight: Theme.fontWeightBold
                    color: Theme.acidGreen
                }
            }

            Item {
                Layout.fillWidth: true
            }

            // Center Status Readout
            Text {
                text: "SYSTEM: " + SessionService.compositorName.toUpperCase() + " // UPTIME: ONLINE"
                font.family: Theme.fontFamilyMonospace
                font.pixelSize: Theme.fontSizeCaption
                color: Theme.textSecondary
            }

            Item {
                Layout.fillWidth: true
            }

            // Right Return Badge Button
            Rectangle {
                Layout.preferredHeight: 28
                Layout.preferredWidth: closeLabel.implicitWidth + 20
                radius: Theme.radiusSmall
                color: Theme.gray800
                border.color: Theme.gray600
                border.width: 1

                Text {
                    id: closeLabel
                    anchors.centerIn: parent
                    text: root.isExpanded ? "[ESC] BACK TO WHEEL" : "[ESC] DISMISS MATRIX"
                    font.family: Theme.fontFamilyMonospace
                    font.pixelSize: Theme.fontSizeCaption
                    color: Theme.textPrimary
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (root.isExpanded) {
                            root.isExpanded = false;
                        } else {
                            OverlayController.close();
                        }
                    }
                }
            }
        }
    }

    // =========================================================================
    // Core Visualization Components
    // =========================================================================

    // Skill Tree Graph Container (Preview Trees & Expanded Branch)
    SkillTree {
        id: skillTree
        anchors.fill: parent
        model: settingsModel
        focusedCategoryIndex: root.focusedCategoryIndex
        selectedNodeId: root.selectedNodeId
        isExpanded: root.branchExpanded
        wheelCenterX: wheelMenu.wheelCenterX
        wheelCenterY: wheelMenu.wheelCenterY
        branchOriginX: wheelMenu.leftAnchorX + 350
        branchOriginY: root.height / 2
        z: 5

        onNodeSelected: function(nodeId) {
            root.selectedNodeId = nodeId;
        }
    }

    // Circular Radial Wheel Menu
    CircularSettingsMenu {
        id: wheelMenu
        anchors.fill: parent
        model: settingsModel
        focusedIndex: root.focusedCategoryIndex
        isExpanded: root.wheelExpanded
        leftAnchorX: -70
        z: 10

        onCategoryClicked: function(idx) {
            if (root.focusedCategoryIndex === idx) {
                root.isExpanded = !root.isExpanded;
            } else {
                root.focusedCategoryIndex = idx;
            }
        }

        onCategoryHovered: function(idx) {
            if (!root.isExpanded) {
                root.focusedCategoryIndex = idx;
            }
        }

        onCollapseRequested: {
            root.isExpanded = false;
        }
    }

    // Tactical Right-Side Detail Context Panel
    ContextPanel {
        id: contextPanel
        model: settingsModel
        focusedCategoryIndex: root.focusedCategoryIndex
        selectedNodeId: root.selectedNodeId
        isExpanded: root.branchExpanded
        z: 15
    }

    // =========================================================================
    // Navigation Controller
    // =========================================================================

    NavigationController {
        id: navCtrl
        focusedCategoryIndex: root.focusedCategoryIndex
        selectedNodeId: root.selectedNodeId
        isExpanded: root.isExpanded
        wheelCenterX: wheelMenu.wheelCenterX
        wheelCenterY: wheelMenu.wheelCenterY
        wheelRotation: wheelMenu.wheelRotation
        surfaceWidth: root.width
        surfaceHeight: root.height
        activeNodes: skillTree.activeNodes
        categoryCount: settingsModel.categoryCount
        innerDeadZone: wheelMenu.innerRadius

        onCategoryChanged: function(idx) {
            root.focusedCategoryIndex = idx;
        }

        onNodeChanged: function(nodeId) {
            root.selectedNodeId = nodeId;
        }

        onExpandRequested: {
            root.isExpanded = true;
        }

        onCollapseRequested: {
            root.isExpanded = false;
        }

        onDismissRequested: {
            OverlayController.close();
        }

        onActivateRequested: {
            contextPanel.executeCurrentNode();
        }
    }

    // Surface-Wide Mouse Hover and Wheel Dispatcher
    MouseArea {
        id: surfaceMouseArea
        anchors.fill: parent
        hoverEnabled: true
        preventStealing: false
        z: 1

        onPositionChanged: function(mouse) {
            navCtrl.handleMouseMove(mouse.x, mouse.y);
        }

        onWheel: function(wheel) {
            navCtrl.handleWheel(wheel.angleDelta.y);
            wheel.accepted = true;
        }

        onClicked: function(mouse) {
            var distFromCenter = RadialGeometry.distance(wheelMenu.wheelCenterX, wheelMenu.wheelCenterY, mouse.x, mouse.y);
            if (root.isExpanded) {
                // If clicked on center hub: collapse
                if (distFromCenter < wheelMenu.innerRadius) {
                    root.isExpanded = false;
                } else if (distFromCenter <= wheelMenu.outerRadius + 25) {
                    // Clicked on a wheel segment in expanded mode
                    var rawAngle = RadialGeometry.angleFromCenter(wheelMenu.wheelCenterX, wheelMenu.wheelCenterY, mouse.x, mouse.y);
                    var localAngle = RadialGeometry.normalizeAngle(rawAngle - wheelMenu.wheelRotation);
                    var clickedCat = RadialGeometry.findClosestSegment(localAngle, settingsModel.categoryCount, root.focusedCategoryIndex, 0);
                    root.focusedCategoryIndex = clickedCat;
                }
            } else {
                if (distFromCenter < wheelMenu.innerRadius) {
                    // Clicked center hub -> expand
                    root.isExpanded = true;
                } else if (distFromCenter > 280) {
                    // Clicked far background -> dismiss
                    OverlayController.close();
                } else {
                    // Clicked on a segment
                    var angle = RadialGeometry.angleFromCenter(wheelMenu.wheelCenterX, wheelMenu.wheelCenterY, mouse.x, mouse.y);
                    var clickedIdx = RadialGeometry.findClosestSegment(angle, settingsModel.categoryCount, root.focusedCategoryIndex, 0);
                    root.focusedCategoryIndex = clickedIdx;
                    root.isExpanded = true;
                }
            }
        }
    }

    Keys.onEscapePressed: function(event) {
        var handled = navCtrl.handleKeyPress(Qt.Key_Escape);
        if (handled) {
            event.accepted = true;
        }
    }

    // Global Keyboard Focus Handling
    Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Escape) {
            // Handled specifically by onEscapePressed to preempt global shortcuts
            return;
        }

        if (event.key === Qt.Key_F12) {
            root.debugMode = !root.debugMode;
            event.accepted = true;
            return;
        }

        var handled = navCtrl.handleKeyPress(event.key);
        if (handled) {
            event.accepted = true;
        }
    }

    // =========================================================================
    // Debug Visualization Overlay (F12)
    // =========================================================================

    Item {
        id: debugOverlay
        anchors.fill: parent
        visible: root.debugMode
        z: 99

        // Center crosshair lines
        Rectangle {
            x: wheelMenu.wheelCenterX - 50
            y: wheelMenu.wheelCenterY
            width: 100
            height: 1
            color: Theme.acidGreen
        }
        Rectangle {
            x: wheelMenu.wheelCenterX
            y: wheelMenu.wheelCenterY - 50
            width: 1
            height: 100
            color: Theme.acidGreen
        }

        // Telemetry readout box
        Rectangle {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.margins: Theme.paddingLarge
            width: 320
            height: 120
            color: Theme.gray900
            border.color: Theme.acidGreen
            border.width: 1

            Column {
                anchors.fill: parent
                anchors.margins: Theme.paddingMedium
                spacing: 2

                Text {
                    text: "[DEBUG HUD // F12 ACTIVE]"
                    font.family: Theme.fontFamilyMonospace
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Theme.fontWeightBold
                    color: Theme.acidGreen
                }
                Text {
                    text: "Category: " + root.focusedCategoryIndex + " (" + (settingsModel.getCategory(root.focusedCategoryIndex)?.name || "") + ")"
                    font.family: Theme.fontFamilyMonospace
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.textPrimary
                }
                Text {
                    text: "Selected Node: " + root.selectedNodeId
                    font.family: Theme.fontFamilyMonospace
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.textPrimary
                }
                Text {
                    text: "Expanded: " + root.isExpanded + " | Rotation: " + wheelMenu.wheelRotation.toFixed(1) + " deg"
                    font.family: Theme.fontFamilyMonospace
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.textPrimary
                }
                Text {
                    text: "Wheel Center: (" + wheelMenu.wheelCenterX.toFixed(0) + ", " + wheelMenu.wheelCenterY.toFixed(0) + ")"
                    font.family: Theme.fontFamilyMonospace
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.textSecondary
                }
            }
        }
    }
}
