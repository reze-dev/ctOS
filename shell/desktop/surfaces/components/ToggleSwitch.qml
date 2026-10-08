pragma ComponentBehavior: Bound

import QtQuick
import "../../core"

// Pill toggle switch: a track with a knob that slides across it.
//
// Sizes itself. The toggles this replaces were fixed-width text buttons --
// `width: 60` for "[ON]", `width: 70` for "[UNMUTE]" -- with the width chosen
// by hand to fit the current string. Changing the label silently broke the
// layout. Nothing here depends on the text, so there is no width to get wrong.
//
// Every dimension is a property with a token-sourced default, so a card can
// override scale without redefining the drawing.
Item {
    id: root

    // Off/on state. Deliberately a plain bool property rather than a two-state
    // enum: a toggle has exactly two positions, and anything else in a toggle's
    // API is a bug waiting to happen.
    property bool checked: false

    // Emitted on user interaction only. Assigning `checked` programmatically
    // does not re-emit, so a service pushing state in will not loop back
    // through a handler that writes it again.
    signal toggled()

    property color onColor: Theme.accentBlue
    property color offColor: Theme.navyBorder
    property color knobColor: Theme.textPrimary

    property real trackWidth: 30
    property real trackHeight: 17
    property real knobInset: 2.5

    implicitWidth: trackWidth
    implicitHeight: trackHeight
    width: trackWidth
    height: trackHeight

    readonly property real knobDiameter: height - knobInset * 2
    readonly property real knobTravel: width - knobDiameter - knobInset * 2

    Rectangle {
        id: track
        anchors.fill: parent
        radius: height / 2
        color: root.checked ? root.onColor : root.offColor
        border.width: Theme.borderWidth
        border.color: root.checked ? root.onColor : Theme.borderSubtle
        opacity: hoverArea.containsMouse ? 1.0 : 0.92

        Behavior on color {
            ColorAnimation {
                duration: Settings.reducedMotion ? 0 : Theme.durationFast
            }
        }
    }

    Rectangle {
        id: knob
        width: root.knobDiameter
        height: width
        radius: width / 2
        color: root.knobColor
        y: root.knobInset
        x: root.checked ? root.knobInset + root.knobTravel : root.knobInset

        Behavior on x {
            NumberAnimation {
                duration: Settings.reducedMotion ? 0 : Theme.durationFast
                easing.type: Easing.OutCubic
            }
        }
    }

    MouseArea {
        id: hoverArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        // The whole track is the hit target, not just the knob. A 30x17 target
        // is already small; making the user aim at a 12px circle inside it would
        // be needlessly fiddly.
        onClicked: {
            root.checked = !root.checked;
            root.toggled();
        }
    }
}