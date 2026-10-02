import QtQuick
import QtQuick.Shapes

import "../../core"

// Hexagon mark: the shell's identity glyph.
//
// Drawn rather than shipped as an SVG. A static asset bakes its colours in, so
// it could never follow the palette; a hexagon is also the worst case for
// bitmap scaling, since every edge is diagonal and the notch animates. And a
// coloured asset is another colour that stops routing through Theme.
//
// Shape/ShapePath rather than Polygon or a gradient stroke, because those are
// the primitives this codebase already draws vector work with and they resolve
// here. ShapeLinearGradient and Polygon do not, and a blue-to-violet sweep is
// not perceptible at 18px anyway.
//
// Replaces os-icon.svg, which was a diamond where the design specifies a
// hexagon.
Item {
    id: root

    // Circumradius as a fraction of the shorter side.
    property real radiusRatio: 0.48
    readonly property real hexRadius: Math.min(width, height) * root.radiusRatio

    // Inset of the inner hexagon, i.e. half the ring thickness.
    property real ringThicknessRatio: 0.17
    readonly property real ringInset: root.hexRadius * root.ringThicknessRatio

    property color ringColor: Theme.accentBlue
    property color surfaceColor: Theme.notchSurface
    property color coreColor: Theme.accentMagenta
    property bool showCore: true

    // Six vertices of a pointy-top regular hexagon, clockwise from the top.
    // Properties rather than functions so the ShapePaths re-evaluate only when
    // the size actually changes.
    readonly property var outerVerts: _hexVerts(root.hexRadius)
    readonly property var innerVerts: _hexVerts(root.hexRadius - root.ringInset)

    function _hexVerts(r) {
        const cx = width / 2;
        const cy = height / 2;
        const out = [];
        for (let i = 0; i < 6; ++i) {
            const a = (-90 + i * 60) * Math.PI / 180;
            out.push(cx + r * Math.cos(a));
            out.push(cy + r * Math.sin(a));
        }
        return out;
    }

    // Outer: the coloured ring.
    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.GeometryRenderer
        antialiasing: true

        ShapePath {
            fillColor: root.ringColor
            startX: root.outerVerts[0]
            startY: root.outerVerts[1]
            PathLine { x: root.outerVerts[2];  y: root.outerVerts[3] }
            PathLine { x: root.outerVerts[4];  y: root.outerVerts[5] }
            PathLine { x: root.outerVerts[6];  y: root.outerVerts[7] }
            PathLine { x: root.outerVerts[8];  y: root.outerVerts[9] }
            PathLine { x: root.outerVerts[10]; y: root.outerVerts[11] }
        }
    }

    // Inner: punches the surface back out, leaving the ring.
    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.GeometryRenderer
        antialiasing: true

        ShapePath {
            fillColor: root.surfaceColor
            startX: root.innerVerts[0]
            startY: root.innerVerts[1]
            PathLine { x: root.innerVerts[2];  y: root.innerVerts[3] }
            PathLine { x: root.innerVerts[4];  y: root.innerVerts[5] }
            PathLine { x: root.innerVerts[6];  y: root.innerVerts[7] }
            PathLine { x: root.innerVerts[8];  y: root.innerVerts[9] }
            PathLine { x: root.innerVerts[10]; y: root.innerVerts[11] }
        }
    }

    // Core, so the mark still reads at 14px where the ring is barely two
    // pixels wide.
    Rectangle {
        visible: root.showCore && root.hexRadius > 4
        width: Math.max(2, root.hexRadius * 0.52)
        height: width
        radius: width / 2
        anchors.centerIn: parent
        color: root.coreColor
    }
}
