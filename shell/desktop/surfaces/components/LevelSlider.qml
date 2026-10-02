pragma ComponentBehavior: Bound

import QtQuick
import "../../core"

// Horizontal level slider: a filled track, a knob, drag and wheel to set.
//
// Exists because the CCC had two of these inline -- output and microphone --
// which meant the drag handling, the fill maths and the keyboard behaviour all
// existed twice. Behaviour is also easier to reason about in one place than to
// keep consistent across two copies.

Item {
    id: root

    // Level in [0.0, 1.0]. Clamped on the way in and on the way out, because the
    // value can come from a service that reports out-of-range, and an unclamped
    // fraction draws a fill past the end of the track.
    property real value: 0.0
    readonly property real clamped: Math.max(0, Math.min(1, value))

    property real minimum: 0.0
    property real maximum: 1.0
    readonly property real span: Math.max(0.0001, maximum - minimum)

    property color fillColor: Theme.accentViolet
    property color trackColor: Theme.navyBorder
    property color knobColor: Theme.textPrimary

    property real knobDiameter: 12
    property real trackHeight: 5

    // Emitted while dragging as well as on release, so the caller can push the
    // value to the service continuously rather than only at the end.
    signal moved(real level)
    signal committed(real level)

    implicitHeight: Math.max(knobDiameter, trackHeight)
    implicitWidth: 160

    function _levelFromX(x: real): real {
        const usable = Math.max(1, width - knobDiameter);
        const t = Math.max(0, Math.min(1, (x - knobDiameter / 2) / usable));
        return minimum + t * span;
    }

    Rectangle {
        id: track
        // Inset by the knob radius so the fill starts under the knob's leading
        // edge rather than under its centre. Margins belong to the anchors
        // group, not to the item.
        anchors {
            left: parent.left
            right: parent.right
            verticalCenter: parent.verticalCenter
            leftMargin: root.knobDiameter / 2
            rightMargin: root.knobDiameter / 2
        }
        height: root.trackHeight
        radius: height / 2
        color: root.trackColor
    }

    Rectangle {
        id: fill
        anchors.left: track.left
        anchors.verticalCenter: parent.verticalCenter
        height: root.trackHeight
        radius: height / 2
        color: root.fillColor
        width: Math.max(0, (track.width) * ((root.clamped - root.minimum) / root.span))

        Behavior on width {
            NumberAnimation {
                // Only animate programmatic changes; a drag is already smooth
                // and animating it here would lag the knob behind the pointer.
                duration: root.pressed ? 0 : (Settings.reducedMotion ? 0 : Theme.durationFast)
            }
        }
    }

    Rectangle {
        id: knob
        width: root.knobDiameter
        height: width
        radius: width / 2
        color: root.knobColor
        y: (root.height - height) / 2
        x: (Math.max(1, root.width - root.knobDiameter)) * ((root.clamped - root.minimum) / root.span)

        Behavior on x {
            NumberAnimation {
                duration: root.pressed ? 0 : (Settings.reducedMotion ? 0 : Theme.durationFast)
                easing.type: Easing.OutCubic
            }
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        anchors.margins: -Theme.spacingSmall
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        property bool pressed: false

        onPressed: function (mouse) {
            area.pressed = true;
            const v = root._levelFromX(mouse.x);
            root.value = v;
            root.moved(v);
        }
        onPositionChanged: function (mouse) {
            if (!area.pressed)
                return;
            const v = root._levelFromX(mouse.x);
            root.value = v;
            root.moved(v);
        }
        onReleased: function (mouse) {
            area.pressed = false;
            root.committed(root.clamped);
        }

        onWheel: function (wheel) {
            const delta = (wheel.angleDelta.y !== 0 ? wheel.angleDelta.y : wheel.angleDelta.x) > 0
                ? root.span * 0.05 : -root.span * 0.05;
            const v = Math.max(root.minimum, Math.min(root.maximum, root.value + delta));
            root.value = v;
            root.moved(v);
            root.committed(v);
        }
    }
}