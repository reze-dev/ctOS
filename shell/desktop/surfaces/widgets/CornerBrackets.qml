import QtQuick
import "../../core"

Item {
    id: root

    // =========================================================================
    // Public Properties adhering to Theme tokens
    // =========================================================================

    property color bracketColor: Theme.acidGreen
    property alias color: root.bracketColor
    property int armLength: Theme.cornerBracketArmLength
    property int thickness: Theme.cornerBracketThickness
    property int margin: Theme.cornerBracketMargin
    property alias bracketMargin: root.margin

    anchors.fill: parent
    z: 10

    // Top-Left Corner
    Rectangle {
        x: root.margin
        y: root.margin
        width: root.armLength
        height: root.thickness
        color: root.bracketColor
    }
    Rectangle {
        x: root.margin
        y: root.margin
        width: root.thickness
        height: root.armLength
        color: root.bracketColor
    }

    // Top-Right Corner
    Rectangle {
        x: root.width - root.margin - root.armLength
        y: root.margin
        width: root.armLength
        height: root.thickness
        color: root.bracketColor
    }
    Rectangle {
        x: root.width - root.margin - root.thickness
        y: root.margin
        width: root.thickness
        height: root.armLength
        color: root.bracketColor
    }

    // Bottom-Left Corner
    Rectangle {
        x: root.margin
        y: root.height - root.margin - root.thickness
        width: root.armLength
        height: root.thickness
        color: root.bracketColor
    }
    Rectangle {
        x: root.margin
        y: root.height - root.margin - root.armLength
        width: root.thickness
        height: root.armLength
        color: root.bracketColor
    }

    // Bottom-Right Corner
    Rectangle {
        x: root.width - root.margin - root.armLength
        y: root.height - root.margin - root.thickness
        width: root.armLength
        height: root.thickness
        color: root.bracketColor
    }
    Rectangle {
        x: root.width - root.margin - root.thickness
        y: root.height - root.margin - root.armLength
        width: root.thickness
        height: root.armLength
        color: root.bracketColor
    }
}
