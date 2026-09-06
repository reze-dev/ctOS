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

        // Top Horizontal Slab (Highlight facet)
        ShapePath {
            strokeColor: root.color
            strokeWidth: root.strokeWidth
            fillColor: root.color
            fillGradient: null
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.MiterJoin

            PathSvg {
                path: "M 4 5 L 18 5 L 14.5 9 L 4 9 Z"
            }
        }

        // Diagonal Cross-Beam Slab
        ShapePath {
            strokeColor: root.color
            strokeWidth: root.strokeWidth
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.MiterJoin

            PathSvg {
                path: "M 16.5 6.5 L 19.5 9.5 L 7.5 17.5 L 4.5 14.5 Z"
            }
        }

        // Bottom Horizontal Slab
        ShapePath {
            strokeColor: root.color
            strokeWidth: root.strokeWidth
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.MiterJoin

            PathSvg {
                path: "M 9.5 15 L 20 15 L 16.5 19 L 6 19 Z"
            }
        }
    }
}
