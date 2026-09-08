import QtQuick
import QtQuick.Shapes

Item {
    id: root

    property real size: 24
    property color color: "#1BFD9C"
    property real strokeWidth: 1.2
    property bool active: false

    width: root.size
    height: root.size
    scale: root.size / 24.0
    transformOrigin: Item.TopLeft

    Shape {
        id: shape
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        // Facet 1: Top Left (Active Light Facet)
        ShapePath {
            strokeColor: root.color
            strokeWidth: root.strokeWidth
            fillColor: root.color
            fillGradient: null
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.MiterJoin

            PathSvg {
                path: "M 12 2 L 3.5 9.5 L 12 11 Z"
            }
        }

        // Facet 2: Top Right
        ShapePath {
            strokeColor: root.color
            strokeWidth: root.strokeWidth
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.MiterJoin

            PathSvg {
                path: "M 12 2 L 20.5 9.5 L 12 11 Z"
            }
        }

        // Facet 3: Mid Left
        ShapePath {
            strokeColor: root.color
            strokeWidth: root.strokeWidth
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.MiterJoin

            PathSvg {
                path: "M 3.5 9.5 L 5.5 17 L 12 11 Z"
            }
        }

        // Facet 4: Mid Right
        ShapePath {
            strokeColor: root.color
            strokeWidth: root.strokeWidth
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.MiterJoin

            PathSvg {
                path: "M 20.5 9.5 L 18.5 17 L 12 11 Z"
            }
        }

        // Facet 5: Bottom Left
        ShapePath {
            strokeColor: root.color
            strokeWidth: root.strokeWidth
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.MiterJoin

            PathSvg {
                path: "M 5.5 17 L 12 22 L 12 11 Z"
            }
        }

        // Facet 6: Bottom Right
        ShapePath {
            strokeColor: root.color
            strokeWidth: root.strokeWidth
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.MiterJoin

            PathSvg {
                path: "M 18.5 17 L 12 22 L 12 11 Z"
            }
        }
    }
}
