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

        // Dolphin Body Silhouette
        ShapePath {
            strokeColor: root.color
            strokeWidth: root.strokeWidth
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.MiterJoin

            PathSvg {
                path: "M 21 8 L 19 10.5 L 15 11.5 L 12 16 L 13.5 13 L 9.5 14 L 5 17 L 2 21 L 3.5 18.5 L 1.5 16.5 L 4.5 17.5 L 7.5 13 L 10.5 7 L 12.5 2 L 14 5.5 L 18 5.5 Z"
            }
        }

        // Cyber Eye Slit
        ShapePath {
            strokeColor: root.color
            strokeWidth: root.strokeWidth
            fillColor: "transparent"
            capStyle: ShapePath.SquareCap

            PathSvg {
                path: "M 17 7.5 L 19 7.5"
            }
        }

        // Cybernetic Flank Panel
        ShapePath {
            strokeColor: root.color
            strokeWidth: 1.0
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.MiterJoin

            PathSvg {
                path: "M 14 7.5 L 10.5 10 L 7.5 13"
            }
        }
    }
}
