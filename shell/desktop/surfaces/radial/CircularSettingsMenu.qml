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
    property int focusedIndex: 0
    property bool isExpanded: false

    property real baseDiameter: 520
    property real innerRadius: 185
    property real outerRadius: 220
    property real leftAnchorX: Math.max(100, width * 0.06)

    // Animated Wheel Center Coordinates
    property real targetCenterX: isExpanded ? leftAnchorX : (width / 2)
    property real wheelCenterX: targetCenterX
    property real wheelCenterY: height / 2

    Behavior on wheelCenterX {
        NumberAnimation {
            duration: Theme.durationSlow
            easing.type: Easing.OutCubic
        }
    }

    // Target Rotation: Continuous shortest-path calculation
    readonly property real segAngle: 360.0 / (root.model ? Math.max(1, root.model.categoryCount) : 9)
    readonly property real selectedBaseAngle: -90.0 + focusedIndex * segAngle
    readonly property real baseTargetAngle: isExpanded ? RadialGeometry.normalizeAngle(-selectedBaseAngle) : 0.0

    property real wheelRotation: 0.0

    Behavior on wheelRotation {
        id: wheelRotationBehavior
        NumberAnimation {
            id: wheelRotationAnim
            duration: Theme.durationSlow
            easing.type: Easing.OutCubic
            onRunningChanged: {
                if (!running && !root.isExpanded) {
                    wheelRotationBehavior.enabled = false;
                    root.wheelRotation = 0.0;
                    wheelRotationBehavior.enabled = true;
                }
            }
        }
    }

    function updateRotationTarget(): void {
        var currentNorm = RadialGeometry.normalizeAngle(root.wheelRotation);
        var delta = RadialGeometry.angleDifference(currentNorm, root.baseTargetAngle);
        root.wheelRotation = root.wheelRotation + delta;
    }

    onBaseTargetAngleChanged: updateRotationTarget()

    // Signals
    signal categoryClicked(int index)
    signal categoryHovered(int index)
    signal collapseRequested()

    // Rotating Wheel Container
    Item {
        id: wheelContainer
        x: root.wheelCenterX - width / 2
        y: root.wheelCenterY - height / 2
        width: root.baseDiameter + 40
        height: root.baseDiameter + 40
        rotation: root.wheelRotation
        transformOrigin: Item.Center

        // Annular Sectors (dynamic category count)
        Repeater {
            model: root.model ? root.model.categoryCount : 0
            delegate: RadialSegment {
                id: segItem
                width: wheelContainer.width
                height: wheelContainer.height
                
                categoryId: (root.model && root.model.categories[index]) ? root.model.categories[index].id : ""
                categoryName: (root.model && root.model.categories[index]) ? root.model.categories[index].name : ""
                iconName: (root.model && root.model.categories[index]) ? root.model.categories[index].icon : "gear"
                cx: wheelContainer.width / 2
                cy: wheelContainer.height / 2
                baseInnerRadius: root.innerRadius
                baseOuterRadius: root.outerRadius
                centerAngle: -90.0 + index * root.segAngle
                wheelRotation: root.wheelRotation
                isFocused: root.focusedIndex === index && !root.isExpanded
                isSelected: root.focusedIndex === index && root.isExpanded
                isDimmed: root.isExpanded && root.focusedIndex !== index

                onClicked: {
                    root.categoryClicked(index);
                }
                onHovered: {
                    root.categoryHovered(index);
                }
            }
        }
    }

    // Center Circular HUD Hub
    Item {
        id: centerHub
        x: root.wheelCenterX - width / 2
        y: root.wheelCenterY - height / 2
        width: root.innerRadius * 2 - 10
        height: root.innerRadius * 2 - 10

        // Hub Disc
        Rectangle {
            anchors.fill: parent
            radius: Theme.radiusPill
            color: Theme.gray900
            border.color: root.isExpanded ? Theme.acidGreen : Theme.gray700
            border.width: 1

            Behavior on border.color {
                ColorAnimation { duration: Theme.durationFast }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                hoverEnabled: true
                onClicked: {
                    if (root.isExpanded) {
                        root.collapseRequested();
                    } else {
                        root.categoryClicked(root.focusedIndex);
                    }
                }
            }
        }

        // Concentric Inner Tech Ring
        Rectangle {
            anchors.centerIn: parent
            width: parent.width - 24
            height: parent.height - 24
            radius: Theme.radiusPill
            color: "transparent"
            border.color: Theme.gray800
            border.width: 1
        }

        // Center Content Text (Active Category Readout)
        Column {
            anchors.centerIn: parent
            width: parent.width - 30
            spacing: 4
            opacity: root.isExpanded ? 0.3 : 1.0

            Behavior on opacity {
                NumberAnimation { duration: Theme.durationSlow; easing.type: Easing.OutCubic }
            }

            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: (root.model && root.model.categories[root.focusedIndex]) ? root.model.categories[root.focusedIndex].name : "SYSTEM"
                font.family: Theme.fontFamilyMonospace
                font.pixelSize: Theme.fontSizeTitle
                font.weight: Theme.fontWeightBold
                color: Theme.textPrimary
                elide: Text.ElideRight
            }

            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: (root.model && root.model.categories[root.focusedIndex]) ? root.model.categories[root.focusedIndex].subtitle : ""
                font.family: Theme.fontFamilyMonospace
                font.pixelSize: Theme.fontSizeCaption
                color: Theme.acidGreen
                wrapMode: Text.WordWrap
                maximumLineCount: 2
                elide: Text.ElideRight
            }
        }
    }
}
