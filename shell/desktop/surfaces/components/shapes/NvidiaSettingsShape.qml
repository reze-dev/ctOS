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

        // Cyber Eye Outline (Almond Contour)
        ShapePath {
            strokeColor: root.color
            strokeWidth: root.strokeWidth
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.MiterJoin

            PathSvg {
                path: "M 2 12 Q 12 4.5 22 12 M 22 12 Q 12 19.5 2 12"
            }
        }

        // Offset Iris Ring
        ShapePath {
            strokeColor: root.color
            strokeWidth: 1.2
            fillColor: "transparent"

            PathSvg {
                path: "M 13 8.5 A 3.5 3.5 0 1 0 13 15.5 A 3.5 3.5 0 1 0 13 8.5 Z"
            }
        }

        // Glowing Offset Pupil Dot
        ShapePath {
            strokeColor: root.color
            strokeWidth: 1.0
            fillColor: root.color

            PathSvg {
                path: "M 13 10.5 A 1.5 1.5 0 1 0 13 13.5 A 1.5 1.5 0 1 0 13 10.5 Z"
            }
        }

        // Curved Spiral Reticle Claws
        ShapePath {
            strokeColor: root.color
            strokeWidth: 1.2
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap

            PathSvg {
                path: "M 4.5 11 Q 8 6.5 13 7 M 6 14 Q 10 17.5 15 16 M 17 8 Q 18.5 12 17 16"
            }
        }

        // Reticle Axis Crosshair Ticks
        ShapePath {
            strokeColor: root.color
            strokeWidth: 1.0
            fillColor: "transparent"
            capStyle: ShapePath.SquareCap

            PathSvg {
                path: "M 0.5 12 L 2 12 M 22 12 L 23.5 12 M 13 3 L 13 5 M 13 19 L 13 21"
            }
        }
    }
}
