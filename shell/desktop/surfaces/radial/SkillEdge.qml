import QtQuick
import QtQuick.Shapes
import "../../core"

Item {
    id: root

    // =========================================================================
    // Properties
    // =========================================================================

    property real x1: 0.0
    property real y1: 0.0
    property real x2: 0.0
    property real y2: 0.0

    property bool isActive: false
    property bool isPreview: false
    property int pulseDuration: Theme.durationSlow

    property real progress: 0.0

    anchors.fill: parent

    function triggerPulse() {
        if (!isPreview) {
            pulseAnim.restart();
        }
    }

    // Base Connecting Vector Line
    Shape {
        id: lineShape
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeWidth: root.isPreview ? 1.0 : (root.isActive ? 2.0 : 1.2)
            strokeColor: root.isActive ? Theme.acidGreen : (root.isPreview ? Theme.gray700 : Theme.gray600)
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap

            Behavior on strokeColor {
                ColorAnimation { duration: Theme.durationFast }
            }
            Behavior on strokeWidth {
                NumberAnimation { duration: Theme.durationFast }
            }

            startX: root.x1
            startY: root.y1

            PathLine {
                x: root.x2
                y: root.y2
            }
        }
    }

    // Traveling Signal Packet Animation
    NumberAnimation {
        id: pulseAnim
        target: root
        property: "progress"
        from: 0.0
        to: 1.0
        duration: root.pulseDuration
        easing.type: Easing.InOutQuad
    }

    // Traveling Signal Packet Dot
    Rectangle {
        id: signalPacket
        width: 6
        height: 6
        radius: Theme.radiusPill
        color: Theme.acidGreen
        visible: pulseAnim.running && !root.isPreview
        x: root.x1 + root.progress * (root.x2 - root.x1) - width / 2
        y: root.y1 + root.progress * (root.y2 - root.y1) - height / 2
    }
}
