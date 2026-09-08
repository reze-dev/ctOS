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

        // Ghostly Shroud / Hood Contour
        ShapePath {
            strokeColor: root.color
            strokeWidth: root.strokeWidth
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.MiterJoin

            PathSvg {
                path: "M 12 3 L 6 7 L 5 16 L 7 21 L 9 17.5 L 12 21 L 15 17.5 L 17 21 L 19 16 L 18 7 Z"
            }
        }

        // Left Rectangular Eye Visor Slit
        ShapePath {
            strokeColor: root.color
            strokeWidth: 1.0
            fillColor: root.color

            PathSvg {
                path: "M 7.5 11 H 10.5 V 13.5 H 7.5 Z"
            }
        }

        // Right Rectangular Eye Visor Slit
        ShapePath {
            strokeColor: root.color
            strokeWidth: 1.0
            fillColor: root.color

            PathSvg {
                path: "M 13.5 11 H 16.5 V 13.5 H 13.5 Z"
            }
        }

        // Cyber Forehead HUD Tick
        ShapePath {
            strokeColor: root.color
            strokeWidth: 1.0
            fillColor: "transparent"
            capStyle: ShapePath.SquareCap

            PathSvg {
                path: "M 12 5.5 L 12 7.5"
            }
        }
    }
}
