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

    // Optional dim second line in the header, for the card's headline state
    // rather than a value that belongs in the body.
    property string subtitle: ""

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

    // Disclosure state. A card owns this and toggles it itself on a header
    // click; callers should not bind it, because a binding here is silently
    // destroyed by that first click. To open a card programmatically, assign to
    // it after construction rather than binding.
    property bool collapsible: false
    property bool expanded: true

    signal headerClicked()

    // Header height tracks the icon tile plus padding, so raising the tile size
    // raises the header rather than clipping it.
    readonly property int headerHeight: Theme.cardIconTile + Theme.spacingSmall * 2
// Vertical insets, inside the card.
//
// The card had none at all above the header and twelve below the content, so the
// heading sat against the top border while the body ended in a pool of slack --
// top-tight and bottom-heavy. topInset opens the top edge; contentPadding trims
// the bottom.
//
// 12 + 4 is the sixteen the card already reserved, so every card keeps its exact
// height. That is the whole reason for the split: the left column had ~3px of
// slack against the panel cap, and an earlier attempt that added 8 above while
// leaving 12 below pushed System Status past the cap and sliced its rings in
// half.
//
// Collapsed cards have no content below the header, so they take the top inset
// mirrored underneath instead of a 4px stub -- otherwise a collapsed card would
// be the only one in the column sitting off-centre.
readonly property int topInset: Theme.cardPadding
    readonly property int contentPadding: Theme.spacingSmall

    readonly property real contentHeight: contentLoader.item
        ? (contentLoader.item.implicitHeight > 0
           ? contentLoader.item.implicitHeight
           : contentLoader.item.height)
        : 0

    implicitWidth: parent ? parent.width : undefined
    implicitHeight: topInset + headerHeight
                     + (contentHeight > 0 ? contentHeight + contentPadding : topInset)
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
        // The inset lives here: between the card's top edge and the heading.
        anchors.topMargin: root.topInset
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

        // Title, with an optional dim second line for state ("85% - Charging").
        Column {
            id: titleStack
            anchors.left: iconTile.right
            anchors.leftMargin: root.icon !== "" ? Theme.spacingMedium : Theme.cardPadding
            anchors.right: trailing.left
            anchors.rightMargin: Theme.spacingSmall
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1

            Text {
                id: titleText
                width: parent.width
                text: root.title
                color: Theme.textPrimary
                font.family: Theme.fontFamilySans
                font.pixelSize: Theme.fontSizeBody
                font.weight: Theme.fontWeightDemiBold
                elide: Text.ElideRight
            }

            Text {
                width: parent.width
                visible: root.subtitle !== ""
                text: root.subtitle
                color: Theme.textSecondary
                font.family: Theme.fontFamilySans
                font.pixelSize: Theme.fontSizeCaption
                elide: Text.ElideRight
            }
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
                      id: chevronIcon
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

                    // Lives inside the icon rather than in the header beside it.
                    // Anchors only resolve against a parent or a sibling, and the
                    // header MouseArea is a sibling of `trailing` -- the icon is
                    // three levels below that, inside trailingContent. Anchoring
                    // across that gap is silently discarded: the area kept its
                    // size but fell back to the header's origin, so the top-left
                    // corner of every card toggled it. Filling the parent needs
                    // no anchor at all, so there is nothing to get wrong.
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: root.collapsible
                        acceptedButtons: root.collapsible ? Qt.LeftButton : Qt.NoButton
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.expanded = !root.expanded;
                            root.headerClicked();
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
              anchors.left: parent.left
              anchors.top: parent.top
              anchors.bottom: parent.bottom
              // Stops short of the trailing slot rather than filling the header.
              // That slot holds the chevron and any `action`, which for the Wi-Fi
              // and Bluetooth cards is the on/off ToggleSwitch. Filling the header
              // swallowed clicks on those switches: the click collapsed the card
              // instead of toggling Wi-Fi or Bluetooth, so every header control in
              // the panel looked dead.
              anchors.right: trailing.left
              anchors.rightMargin: Theme.spacingSmall
              hoverEnabled: true
              enabled: root.collapsible
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
        // Flush under the heading: the gap between the card's top edge and the
        // heading is topInset's job, and doubling it up here is what left the
        // content marooned in the middle of the card.
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