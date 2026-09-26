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

    required property int index
    property string categoryId: ""
    property string categoryName: ""
    property string iconName: "gear"

    property real cx: width / 2
    property real cy: height / 2
    property real baseInnerRadius: 150
    property real baseOuterRadius: 210
    property real _lastTargetAngle: -90.0 + index * (360.0 / Math.max(1, typeof categoryCount !== "undefined" ? categoryCount : 8))
    property var layoutInfo: RadialGeometry.getSegmentTargetLayout(
        index, 
        typeof globalFocusedIndex !== "undefined" ? globalFocusedIndex : 0, 
        typeof categoryCount !== "undefined" ? categoryCount : 8, 
        2.0, 
        90.0, 
        _lastTargetAngle
    )

    onLayoutInfoChanged: {
        if (layoutInfo && layoutInfo.centerAngle !== undefined) {
            _lastTargetAngle = layoutInfo.centerAngle;
        }
    }

    property real centerAngle: layoutInfo.centerAngle
    property real currentWidth: layoutInfo.width
    property real startAngle: layoutInfo.startAngle
    property real endAngle: layoutInfo.endAngle
    
    Behavior on currentWidth {
        NumberAnimation { duration: Theme.durationSlow; easing.type: Easing.OutCubic }
    }
    Behavior on centerAngle {
        NumberAnimation { duration: Theme.durationSlow; easing.type: Easing.OutCubic }
    }
    Behavior on startAngle {
        NumberAnimation { duration: Theme.durationSlow; easing.type: Easing.OutCubic }
    }
    Behavior on endAngle {
        NumberAnimation { duration: Theme.durationSlow; easing.type: Easing.OutCubic }
    }
    
    property real wheelRotation: 0.0

    property bool isFocused: false
    property bool isSelected: false
    property bool isDimmed: false

    // We removed the aggressive 0.15 opacity dimming so the other 8 segments stay visible!
    opacity: 1.0

    // Centered icon coordinates along the radial sector ray using direct arithmetic
    readonly property real iconRadius: (root.baseInnerRadius + root.baseOuterRadius) / 2.0
    readonly property real iconRad: root.centerAngle * Math.PI / 180.0
    readonly property real iconCenterX: root.cx + root.iconRadius * Math.cos(root.iconRad)
    readonly property real iconCenterY: root.cy + root.iconRadius * Math.sin(root.iconRad)

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
            strokeWidth: 2.0
            strokeColor: root.isFocused ? Theme.gray50 : (root.isSelected ? Theme.acidGreen : "transparent")
            fillColor: (root.isFocused || root.isSelected) ? Theme.gray50 : "black"
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
                    root.baseInnerRadius,
                    root.baseOuterRadius,
                    root.startAngle,
                    root.endAngle
                )
            }
        }
    }

    // Centered Category Icon with Rotation Compensation
    Item {
        id: iconContainer
        x: root.iconCenterX - width / 2
        y: root.iconCenterY - height / 2
        width: 36
        height: 36

        // Counter-rotate by wheel rotation so icon stays strictly upright
        rotation: -root.wheelRotation

        CtosIcon {
            id: categoryIcon
            anchors.centerIn: parent
            size: 22
            name: root.iconName
            color: (root.isFocused || root.isSelected) ? "black" : Theme.gray300

            Behavior on color {
                ColorAnimation { duration: Theme.durationFast }
            }
        }

    }
}
