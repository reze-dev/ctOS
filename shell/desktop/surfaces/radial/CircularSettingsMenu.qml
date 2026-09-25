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

    property real baseDiameter: 360
    property real innerRadius: 95
    property real outerRadius: 170
    property real leftAnchorX: 180

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

    // Target Rotation: Aligns selected category to 0 deg (pointing right)
    readonly property real selectedBaseAngle: -90.0 + focusedIndex * 45.0
    readonly property real desiredAngle: isExpanded ? RadialGeometry.normalizeAngle(-selectedBaseAngle) : 0.0
    property real targetWheelRotation: desiredAngle
    property real wheelRotation: targetWheelRotation

    Behavior on wheelRotation {
        NumberAnimation {
            duration: Theme.durationSlow
            easing.type: Easing.OutCubic
        }
    }

    onDesiredAngleChanged: {
        var diff = RadialGeometry.angleDifference(root.wheelRotation, root.desiredAngle);
        root.targetWheelRotation = root.wheelRotation + diff;
    }

    // Signals
    signal categoryClicked(int index)
    signal categoryHovered(int index)

    // Rotating Wheel Container
    Item {
        id: wheelContainer
        x: root.wheelCenterX - width / 2
        y: root.wheelCenterY - height / 2
        width: root.baseDiameter + 40
        height: root.baseDiameter + 40
        rotation: root.wheelRotation
        transformOrigin: Item.Center

        // 8 Annular Sectors
        Repeater {
            model: 8
            delegate: RadialSegment {
                id: segItem
                width: wheelContainer.width
                height: wheelContainer.height
                index: index
                categoryId: (root.model && root.model.categories[index]) ? root.model.categories[index].id : ""
                categoryName: (root.model && root.model.categories[index]) ? root.model.categories[index].name : ""
                iconName: (root.model && root.model.categories[index]) ? root.model.categories[index].icon : "gear"
                cx: wheelContainer.width / 2
                cy: wheelContainer.height / 2
                baseInnerRadius: root.innerRadius
                baseOuterRadius: root.outerRadius
                startAngle: -90.0 + index * 45.0 - 21.5
                endAngle: -90.0 + index * 45.0 + 21.5
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
                        root.isExpanded = false;
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
