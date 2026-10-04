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

    property string controlType: ""
    property bool locked: false
    property bool isSelected: false
    property bool isPreview: false
    property bool isHovered: false
    property bool isActive: false

    property real nodeSize: (!isPreview && (isSelected || isHovered)) ? 60 : (isPreview ? 30 : 42)
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

    readonly property bool shouldPulse: !isPreview && (isSelected || isHovered)

    onShouldPulseChanged: {
        if (shouldPulse) {
            pulseAnim.restart();
        } else {
            pulseAnim.stop();
            outerRing.scale = 1.0;
            outerRing.opacity = 0.0;
        }
    }

    // Expanding Concentric Signal Pulse Wave
    Rectangle {
        id: outerRing
        anchors.centerIn: parent
        width: root.width
        height: root.height
        radius: Theme.radiusPill
        color: "transparent"
        border.color: (root.controlType === "readonly" || root.locked) ? Theme.warningRed : Theme.acidGreen
        border.width: 4
        opacity: 0.0
        scale: 1.0
        visible: !root.isPreview

        ParallelAnimation {
            id: pulseAnim
            running: root.shouldPulse
            loops: Animation.Infinite
            NumberAnimation {
                target: outerRing
                property: "scale"
                from: 1.0
                to: 1.8
                duration: 1000
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: outerRing
                property: "opacity"
                from: 0.8
                to: 0.0
                duration: 1000
                easing.type: Easing.OutCubic
            }
        }
    }


    // Main Node Disc
    Rectangle {
        id: nodeDisc
        anchors.fill: parent
        radius: Theme.radiusPill
        // Was `(... ? "black" : Theme.gray900)`.
        //
        // The "black" branch cannot become gray900: gray900 *is* the page
        // background, so every branch node disc went the same colour as the
        // scrim behind it and vanished. "black" had been standing in for
        // "something darker than the page", and surface is the palette's answer
        // to that -- one step up from bg rather than a literal that only ever
        // worked on a near-black palette.
        //
        // The preview branch keeps gray900, which is intentional: an unselected
        // preview node is meant to recede into the grid.
        color: (!root.isPreview || root.isSelected || root.isHovered) ? Theme.surface : Theme.gray900
        border.width: (!root.isPreview) ? 0 : ((root.isSelected || root.isHovered) ? 2 : 1)
        border.color: root.locked ? Theme.warningRed : ((root.isSelected || root.isHovered) ? Theme.textPrimary : (root.isPreview ? Theme.gray800 : Theme.gray700))

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
            color: root.locked ? Theme.warningRed : ((!root.isPreview || root.isSelected || root.isHovered) ? Theme.textPrimary : (root.isPreview ? Theme.gray800 : Theme.gray500))
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
