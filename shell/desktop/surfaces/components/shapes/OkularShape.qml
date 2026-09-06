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

        // Document Perimeter Sheet
        ShapePath {
            strokeColor: root.color
            strokeWidth: root.strokeWidth
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.MiterJoin

            PathSvg {
                path: "M 4 2.5 H 12.5 L 16.5 6.5 V 19.5 H 4 Z"
            }
        }

        // Dog-ear Corner Fold
        ShapePath {
            strokeColor: root.color
            strokeWidth: 1.2
            fillColor: "transparent"
            joinStyle: ShapePath.MiterJoin

            PathSvg {
                path: "M 12.5 2.5 V 6.5 H 16.5"
            }
        }

        // Data Scanlines
        ShapePath {
            strokeColor: root.color
            strokeWidth: 1.0
            fillColor: "transparent"
            capStyle: ShapePath.SquareCap

            PathSvg {
                path: "M 6.5 6 H 10.5 M 6.5 9 H 14 M 6.5 12 H 10"
            }
        }

        // Magnifying Reticle Lens
        ShapePath {
            strokeColor: root.color
            strokeWidth: 1.4
            fillColor: "transparent"

            PathSvg {
                path: "M 14.5 9.5 A 5 5 0 1 0 14.5 19.5 A 5 5 0 1 0 14.5 9.5 Z"
            }
        }

        // Loupe Diagonal Handle
        ShapePath {
            strokeColor: root.color
            strokeWidth: 2.0
            fillColor: "transparent"
            capStyle: ShapePath.SquareCap

            PathSvg {
                path: "M 18 18 L 22 22"
            }
        }

        // Optical Crosshair Reticles
        ShapePath {
            strokeColor: root.color
            strokeWidth: 1.0
            fillColor: "transparent"
            capStyle: ShapePath.SquareCap

            PathSvg {
                path: "M 10.5 14.5 H 12.5 M 16.5 14.5 H 18.5 M 14.5 10.5 V 12.5 M 14.5 16.5 V 18.5"
            }
        }
    }
}
