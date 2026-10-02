pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import "../../core"

// Functional glyphs, drawn on a 24x24 grid.
//
// Why this exists rather than reusing CtosIcon: CtosIcon answers "which app is
// this?", mapping application names onto brand marks (kitty, zed, obsidian). The
// CCC was passing it category words -- "timer", "power", "volume", "bluetooth" --
// for which it has no entries, which is why those header icons were blank or
// resolved to whatever matched first. An icon slot wants functional glyphs.
//
// Drawn rather than shipped as assets, for the reasons HexMark sets out: a
// baked asset cannot follow the palette, and every glyph here is also a recolour
// per card accent.
//
// Curves are quadratics rather than arcs. An exact circular arc needs start
// angle, sweep and bounding box to be reasoned about together; a quadratic
// through two endpoints and a control point is one line of arithmetic, and at
// the 14-20px these render at the difference is not visible.
//
// Selection is by `visible` on each Shape rather than by loading a Component.
// Loading was tried first -- one Loader whose sourceComponent came from a
// function that mapped name to Component. It renders correctly when the
// function is called with a literal, and renders nothing when it is bound to
// the instance's own `name`: the binding evaluates once during construction,
// before `name` is assigned, and is never re-evaluated. A direct
// `visible: root.glyph === "..."` is re-evaluated when name changes, which is
// what makes this work at all.
//
// The cost is that all twelve Shapes are constructed per icon rather than one.
// They are invisible when they do not match, so only the matching one is
// rendered.

