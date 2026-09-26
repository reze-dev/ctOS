import QtQuick
import QtQuick.Shapes
import "../../core"
import "../components"
import "RadialGeometry.js" as RadialGeometry

Item {
    id: root

    // =========================================================================
    // Properties
    // =========================================================================

    property int index: 0
    property string categoryId: ""
    property string categoryName: ""
    property string iconName: "gear"

    property real cx: width / 2
    property real cy: height / 2
    property real baseInnerRadius: 100
    property real baseOuterRadius: 170
    property real startAngle: -90.0
    property real endAngle: -45.0
    property real wheelRotation: 0.0

    property bool isFocused: false
    property bool isSelected: false
    property bool isDimmed: false

    readonly property real centerAngle: (startAngle + endAngle) / 2.0

    // Animated dynamic radii for hover expansion
    property real effectiveInnerRadius: isFocused ? (baseInnerRadius - 4) : baseInnerRadius
    property real effectiveOuterRadius: isFocused ? (baseOuterRadius + 12) : baseOuterRadius

    Behavior on effectiveInnerRadius {
        NumberAnimation {
            duration: Theme.durationNormal
            easing.type: Easing.OutCubic
        }
    }

    Behavior on effectiveOuterRadius {
        NumberAnimation {
            duration: Theme.durationNormal
            easing.type: Easing.OutCubic
        }
    }

    // Dynamic Opacity for Dimmed State
    opacity: isDimmed ? 0.15 : 1.0
    Behavior on opacity {
        NumberAnimation {
            duration: Theme.durationSlow
            easing.type: Easing.OutCubic
        }
    }

    // Centered icon coordinates along the radial sector ray
    readonly property var iconCenter: RadialGeometry.pointOnCircle(
        root.cx,
        root.cy,
        (root.effectiveInnerRadius + root.effectiveOuterRadius) / 2.0,
        root.centerAngle
    )

    // Signals
    signal clicked()
    signal hovered()

    // Annular Sector Vector Shape
    Shape {
        id: sectorShape
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            id: sectorPath
            strokeWidth: (root.isFocused || root.isSelected) ? 2.0 : 1.0
            strokeColor: root.isFocused ? Theme.gray50 : (root.isSelected ? Theme.acidGreen : Theme.gray700)
            fillColor: root.isFocused ? Theme.gray50 : (root.isSelected ? Theme.gray800 : Theme.gray900)
            capStyle: ShapePath.FlatCap
            joinStyle: ShapePath.MiterJoin

            Behavior on fillColor {
                ColorAnimation { duration: Theme.durationFast }
            }
            Behavior on strokeColor {
                ColorAnimation { duration: Theme.durationFast }
            }

            PathSvg {
                path: RadialGeometry.createSectorSvgPath(
                    root.cx,
                    root.cy,
                    root.effectiveInnerRadius,
                    root.effectiveOuterRadius,
                    root.startAngle,
                    root.endAngle
                )
            }
        }
    }

    // Centered Category Icon with Rotation Compensation
    Item {
        id: iconContainer
        x: root.iconCenter.x - width / 2
        y: root.iconCenter.y - height / 2
        width: 36
        height: 36

        // Counter-rotate by wheel rotation so icon stays strictly upright
        rotation: -root.wheelRotation

        CtosIcon {
            id: categoryIcon
            anchors.centerIn: parent
            size: 22
            name: root.iconName
            color: root.isFocused ? Theme.gray900 : (root.isSelected ? Theme.acidGreen : Theme.gray200)

            Behavior on color {
                ColorAnimation { duration: Theme.durationFast }
            }
        }

    }
}
