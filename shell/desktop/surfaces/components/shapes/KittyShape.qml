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

        // Faceted Cat Head Polygon
        ShapePath {
            strokeColor: root.color
            strokeWidth: root.strokeWidth
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.MiterJoin

            PathSvg {
                path: "M 4 3 L 9 6.5 L 12 5.5 L 15 6.5 L 20 3 L 21 10.5 L 18 16 L 14 20.5 L 10 20.5 L 6 16 L 3 10.5 Z"
            }
        }

        // Left Ear Inner Facet
        ShapePath {
            strokeColor: root.color
            strokeWidth: 1.0
            fillColor: "transparent"

            PathSvg {
                path: "M 4 3 L 8 10"
            }
        }

        // Right Ear Inner Facet
        ShapePath {
            strokeColor: root.color
            strokeWidth: 1.0
            fillColor: "transparent"

            PathSvg {
                path: "M 20 3 L 16 10"
            }
        }

        // Left Eye Slit
        ShapePath {
            strokeColor: root.color
            strokeWidth: 1.0
            fillColor: root.color

            PathSvg {
                path: "M 7 11.5 L 10 10.5 L 8.5 13 Z"
            }
        }

        // Right Eye Slit
        ShapePath {
            strokeColor: root.color
            strokeWidth: 1.0
            fillColor: root.color

            PathSvg {
                path: "M 17 11.5 L 14 10.5 L 15.5 13 Z"
            }
        }

        // Cyber Nose Triangle
        ShapePath {
            strokeColor: root.color
            strokeWidth: 1.0
            fillColor: root.color

            PathSvg {
                path: "M 11 15 L 13 15 L 12 16.5 Z"
            }
        }

        // Neon Whiskers (Left Upper, Left Lower, Right Upper, Right Lower)
        ShapePath {
            strokeColor: root.color
            strokeWidth: 1.0
            fillColor: "transparent"
            capStyle: ShapePath.SquareCap

            PathSvg {
                path: "M 5 12 L 1 11 M 6 14.5 L 2 15.5 M 19 12 L 23 11 M 18 14.5 L 22 15.5"
            }
        }
    }
}