Item {
    id: root

    // One of: bell, wifi, bluetooth, speaker, calendar, sliders, power, lock,
    // logout, reboot, battery, chevron.
    //
    // Named `glyph` rather than `name`: a property called `name` on a reusable
    // component invites collision with the ambient identifiers every QML
    // caller has in scope, and assigning it from the outside had no effect --
    // the glyph stayed blank with every shape's `visible` comparing false.
    property string glyph: ""

    property color color: Theme.textPrimary

    // Stroke weight in grid units. Glyphs are mostly strokes, so this is the
    // single dial that makes a set look consistent with itself.
    property real strokeWidth: 2

    implicitWidth: 20
    implicitHeight: implicitWidth

    readonly property real gridScale: width / 24

    Item {
        width: 24
        height: 24
        anchors.centerIn: parent
        // Scaled about its own centre, so every glyph below can be written in
        // 24-unit coordinates without knowing the rendered size.
        scale: root.gridScale


    // =========================================================== glyph set

    Shape {
        anchors.fill: parent
        visible: root.glyph === "bell"
            preferredRendererType: Shape.GeometryRenderer
            antialiasing: true

            // Dome and skirt.
            ShapePath {
                fillColor: root.color
                strokeColor: "transparent"
                startX: 6.5; startY: 17.5
                PathLine { x: 6.5;  y: 13 }
                PathQuad  { x: 6.5;  y: 7.5;  controlX: 12;   controlY: 5 }
                PathQuad  { x: 17.5; y: 13;   controlX: 12;   controlY: 5 }
                PathLine  { x: 17.5; y: 17.5 }
                PathLine { x: 6.5; y: 17.5 }
            }
            // Clapper.
            ShapePath {
                fillColor: "transparent"
                strokeColor: root.color
                strokeWidth: root.strokeWidth
                capStyle: ShapePath.RoundCap
                startX: 10; startY: 19.5
                PathQuad { x: 14; y: 19.5; controlX: 12; controlY: 22 }
            }
        
    }

    Shape {
        anchors.fill: parent
        visible: root.glyph === "wifi"
            preferredRendererType: Shape.GeometryRenderer
            antialiasing: true

            // Two nested arcs opening downward, plus the dot.
            ShapePath {
                fillColor: "transparent"
                strokeColor: root.color
                strokeWidth: root.strokeWidth
                capStyle: ShapePath.RoundCap
                startX: 3.5; startY: 13.5
                PathQuad { x: 20.5; y: 13.5; controlX: 12; controlY: 4 }
            }
            ShapePath {
                fillColor: "transparent"
                strokeColor: root.color
                strokeWidth: root.strokeWidth
                capStyle: ShapePath.RoundCap
                startX: 7; startY: 17
                PathQuad { x: 17; y: 17; controlX: 12; controlY: 11 }
            }
            ShapePath {
                fillColor: root.color
                strokeColor: "transparent"
                startX: 10.1; startY: 22
                PathLine { x: 13.9; y: 22 }
                PathQuad { x: 10.1; y: 18.1; controlX: 12; controlY: 20.4 }
                PathLine { x: 10.1; y: 22 }
            }
        
    }

    Shape {
        anchors.fill: parent
        visible: root.glyph === "bluetooth"
            preferredRendererType: Shape.GeometryRenderer
            antialiasing: true

            // The rune is one continuous polyline: down the spine, out to a
            // corner, back to the middle, up the spine, out to the other corner.
            // Drawn as a single path so the joins are mitred, not stacked caps.
            ShapePath {
                fillColor: "transparent"
                strokeColor: root.color
                strokeWidth: root.strokeWidth
                joinStyle: ShapePath.MiterJoin
                capStyle: ShapePath.RoundCap
                startX: 7; startY: 7.5
                PathLine { x: 17;   y: 16.5 }
                PathLine { x: 12;   y: 21.5 }
                PathLine { x: 12;   y: 2.5 }
                PathLine { x: 17;   y: 7.5 }
                PathLine { x: 7;    y: 16.5 }
            }
        
    }

    Shape {
        anchors.fill: parent
        visible: root.glyph === "speaker"
            preferredRendererType: Shape.GeometryRenderer
            antialiasing: true

            // Cone.
            ShapePath {
                fillColor: root.color
                strokeColor: "transparent"
                startX: 3; startY: 9
                PathLine { x: 7;  y: 9 }
                PathLine { x: 13; y: 4 }
                PathLine { x: 13; y: 20 }
                PathLine { x: 7;  y: 15 }
                PathLine { x: 3;  y: 15 }
                PathLine { x: 3; y: 9 }
            }
            // Two wavefronts.
            ShapePath {
                fillColor: "transparent"
                strokeColor: root.color
                strokeWidth: root.strokeWidth
                capStyle: ShapePath.RoundCap
                startX: 16; startY: 9.5
                PathQuad { x: 16; y: 14.5; controlX: 19.5; controlY: 12 }
            }
            ShapePath {
                fillColor: "transparent"
                strokeColor: root.color
                strokeWidth: root.strokeWidth
                capStyle: ShapePath.RoundCap
                startX: 18.5; startY: 6.5
                PathQuad { x: 18.5; y: 17.5; controlX: 23; controlY: 12 }
            }
        
    }

    Shape {
        anchors.fill: parent
        visible: root.glyph === "calendar"
            preferredRendererType: Shape.GeometryRenderer
            antialiasing: true

            // Body outline.
            ShapePath {
                fillColor: "transparent"
                strokeColor: root.color
                strokeWidth: root.strokeWidth
                joinStyle: ShapePath.MiterJoin
                startX: 3; startY: 5.5
                PathLine { x: 21; y: 5.5 }
                PathLine { x: 21; y: 21 }
                PathLine { x: 3;  y: 21 }
            }
            // Filled header band.
            ShapePath {
                fillColor: root.color
                strokeColor: "transparent"
                startX: 4.2; startY: 6.7
                PathLine { x: 19.8; y: 6.7 }
                PathLine { x: 19.8; y: 10 }
                PathLine { x: 4.2;  y: 10 }
                PathLine { x: 4.2; y: 6.7 }
            }
            // Hangers.
            ShapePath {
                fillColor: "transparent"
                strokeColor: root.color
                strokeWidth: root.strokeWidth
                capStyle: ShapePath.RoundCap
                startX: 8; startY: 3
                PathLine { x: 8;  y: 7 }
            }
            ShapePath {
                fillColor: "transparent"
                strokeColor: root.color
                strokeWidth: root.strokeWidth
                capStyle: ShapePath.RoundCap
                startX: 16; startY: 3
                PathLine { x: 16; y: 7 }
            }
            // Day markers.
            ShapePath {
                fillColor: root.color
                strokeColor: "transparent"
                startX: 7;    startY: 13
                PathLine { x: 8.4; y: 13 }
                PathLine { x: 8.4; y: 18 }
                PathLine { x: 7;    y: 18 }
                PathLine { x: 7; y: 13 }
            }
            ShapePath {
                fillColor: root.color
                strokeColor: "transparent"
                startX: 11.3; startY: 13
                PathLine { x: 12.7; y: 13 }
                PathLine { x: 12.7; y: 18 }
                PathLine { x: 11.3; y: 18 }
                PathLine { x: 11.3; y: 13 }
            }
            ShapePath {
                fillColor: root.color
                strokeColor: "transparent"
                startX: 15.6; startY: 13
                PathLine { x: 17;   y: 13 }
                PathLine { x: 17;   y: 18 }
                PathLine { x: 15.6; y: 18 }
                PathLine { x: 15.6; y: 13 }
            }
        
    }

    Shape {
        anchors.fill: parent
        visible: root.glyph === "sliders"
            preferredRendererType: Shape.GeometryRenderer
            antialiasing: true

            // Three rails.
            ShapePath {
                fillColor: "transparent"
                strokeColor: root.color
                strokeWidth: root.strokeWidth
                capStyle: ShapePath.RoundCap
                startX: 3; startY: 7
                PathLine { x: 21; y: 7 }
            }
            ShapePath {
                fillColor: "transparent"
                strokeColor: root.color
                strokeWidth: root.strokeWidth
                capStyle: ShapePath.RoundCap
                startX: 3; startY: 12
                PathLine { x: 21; y: 12 }
            }
            ShapePath {
                fillColor: "transparent"
                strokeColor: root.color
                strokeWidth: root.strokeWidth
                capStyle: ShapePath.RoundCap
                startX: 3; startY: 17
                PathLine { x: 21; y: 17 }
            }
            // Knobs at staggered positions, so the glyph reads as three
            // independent channels rather than a single slider repeated.
            ShapePath {
                fillColor: root.color
                strokeColor: "transparent"
                startX: 6; startY: 4.6
                PathLine { x: 9.4; y: 4.6 }
                PathLine { x: 9.4; y: 9.4 }
                PathLine { x: 6;   y: 9.4 }
                PathLine { x: 6; y: 4.6 }
            }
            ShapePath {
                fillColor: root.color
                strokeColor: "transparent"
                startX: 13; startY: 9.6
                PathLine { x: 16.4; y: 9.6 }
                PathLine { x: 16.4; y: 14.4 }
                PathLine { x: 13;   y: 14.4 }
                PathLine { x: 13; y: 9.6 }
            }
            ShapePath {
                fillColor: root.color
                strokeColor: "transparent"
                startX: 9; startY: 14.6
                PathLine { x: 12.4; y: 14.6 }
                PathLine { x: 12.4; y: 19.4 }
                PathLine { x: 9;    y: 19.4 }
                PathLine { x: 9; y: 14.6 }
            }
        
    }

    Shape {
        anchors.fill: parent
        visible: root.glyph === "power"
        preferredRendererType: Shape.GeometryRenderer
        antialiasing: true

        // Three quarters of a ring, open across the top. Four quads through the
        // cardinal points of a circle of radius 7 centred on (12,12).
        ShapePath {
            fillColor: "transparent"
            strokeColor: root.color
            strokeWidth: root.strokeWidth
            capStyle: ShapePath.RoundCap
            startX: 7.05; startY: 7.05
            PathQuad { x: 5;    y: 12;   controlX: 5;     controlY: 7.05 }
            PathQuad { x: 12;   y: 19;   controlX: 5;     controlY: 19 }
            PathQuad { x: 19;   y: 12;   controlX: 19;    controlY: 19 }
            PathQuad { x: 16.95; y: 7.05; controlX: 19;    controlY: 7.05 }
        }
        // Stem, running out through the gap.
        ShapePath {
            fillColor: "transparent"
            strokeColor: root.color
            strokeWidth: root.strokeWidth
            capStyle: ShapePath.RoundCap
            startX: 12; startY: 3.4
            PathLine { x: 12; y: 11.8 }
        }
    }


    Shape {
        anchors.fill: parent
        visible: root.glyph === "lock"
            preferredRendererType: Shape.GeometryRenderer
            antialiasing: true

            // Shackle.
            ShapePath {
                fillColor: "transparent"
                strokeColor: root.color
                strokeWidth: root.strokeWidth
                capStyle: ShapePath.RoundCap
                startX: 7.6; startY: 10.6
                PathLine { x: 7.6;  y: 8.4 }
                PathQuad { x: 16.4; y: 8.4;  controlX: 16.4; controlY: 4.6 }
                PathLine { x: 16.4; y: 10.6 }
            }
            // Body.
            ShapePath {
                fillColor: root.color
                strokeColor: "transparent"
                startX: 4.6; startY: 10.6
                PathLine { x: 19.4; y: 10.6 }
                PathLine { x: 19.4; y: 20.4 }
                PathLine { x: 4.6;  y: 20.4 }
                PathLine { x: 4.6; y: 10.6 }
            }
            // Keyhole.
            ShapePath {
                fillColor: Theme.background
                strokeColor: "transparent"
                startX: 10.8; startY: 13.6
                PathLine { x: 13.2; y: 13.6 }
                PathLine { x: 13.2; y: 17.6 }
                PathLine { x: 10.8; y: 17.6 }
                PathLine { x: 10.8; y: 13.6 }
            }
        
    }

    Shape {
        anchors.fill: parent
        visible: root.glyph === "logout"
            preferredRendererType: Shape.GeometryRenderer
            antialiasing: true

            // Bracket.
            ShapePath {
                fillColor: "transparent"
                strokeColor: root.color
                strokeWidth: root.strokeWidth
                joinStyle: ShapePath.MiterJoin
                capStyle: ShapePath.RoundCap
                startX: 13; startY: 5
                PathLine { x: 5;  y: 5 }
                PathLine { x: 5;  y: 19 }
                PathLine { x: 13; y: 19 }
            }
            // Shaft and head.
            ShapePath {
                fillColor: "transparent"
                strokeColor: root.color
                strokeWidth: root.strokeWidth
                joinStyle: ShapePath.MiterJoin
                capStyle: ShapePath.RoundCap
                startX: 10; startY: 12
                PathLine { x: 20; y: 12 }
            }
            ShapePath {
                fillColor: "transparent"
                strokeColor: root.color
                strokeWidth: root.strokeWidth
                joinStyle: ShapePath.MiterJoin
                capStyle: ShapePath.RoundCap
                startX: 16.4; startY: 8.4
                PathLine { x: 20;    y: 12 }
                PathLine { x: 16.4; y: 15.6 }
            }
        
    }

    Shape {
        anchors.fill: parent
        visible: root.glyph === "reboot"
        preferredRendererType: Shape.GeometryRenderer
        antialiasing: true

        // Arc of a circle of radius 7 centred on (12,12), left open across the
        // top so the head has somewhere to point out of.
        ShapePath {
            fillColor: "transparent"
            strokeColor: root.color
            strokeWidth: root.strokeWidth
            capStyle: ShapePath.RoundCap
            startX: 7.05; startY: 7.05
            PathQuad { x: 5;    y: 12;   controlX: 5;     controlY: 7.05 }
            PathQuad { x: 12;   y: 19;   controlX: 5;     controlY: 19 }
            PathQuad { x: 19;   y: 12;   controlX: 19;    controlY: 19 }
            PathQuad { x: 16.95; y: 7.05; controlX: 19;    controlY: 7.05 }
        }
        // Head at the open end of the arc, pointing up and out.
        ShapePath {
            fillColor: root.color
            strokeColor: "transparent"
            startX: 13.4; startY: 4.6
            PathLine { x: 22.6; y: 3.4 }
            PathLine { x: 20.6; y: 12.6 }
            PathLine { x: 13.4; y: 4.6 }
        }
    }


    Shape {
        anchors.fill: parent
        visible: root.glyph === "battery"
            preferredRendererType: Shape.GeometryRenderer
            antialiasing: true

            // Case.
            ShapePath {
                fillColor: "transparent"
                strokeColor: root.color
                strokeWidth: root.strokeWidth
                joinStyle: ShapePath.MiterJoin
                startX: 2; startY: 8
                PathLine { x: 19;  y: 8 }
                PathLine { x: 19;  y: 16 }
                PathLine { x: 2;   y: 16 }
            }
            // Nub.
            ShapePath {
                fillColor: root.color
                strokeColor: "transparent"
                startX: 20; startY: 10.5
                PathLine { x: 22;  y: 10.5 }
                PathLine { x: 22;  y: 13.5 }
                PathLine { x: 20;  y: 13.5 }
                PathLine { x: 20; y: 10.5 }
            }
            // Charge level, fixed at roughly three quarters: a glyph cannot show
            // a live level, and an empty case next to a real percentage readout
            // would be a second, contradicting answer to the same question.
            ShapePath {
                fillColor: root.color
                strokeColor: "transparent"
                startX: 4; startY: 10
                PathLine { x: 14; y: 10 }
                PathLine { x: 14; y: 14 }
                PathLine { x: 4;  y: 14 }
                PathLine { x: 4; y: 10 }
            }
        
    }

    Shape {
        anchors.fill: parent
        visible: root.glyph === "chevron"
            preferredRendererType: Shape.GeometryRenderer
            antialiasing: true

            ShapePath {
                fillColor: "transparent"
                strokeColor: root.color
                strokeWidth: root.strokeWidth
                joinStyle: ShapePath.MiterJoin
                capStyle: ShapePath.RoundCap
                startX: 7; startY: 10.5
                PathLine { x: 12; y: 15.5 }
                PathLine { x: 17; y: 10.5 }
            }
        
    }
    }
}