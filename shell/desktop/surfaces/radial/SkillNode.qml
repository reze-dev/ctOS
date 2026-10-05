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

    // Preview nodes sit at 20 against 42 interactive. The reference wheel draws
    // its preview trees as 11px dots on a ~195px ring -- about 5.6% of the
    // diameter -- and 30 was more than twice that, so the trees read as scattered
    // clusters of icons rather than as a dense wheel of small trees. 20 keeps the
    // glyph legible and lands near the reference proportion.
    property real nodeSize: (!isPreview && (isSelected || isHovered)) ? 60 : (isPreview ? 20 : 42)
    property real screenX: x + width / 2
    property real screenY: y + height / 2

    Behavior on nodeSize {
        NumberAnimation { duration: Settings.reducedMotion ? 0 : Theme.durationFast }
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
            // Gated on running, not just on duration. This loop is infinite, so a
            // zero duration would not make it still -- it would make it spin as
            // fast as the frame clock, which is the opposite of reduced motion and
            // costs a wakeup per frame. It has to not run at all.
            running: root.shouldPulse && !Settings.reducedMotion
            loops: Animation.Infinite
            NumberAnimation {
                target: outerRing
                property: "scale"
                from: 1.0
                to: 1.8
                duration: Settings.reducedMotion ? 0 : 1000
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: outerRing
                property: "opacity"
                from: 0.8
                to: 0.0
                duration: Settings.reducedMotion ? 0 : 1000
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
            ColorAnimation { duration: Settings.reducedMotion ? 0 : Theme.durationFast }
        }
        Behavior on color {
            ColorAnimation { duration: Settings.reducedMotion ? 0 : Theme.durationFast }
        }

        // Center Node Icon
        CtosIcon {
            id: nodeIcon
            anchors.centerIn: parent

            // Preview glyphs were hidden outright (`visible: !isPreview ||
            // isSelected`), which left every node in the base-state trees a blank
            // dot. The Watch Dogs reference draws an icon in all of them.
            //
            // They also grow: 24px in the preview trees, and nodeSize-relative once
            // the branch is expanded, so selecting a branch enlarges its glyphs
            // without a second set of art.
            size: root.isPreview ? 24 : Math.max(20, root.nodeSize * 0.44)
            name: root.locked ? "lock" : root.iconName

            // Preview discs are Theme.surface on the radial backdrop, so a preview
            // glyph needs to be lighter than gray800 to read on them -- gray800 was
            // the old value and was effectively invisible. Selected and hovered
            // nodes go to full text, which is the reference's "highlighted turns
            // white" behaviour.
            color: root.locked
                ? Theme.destructive
                : (root.isSelected || root.isHovered
                    ? Theme.textPrimary
                    : (root.isPreview ? Theme.textMuted : Theme.gray500))

            Behavior on color {
                ColorAnimation { duration: Settings.reducedMotion ? 0 : Theme.durationFast }
            }
        }

        // State blip: green when the setting is doing its thing, red when it is
        // not. It used to be accent-coloured and visible only while active, so
        // "off" had no marker at all -- the reference shows both states.
        Rectangle {
            id: activeDot
            width: 6
            height: 6
            radius: Theme.radiusPill
            color: root.isActive ? Theme.status : Theme.destructive
            anchors.bottom: parent.bottom
            anchors.right: parent.right
            anchors.margins: 3
            visible: !root.isPreview && !root.locked

            Behavior on color {
                ColorAnimation { duration: Settings.reducedMotion ? 0 : Theme.durationFast }
            }
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
