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

    // Preview nodes sit at 30 against 42 interactive. The reference wheel draws
    // proportionally smaller dots, but matching that ratio cost legibility on
    // every icon in the tree, so the shipped size stayed.
    property real nodeSize: (!isPreview && (isSelected || isHovered)) ? 60 : (isPreview ? 30 : 42)
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
        // Base-tree discs are Theme.palBase -- the palette's darkest slot -- so the whole
        // wheel reads as flat near-black dots and a section's glyphs are the only
        // thing that lights up when it is focused. That is what the reference
        // draws, and it is why its preview nodes look like featureless dots: the
        // glyph is present, painted the same colour as the disc, and invisible
        // until that section is highlighted.
        //
        // Theme.palBase rather than a literal black: Phase 1 removed the hardcoded
        // "black" from this file, and neither palette has a #000 slot. bg is the
        // darkest each one gets (#13111E pine, #0E0E0E acid) and sits below
        // radialBackdrop in both, so the discs still read against the backdrop.
        //
        // Preview discs deliberately keep a constant 1px border. Highlighting one
        // used to take the border to 2px in text colour, which put a lit ring
        // around every node of the focused section -- the reference highlights
        // the glyphs only, and leaves the rings alone.
        color: root.isPreview
            ? (root.locked ? Theme.destructive : Theme.palBase)
            : Theme.surface
        border.width: root.isPreview ? 1 : 0
        border.color: root.isPreview
            ? (root.locked ? Theme.destructive : Theme.gray800)
            : (root.locked ? Theme.warningRed : Theme.gray700)

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

// Base-tree glyphs sit at 24 inside a 30px disc, which is the size this
            // repo shipped and the smallest that keeps every icon legible at a
            // glance. They were briefly dropped to 13 to chase the reference
            // wheel's dot-to-ring ratio, and the icons became unreadable --
            // matching a proportion is not worth that.
            //
            // Once expanded, glyphs grow with the node so selecting a branch
            // enlarges its art without a second set.
            size: root.isPreview ? 24 : Math.max(20, root.nodeSize * 0.44)
            name: root.locked ? "lock" : root.iconName

            // In the base tree the glyph is its own disc's colour, so it is
            // invisible until that section is highlighted -- and then it goes to
            // full text, which is the reference's "highlighted turns white"
            // behaviour. Locked nodes keep the destructive colour in both states,
            // because a lock you cannot see is not information.
            color: root.isPreview
                ? (root.locked
                    ? Theme.destructive
                    : ((root.isSelected || root.isHovered) ? Theme.textPrimary : Theme.palBase))
                : (root.locked
                    ? Theme.destructive
                    : ((root.isSelected || root.isHovered)
                        ? Theme.textPrimary
                        : Theme.gray500))

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
