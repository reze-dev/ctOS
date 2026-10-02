pragma ComponentBehavior: Bound

import QtQuick
import "../../core"
import "../../services"

// Circular utilisation gauge: a track ring with a value arc over it and the
// percentage in the middle.
//
// Drawn on a Canvas rather than with Shape. Shape would need either
// ShapeLinearGradient or a stack of polygon segments to approximate the arc,
// and neither resolves in this Qt packaging -- QtQuick's linktarget for
// qtquick2plugin cannot be satisfied in the Nix sandbox, so Shape-based
// gradients fail at instantiation. Canvas has no such dependency.
Item {
    id: root

    // Used fraction, [0.0, 1.0]. Clamped on read: callers hand this live
    // telemetry, and a momentary >1 would otherwise draw an arc that overshoots
    // the track and looks like a rendering fault.
    property real fraction: 0.0

    property color ringColor: Theme.accent
    property color trackColor: Theme.borderMuted
    property real lineWidth: 5
    property string valueText: ""
    property string caption: ""

    // Text colour sits outside the Canvas: Canvas text would be unselectable,
    // unstyled by the font tokens, and would have to be redrawn on every
    // telemetry tick along with the arc.
    readonly property color valueColor:
        !SystemMonitorService.available ? Theme.textDisabled : Theme.textPrimary

    implicitWidth: 56
    implicitHeight: caption !== "" ? 76 : 58

    // Real sizes, not just implicit ones. Row and Flow measure themselves from
    // their children's *height*, not from child implicitHeight, so a StatRing
    // that only declared implicit sizes measured zero tall and collapsed the
    // whole row it sat in.
    width: implicitWidth
    height: implicitHeight

    Canvas {
        id: ring
        width: Math.min(56, root.width)
        height: width
        antialiasing: true

        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();

            const cx = width / 2;
            const cy = height / 2;
            // Inset by half the stroke so the ring is not clipped by the canvas.
            const radius = (Math.min(width, height) - root.lineWidth) / 2;
            if (radius <= 0)
                return;

            ctx.lineWidth = root.lineWidth;
            ctx.lineCap = "round";

            ctx.beginPath();
            ctx.arc(cx, cy, radius, 0, Math.PI * 2);
            ctx.strokeStyle = root.trackColor;
            ctx.stroke();

            const f = Math.max(0, Math.min(1, root.fraction));
            if (f > 0) {
                // Start at 12 o'clock and sweep clockwise, so the arc reads as
                // a gauge filling up rather than as a pie chart.
                ctx.beginPath();
                ctx.arc(cx, cy, radius, -Math.PI / 2, -Math.PI / 2 + f * Math.PI * 2);
                ctx.strokeStyle = root.ringColor;
                ctx.stroke();
            }
        }

        // Live telemetry repaints every second; without these the ring would
        // show whatever fraction happened to be set when the card was created.
        Connections {
            target: root
            function onFractionChanged() { ring.requestPaint(); }
            function onRingColorChanged() { ring.requestPaint(); }
            function onTrackColorChanged() { ring.requestPaint(); }
            function onLineWidthChanged() { ring.requestPaint(); }
            function onWidthChanged() { ring.requestPaint(); }
        }
    }

    Text {
        anchors.centerIn: ring
        text: root.valueText
        color: root.valueColor
        font.family: Theme.fontFamilyMonospace
        font.pixelSize: Theme.fontSizeCaption
        font.weight: Theme.fontWeightBold
    }

    Text {
        anchors.top: ring.bottom
        anchors.topMargin: Theme.spacingSmall
        anchors.horizontalCenter: parent.horizontalCenter
        text: root.caption
        visible: root.caption !== ""
        color: Theme.textSecondary
        font.family: Theme.fontFamilyMonospace
        font.pixelSize: Theme.fontSizeCaption
        font.weight: Theme.fontWeightBold
    }
}