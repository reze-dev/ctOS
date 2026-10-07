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

    property real node1Radius: 0.0
    property real node2Radius: 0.0

    readonly property real dx: x2 - x1
    readonly property real dy: y2 - y1
    readonly property real distance: Math.sqrt(dx * dx + dy * dy)
    readonly property real angle: Math.atan2(dy, dx)
    
    readonly property real startEdgeX: distance > (node1Radius + node2Radius) ? x1 + Math.cos(angle) * node1Radius : x1
    readonly property real startEdgeY: distance > (node1Radius + node2Radius) ? y1 + Math.sin(angle) * node1Radius : y1
    
    readonly property real endEdgeX: distance > (node1Radius + node2Radius) ? x2 - Math.cos(angle) * node2Radius : x2
    readonly property real endEdgeY: distance > (node1Radius + node2Radius) ? y2 - Math.sin(angle) * node2Radius : y2

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
            strokeWidth: root.isPreview ? 2.0 : 3.0
            strokeColor: "black"
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap

            startX: root.startEdgeX
            startY: root.startEdgeY

            PathLine {
                x: root.endEdgeX
                y: root.endEdgeY
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
        x: root.startEdgeX + root.progress * (root.endEdgeX - root.startEdgeX) - width / 2
        y: root.startEdgeY + root.progress * (root.endEdgeY - root.startEdgeY) - height / 2
    }
}
