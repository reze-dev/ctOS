import QtQuick
import "../../core"
import "../components"

Item {
    id: root

    // =========================================================================
    // Properties
    // =========================================================================

    property string nodeId: ""
    property string title: ""
    property string subtitle: ""
    property string iconName: "gear"

    property bool locked: false
    property bool isSelected: false
    property bool isPreview: false
    property bool isHovered: false
    property bool isActive: false

    property real nodeSize: (!isPreview && isSelected) ? 60 : (isPreview ? 30 : 42)
    property real screenX: x + width / 2
    property real screenY: y + height / 2

    Behavior on nodeSize {
        NumberAnimation { duration: Theme.durationFast }
    }

    width: nodeSize
    height: nodeSize

    signal clicked()
    signal hovered()

    function triggerPulse() {
        pulseAnim.restart();
    }

    onIsSelectedChanged: {
        if (isSelected && !isPreview) {
            triggerPulse();
        }
    }

    // Expanding Concentric Signal Pulse Wave
    Rectangle {
        id: pulseRing
        anchors.centerIn: parent
        width: root.width
        height: root.height
        radius: Theme.radiusPill
        color: "transparent"
        border.color: root.locked ? Theme.warningRed : Theme.acidGreen
        border.width: 2
        opacity: 0.0
        scale: 1.0
        visible: !root.isPreview

        ParallelAnimation {
            id: pulseAnim
            NumberAnimation {
                target: pulseRing
                property: "scale"
                from: 1.0
                to: 1.8
                duration: Theme.durationSlow
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: pulseRing
                property: "opacity"
                from: 0.8
                to: 0.0
                duration: Theme.durationSlow
                easing.type: Easing.OutCubic
            }
        }
    }


    // Main Node Disc
    Rectangle {
        id: nodeDisc
        anchors.fill: parent
        radius: Theme.radiusPill
        color: (!root.isPreview || root.isSelected || root.isHovered) ? "black" : Theme.gray900
        border.width: (!root.isPreview) ? 0 : ((root.isSelected || root.isHovered) ? 2 : 1)
        border.color: root.locked ? Theme.warningRed : ((root.isSelected || root.isHovered) ? "white" : (root.isPreview ? Theme.gray800 : Theme.gray700))

        Behavior on border.color {
            ColorAnimation { duration: Theme.durationFast }
        }
        Behavior on color {
            ColorAnimation { duration: Theme.durationFast }
        }

        // Center Node Icon
        CtosIcon {
            id: nodeIcon
            anchors.centerIn: parent
            size: root.isPreview ? 24 : Math.max(20, root.nodeSize * 0.44)
            name: root.locked ? "lock" : root.iconName
            color: root.locked ? Theme.warningRed : ((!root.isPreview || root.isSelected || root.isHovered) ? "white" : (root.isPreview ? Theme.gray800 : Theme.gray500))
            visible: !root.isPreview || root.isSelected

            Behavior on color {
                ColorAnimation { duration: Theme.durationFast }
            }
        }

        // Active State Indicator Dot
        Rectangle {
            id: activeDot
            width: 6
            height: 6
            radius: Theme.radiusPill
            color: Theme.acidGreen
            anchors.bottom: parent.bottom
            anchors.right: parent.right
            anchors.margins: 3
            visible: root.isActive && !root.locked
        }

        // Lock Badge Mini Indicator
        Rectangle {
            id: lockBadge
            width: 14
            height: 14
            radius: Theme.radiusPill
            color: Theme.gray900
            border.color: Theme.warningRed
            border.width: 1
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.margins: -2
            visible: root.locked && !root.isPreview

            CtosIcon {
                anchors.centerIn: parent
                size: 8
                name: "lock"
                color: Theme.warningRed
            }
        }
    }

    // Interactive Mouse Interaction Area
    MouseArea {
        id: nodeMouseArea
        anchors.fill: parent
        enabled: !root.isPreview
        hoverEnabled: true
        cursorShape: root.locked ? Qt.ForbiddenCursor : Qt.PointingHandCursor
        onEntered: {
            root.isHovered = true;
            root.hovered();
        }
        onExited: {
            root.isHovered = false;
        }
        onClicked: {
            if (!root.locked) {
                root.clicked();
            }
        }
    }
}
