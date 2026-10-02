pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import "../../core"

// Card: a rounded tile with a header bar and a content area.
//
// Replaces the accordion the CCC was built from. An accordion is a disclosure
// control -- it hides its contents behind a click, which is the right model for
// a list you might not care about and the wrong model for a panel whose cards
// are all meant to be read at once. The design shows every card open.
//
// The header carries an icon in a tinted tile, a title, and one trailing
// control: a toggle, a button, or a disclosure chevron.

Item {
    id: root

    property string title: ""

    // Semantic glyph name, resolved by GlyphIcon. Empty hides the tile.
    property string icon: ""

    // Tints the icon tile and the chevron. Per-card so a card can signal what it
    // is without each one reaching for a colour directly.
    property color accent: Theme.accentBlue

    // Trailing interactive control. A Component so a card can pass any widget;
    // sized from the control's own implicit size so callers cannot desync the
    // layout from the content by guessing a width.
    property Component action: null

    property Component contentComponent: null

    // Disclosure state. A card with no collapsible body simply leaves these
    // alone -- expanded defaults true, so read-only cards need no thought.
    property bool collapsible: false
    property bool expanded: true

    signal headerClicked()

    // Header height tracks the icon tile plus padding, so raising the tile size
    // raises the header rather than clipping it.
    readonly property int headerHeight: Theme.cardIconTile + Theme.spacingSmall * 2
    readonly property int contentPadding: Theme.cardPadding

    readonly property real contentHeight: contentLoader.item
        ? (contentLoader.item.implicitHeight > 0
           ? contentLoader.item.implicitHeight
           : contentLoader.item.height)
        : 0

    implicitWidth: parent ? parent.width : undefined
    implicitHeight: headerHeight
                     + (contentHeight > 0 ? Theme.spacingSmall + contentHeight + contentPadding : 0)
    width: parent ? parent.width : undefined
    height: implicitHeight

    // Tile fill and border. The card sits a step above the panel behind it, so
    // it reads as a surface rather than as an outline drawn on the background.
    Rectangle {
        id: tile
        anchors.fill: parent
        radius: Theme.commandCenterSectionRadius
        color: Theme.surface
        border.width: Theme.borderWidth
        border.color: hoverArea.containsMouse ? Theme.borderHover : Theme.border
        visible: true

        Behavior on border.color {
            ColorAnimation {
                duration: Settings.reducedMotion ? 0 : Theme.durationFast
            }
        }
    }

    // ---------------------------------------------------------------- header

    Item {
        id: header
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: root.headerHeight

        // Icon tile: a tinted rounded square, which is what gives the card its
        // identity at a glance.
        Rectangle {
            id: iconTile
            anchors.left: parent.left
            anchors.leftMargin: Theme.cardPadding
            anchors.verticalCenter: parent.verticalCenter
            width: root.icon !== "" ? Theme.cardIconTile : 0
            height: width
            radius: Theme.radiusMedium
            color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.16)
            visible: width > 0

            GlyphIcon {
                anchors.centerIn: parent
                width: Theme.cardIconTile - Theme.spacingSmall * 2
                height: width
                glyph: root.icon
                color: root.accent
            }
        }

        Text {
            id: titleText
            anchors.left: iconTile.right
            anchors.leftMargin: root.icon !== "" ? Theme.spacingMedium : Theme.cardPadding
            anchors.right: trailing.left
            anchors.rightMargin: Theme.spacingSmall
            anchors.verticalCenter: parent.verticalCenter
            text: root.title
            color: Theme.textPrimary
            font.family: Theme.fontFamilySans
            font.pixelSize: Theme.fontSizeBody
            font.weight: Theme.fontWeightDemiBold
            elide: Text.ElideRight
        }

        // Trailing slot: the chevron when collapsible, otherwise whatever the
        // card passed as `action`.
        Item {
            id: trailing
            anchors.right: parent.right
            anchors.rightMargin: Theme.cardPadding
            anchors.verticalCenter: parent.verticalCenter
            width: trailingContent.width
            height: trailingContent.height

            Row {
                id: trailingContent
                anchors.centerIn: parent
                spacing: Theme.spacingSmall

                GlyphIcon {
                    visible: root.collapsible
                    width: Theme.spacing2Xl - Theme.spacingSmall
                    height: width
                    glyph: "chevron"
                    color: Theme.textSecondary
                    // Glyph draws pointing down. Expanded shows it unrotated
                    // (further down the card is visible), collapsed flips it up
                    // to indicate the card opens downward.
                    rotation: root.expanded ? 0 : 180

                    Behavior on rotation {
                        NumberAnimation {
                            duration: Settings.reducedMotion ? 0 : Theme.durationFast
                            easing.type: Easing.OutCubic
                        }
                    }
                }

                Loader {
                    visible: root.action !== null
                    width: visible ? implicitWidth : 0
                    height: visible ? implicitHeight : 0
                    sourceComponent: root.action
                }
            }
        }

        MouseArea {
            id: hoverArea
            anchors.fill: parent
            hoverEnabled: true
            enabled: root.collapsible
            // Only the chevron invites the click, so only the chevron takes it.
            // A card with a toggle in the header must not also toggle open when
            // that toggle is clicked, which is what a full-width MouseArea here
            // would do.
            acceptedButtons: root.collapsible ? Qt.LeftButton : Qt.NoButton
            onClicked: {
                root.expanded = !root.expanded;
                root.headerClicked();
            }
        }
    }

    // -------------------------------------------------------------- content

    Item {
        id: contentArea
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: header.bottom
        anchors.leftMargin: Theme.cardPadding
        anchors.rightMargin: Theme.cardPadding
        // Collapsed cards keep their header height, so the content is hidden
        // rather than the card collapsing to nothing.
        height: root.expanded && root.contentHeight > 0
               ? root.contentHeight
               : 0
        clip: true
        visible: height > 0

        Behavior on height {
            NumberAnimation {
                duration: Settings.reducedMotion ? 0 : Theme.durationFast
                easing.type: Easing.OutCubic
            }
        }

        Loader {
            id: contentLoader
            width: parent ? parent.width : undefined
            sourceComponent: root.expanded ? root.contentComponent : null
        }
    }
}