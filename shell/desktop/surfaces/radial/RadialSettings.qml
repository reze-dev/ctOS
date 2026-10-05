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
        duration: Settings.reducedMotion ? 0 : 130
        easing.type: Easing.OutCubic
    }

    // Expand Choreography: Wheel translates left first, branch deploys once wheel nears left edge
    Timer {
        id: expandTimer
        // Zero under reducedMotion: these three stagger the wheel
        // rotation and the branch origin, so snapping them is what makes the
        // expansion instant rather than merely fast.
        interval: Settings.reducedMotion ? 0 : 180
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
        interval: Settings.reducedMotion ? 0 : 140
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
        interval: Settings.reducedMotion ? 0 : 320
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
            // Its own slot, not palBase. The radial covers the whole screen while
            // it is open and reads as a separate place, so it takes a
            // palette-specific floor -- bronze under pine, deep teal under acid --
            // rather than sharing the desktop's page background. The grid below
            // and the ContextPanel both sit on top of this and read from the same
            // token, so the whole surface tints together.
            color: Theme.palRadialBackdrop
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
            // Tinted from the backdrop, not from bg. Both are dark and the
            // checkerboard is only 15% alpha, so using bg here would leave a
            // faintly blue-grey checker on top of a bronze or teal floor.
            ctx.fillStyle = Theme.withAlpha(Theme.palRadialBackdrop, 0.55);
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
        // SkillTree kept its own outerRadius of 210 while the wheel's ring is
        // 180, so everything anchored to the rim started 30px outside it.
        outerRadius: wheelMenu.outerRadius
        // Where the expanded branch's base node sits: 350px right of the wheel's
        // left anchor, which is where it was before the geometry work.
        //
        // I moved this to leftAnchorX + outerRadius + 11 while chasing the base
        // wheel's short trunks, on the theory that the expanded tree should hug
        // the ring too. It should not -- the expanded view has the whole canvas
        // to itself, so its branch starts further out and runs longer.
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

        // Negative on purpose. outerRadius is 180, so a centre at -70 leaves
        // 110px of a 360px diameter on screen -- about a third of the circle,
        // showing only the arc the branch grows out of.
        //
        // This was previously "fixed" to Math.max(220, width * 0.12) on the
        // theory that the wheel hanging off the left edge was a bug. It is not:
        // the expanded reference shows exactly that, one third of the arc, with
        // the branch tree reading as if it grew out of the hub. Centring the
        // whole wheel instead puts a large empty circle between the arc and the
        // base node, so the tree stops looking attached to anything.
        leftAnchorX: -70
        z: 10

        onCategoryClicked: function(idx) {
            if (root.focusedCategoryIndex === idx) {
                root.isExpanded = !root.isExpanded;
            } else {
                root.focusedCategoryIndex = idx;
            }
        }

        // onCategoryHovered is gone with the signal. It was connected here but
        // never raised: RadialSegment declared hovered() and had no MouseArea to
        // emit it from, so hovering a segment did nothing through this path.
        // Hovering the wheel to change category is surfaceMouseArea's
        // onPositionChanged -> handleMouseMove, which is what has always actually
        // driven it.

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
                } else if (distFromCenter > wheelMenu.outerRadius + 100) {
                    // Outside the wheel entirely: ignore the click.
                    //
                    // This used to be `> 280` -> OverlayController.close(), so any
                    // click more than 280px from the wheel centre dismissed the
                    // whole surface. The wheel's outerRadius is only 180, which
                    // meant the dead zone swallowed most of a 1920px screen: a
                    // stray click on the wallpaper, the notch, or empty space
                    // tore down a menu the user had just opened. Nothing inside
                    // the wheel needs the dismiss -- the hub collapses, segments
                    // select, and Esc closes -- so the wide zone was pure loss.
                    //
                    // Distances past the rim are ignored rather than snapped to
                    // the nearest segment, because angle-only selection would
                    // make a click at the far corner of the screen jump the
                    // selection to whatever happened to be nearest.
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
