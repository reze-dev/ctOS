import QtQuick
import QtQuick.Shapes

Item {
    id: root

    property real size: 24
    property color color: "#1BFD9C"
    property real strokeWidth: 1.5
    property bool active: false

    width: root.size
    height: root.size
    scale: root.size / 24.0
    transformOrigin: Item.TopLeft

    Shape {
        id: shape
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        // Octagonal Viewfinder Frame
        ShapePath {
            strokeColor: root.color
            strokeWidth: root.strokeWidth
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.MiterJoin

            PathSvg {
                path: "M 7 2 L 17 2 L 22 7 L 22 17 L 17 22 L 7 22 L 2 17 L 2 7 Z"
            }
        }

        // Reticle Crosshair Ticks
        ShapePath {
            strokeColor: root.color
            strokeWidth: 1.2
            fillColor: "transparent"
            capStyle: ShapePath.SquareCap

            PathSvg {
                path: "M 12 2 L 12 4.5 M 12 22 L 12 19.5 M 2 12 L 4.5 12 M 22 12 L 19.5 12"
            }
        }

        // Equilateral Play Triangle ▶
        ShapePath {
            strokeColor: root.color
            strokeWidth: 1.2
            fillColor: root.color
            joinStyle: ShapePath.MiterJoin

            PathSvg {
                path: "M 9 7 L 17.5 12 L 9 17 Z"
            }
        }
    }
}
