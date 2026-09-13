pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import "../core"
import "../services"
import "./components"

FocusScope {
    id: root

    implicitWidth: 360
    width: 360
    anchors.bottom: parent ? parent.bottom : undefined
    anchors.top: parent ? parent.top : undefined
    focus: true

    // Keyboard navigation focus & Tiered Escape trapping
    Keys.onEscapePressed: function (event) {
        OverlayController.close();
        if (event) {
            event.accepted = true;
        }
    }

    // Synchronize active focus when opened by OverlayController
    Connections {
        target: OverlayController

        function onOverlayOpened(surface: int): void {
            if (surface === OverlayController.Surface.EventLog) {
                root.forceActiveFocus();
            }
        }
    }

    Component.onCompleted: {
        if (OverlayController.activeSurface === OverlayController.Surface.EventLog) {
            root.forceActiveFocus();
        }
    }

    // Background container
    Rectangle {
        id: panelBackground
        anchors.fill: parent
        color: Theme.gray900
        border.color: Theme.borderMuted
        border.width: Theme.borderWidth
    }

    // Corner Brackets decoration (cyber aesthetic)
    Item {
        id: cornerBrackets
        anchors.fill: parent
        z: 10

        readonly property color bracketColor: Theme.acidGreen

        // Top-Left
        Rectangle {
            x: Theme.cornerBracketMargin
            y: Theme.cornerBracketMargin
            width: Theme.cornerBracketArmLength
            height: Theme.cornerBracketThickness
            color: cornerBrackets.bracketColor
        }
        Rectangle {
            x: Theme.cornerBracketMargin
            y: Theme.cornerBracketMargin
            width: Theme.cornerBracketThickness
            height: Theme.cornerBracketArmLength
            color: cornerBrackets.bracketColor
        }

        // Top-Right
        Rectangle {
            x: parent.width - Theme.cornerBracketMargin - Theme.cornerBracketArmLength
            y: Theme.cornerBracketMargin
            width: Theme.cornerBracketArmLength
            height: Theme.cornerBracketThickness
            color: cornerBrackets.bracketColor
        }
        Rectangle {
            x: parent.width - Theme.cornerBracketMargin - Theme.cornerBracketThickness
            y: Theme.cornerBracketMargin
            width: Theme.cornerBracketThickness
            height: Theme.cornerBracketArmLength
            color: cornerBrackets.bracketColor
        }

        // Bottom-Left
        Rectangle {
            x: Theme.cornerBracketMargin
            y: parent.height - Theme.cornerBracketMargin - Theme.cornerBracketThickness
            width: Theme.cornerBracketArmLength
            height: Theme.cornerBracketThickness
            color: cornerBrackets.bracketColor
        }
        Rectangle {
            x: Theme.cornerBracketMargin
            y: parent.height - Theme.cornerBracketMargin - Theme.cornerBracketArmLength
            width: Theme.cornerBracketThickness
            height: Theme.cornerBracketArmLength
            color: cornerBrackets.bracketColor
        }

        // Bottom-Right
        Rectangle {
            x: parent.width - Theme.cornerBracketMargin - Theme.cornerBracketArmLength
            y: parent.height - Theme.cornerBracketMargin - Theme.cornerBracketThickness
            width: Theme.cornerBracketArmLength
            height: Theme.cornerBracketThickness
            color: cornerBrackets.bracketColor
        }
        Rectangle {
            x: parent.width - Theme.cornerBracketMargin - Theme.cornerBracketThickness
            y: parent.height - Theme.cornerBracketMargin - Theme.cornerBracketArmLength
            width: Theme.cornerBracketThickness
            height: Theme.cornerBracketArmLength
            color: cornerBrackets.bracketColor
        }
    }

    // Inside Click Consumer
    MouseArea {
        id: insideClickConsumer
        anchors.fill: parent
        hoverEnabled: true
        preventStealing: true
        onClicked: function (mouse) {
            mouse.accepted = true;
        }
    }

    // Main Content Column
    ColumnLayout {
        id: mainLayout
        anchors.fill: parent
        anchors.margins: Theme.paddingXl
        spacing: Theme.spacingMedium

        // Header Row
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingMedium

            Rectangle {
                Layout.preferredHeight: 8
                Layout.preferredWidth: 8
                color: Theme.accent
                radius: 4
            }

            Text {
                Layout.fillWidth: true
                color: Theme.accent
                font.family: Theme.fontFamilyMonospace
                font.pixelSize: Theme.fontSizeSegment
                font.weight: Theme.fontWeightBold
                text: "// EVENT LOG"
            }

            // DND Toggle Button
            Rectangle {
                id: dndButton
                Layout.preferredHeight: 24
                Layout.preferredWidth: dndLabel.implicitWidth + Theme.paddingMedium * 2
                border.color: NotificationService.doNotDisturb ? Theme.warningRed : (dndMouseArea.containsMouse ? Theme.accent : Theme.borderMuted)
                border.width: Theme.borderWidth
                color: NotificationService.doNotDisturb ? Theme.surfaceSelected : (dndMouseArea.containsMouse ? Theme.surfaceHover : "transparent")
                radius: Theme.radiusSmall

                Text {
                    id: dndLabel
                    anchors.centerIn: parent
                    color: NotificationService.doNotDisturb ? Theme.warningRed : (dndMouseArea.containsMouse ? Theme.accent : Theme.textSecondary)
                    font.family: Theme.fontFamilyMonospace
                    font.pixelSize: Theme.fontSizeCaption
                    font.weight: Theme.fontWeightBold
                    text: NotificationService.doNotDisturb ? "[DND]" : "[DND OFF]"
                }

                MouseArea {
                    id: dndMouseArea
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    onClicked: NotificationService.toggleDnd()
                }
            }

            // Close Button
            Rectangle {
                id: closeButton
                Layout.preferredHeight: 24
                Layout.preferredWidth: 24
                border.color: closeMouseArea.containsMouse ? Theme.accent : Theme.borderMuted
                border.width: Theme.borderWidth
                color: closeMouseArea.containsMouse ? Theme.surfaceHover : "transparent"
                radius: Theme.radiusSmall

                Text {
                    anchors.centerIn: parent
                    color: closeMouseArea.containsMouse ? Theme.accent : Theme.textSecondary
                    font.family: Theme.fontFamilyMonospace
                    font.pixelSize: Theme.fontSizeCaption
                    font.weight: Theme.fontWeightBold
                    text: "x"
                }

                MouseArea {
                    id: closeMouseArea
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    onClicked: OverlayController.close()
                }
            }
        }

        // Header Divider
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: Theme.borderWidth
            color: Theme.borderMuted
        }

        // Body Content Area (ListView or Empty State)
        Item {
            id: contentContainer
            Layout.fillWidth: true
            Layout.fillHeight: true

            // Notification History ListView
            ListView {
                id: historyListView
                anchors.fill: parent
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                spacing: Theme.spacingSmall
                model: NotificationService.history
                visible: NotificationService.history.count > 0

                delegate: Rectangle {
                    id: cardItem
                    required property int index
                    required property var notifId
                    required property string appName
                    required property string summary
                    required property string body
                    required property int urgency
                    required property string timestamp

                    width: historyListView.width
                    implicitHeight: cardLayout.implicitHeight + Theme.paddingMedium * 2
                    color: Theme.gray800
                    border.color: Theme.gray700
                    border.width: Theme.borderWidth
                    radius: Theme.radiusSmall

                    readonly property color urgencyColor: {
                        if (cardItem.urgency === 2) {
                            return Theme.warningRed;
                        }
                        if (cardItem.urgency === 0) {
                            return Theme.textMuted;
                        }
                        return Theme.acidGreen;
                    }

                    // Urgency accent stripe on left edge
                    Rectangle {
                        id: urgencyStripe
                        anchors.bottom: parent.bottom
                        anchors.left: parent.left
                        anchors.top: parent.top
                        color: cardItem.urgencyColor
                        radius: Theme.radiusSmall
                        width: 3
                    }

                    ColumnLayout {
                        id: cardLayout
                        anchors.left: urgencyStripe.right
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: Theme.paddingMedium
                        spacing: Theme.spacingSmall

                        // Header line: Urgency Dot, App Name (left), Timestamp (right)
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Theme.spacingSmall

                            Rectangle {
                                Layout.preferredHeight: 6
                                Layout.preferredWidth: 6
                                color: cardItem.urgencyColor
                                radius: 3
                            }

                            Text {
                                Layout.fillWidth: true
                                color: Theme.textSecondary
                                elide: Text.ElideRight
                                font.family: Theme.fontFamilyMonospace
                                font.pixelSize: Theme.fontSizeCaption
                                font.weight: Theme.fontWeightMedium
                                text: cardItem.appName.toUpperCase()
                            }

                            Text {
                                color: Theme.textMuted
                                font.family: Theme.fontFamilyMonospace
                                font.pixelSize: Theme.fontSizeCaption
                                text: cardItem.timestamp
                            }
                        }

                        // Summary text
                        Text {
                            Layout.fillWidth: true
                            color: Theme.textPrimary
                            elide: Text.ElideRight
                            font.family: Theme.fontFamilyMonospace
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: Theme.fontWeightBold
                            text: cardItem.summary
                        }

                        // Body text (word wrap, max 3 lines, elide)
                        Text {
                            Layout.fillWidth: true
                            color: Theme.textSecondary
                            elide: Text.ElideRight
                            font.family: Theme.fontFamilyMonospace
                            font.pixelSize: Theme.fontSizeCaption
                            maximumLineCount: 3
                            text: cardItem.body
                            visible: cardItem.body !== ""
                            wrapMode: Text.WordWrap
                        }

                        // Dismiss action button
                        RowLayout {
                            Layout.fillWidth: true

                            Item {
                                Layout.fillWidth: true
                            }

                            Rectangle {
                                id: dismissBtn
                                Layout.preferredHeight: 20
                                Layout.preferredWidth: dismissText.implicitWidth + Theme.paddingSmall * 2
                                border.color: dismissMouseArea.containsMouse ? Theme.accent : Theme.borderMuted
                                border.width: Theme.borderWidth
                                color: dismissMouseArea.containsMouse ? Theme.surfaceHover : "transparent"
                                radius: Theme.radiusSmall

                                Text {
                                    id: dismissText
                                    anchors.centerIn: parent
                                    color: dismissMouseArea.containsMouse ? Theme.accent : Theme.textSecondary
                                    font.family: Theme.fontFamilyMonospace
                                    font.pixelSize: Theme.fontSizeCaption
                                    font.weight: Theme.fontWeightMedium
                                    text: "[DISMISS]"
                                }

                                MouseArea {
                                    id: dismissMouseArea
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    hoverEnabled: true
                                    onClicked: NotificationService.dismissHistoryItem(cardItem.index)
                                }
                            }
                        }
                    }
                }
            }

            // Scrollbar track & thumb
            Rectangle {
                id: scrollTrack
                anchors.bottom: parent.bottom
                anchors.right: parent.right
                anchors.top: parent.top
                color: Theme.gray800
                radius: 2
                visible: historyListView.visible && (historyListView.height < historyListView.contentHeight)
                width: 4

                Rectangle {
                    id: scrollThumb
                    color: Theme.acidGreen
                    height: Math.max(16, historyListView.visibleArea.heightRatio * historyListView.height)
                    radius: 2
                    width: 4
                    y: historyListView.visibleArea.yPosition * historyListView.height
                }
            }

            // Empty state container
            Item {
                id: emptyState
                anchors.fill: parent
                visible: NotificationService.history.count === 0

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: Theme.spacingMedium

                    Rectangle {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.preferredHeight: 8
                        Layout.preferredWidth: 8
                        color: Theme.textMuted
                        radius: 4
                    }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        color: Theme.textMuted
                        font.family: Theme.fontFamilyMonospace
                        font.pixelSize: Theme.fontSizeSmall
                        font.weight: Theme.fontWeightMedium
                        text: "NO NOTIFICATIONS // STANDBY"
                    }
                }
            }
        }

        // Footer Divider
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: Theme.borderWidth
            color: Theme.borderMuted
        }

        // Footer Action Row
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingMedium

            Text {
                Layout.fillWidth: true
                color: Theme.textSecondary
                font.family: Theme.fontFamilyMonospace
                font.pixelSize: Theme.fontSizeCaption
                text: NotificationService.history.count > 0
                      ? NotificationService.history.count + " LOGGED"
                      : "0 LOGGED"
            }

            Rectangle {
                id: clearAllBtn
                Layout.preferredHeight: 26
                Layout.preferredWidth: clearAllText.implicitWidth + Theme.paddingMedium * 2
                border.color: NotificationService.history.count === 0
                              ? Theme.borderMuted
                              : (clearMouseArea.containsMouse ? Theme.destructive : Theme.borderMuted)
                border.width: Theme.borderWidth
                color: NotificationService.history.count === 0
                       ? "transparent"
                       : (clearMouseArea.containsMouse ? Theme.surfaceHover : "transparent")
                opacity: NotificationService.history.count === 0 ? 0.4 : 1.0
                radius: Theme.radiusSmall

                Text {
                    id: clearAllText
                    anchors.centerIn: parent
                    color: NotificationService.history.count === 0
                           ? Theme.textMuted
                           : (clearMouseArea.containsMouse ? Theme.destructive : Theme.textPrimary)
                    font.family: Theme.fontFamilyMonospace
                    font.pixelSize: Theme.fontSizeCaption
                    font.weight: Theme.fontWeightBold
                    text: "[CLEAR ALL]"
                }

                MouseArea {
                    id: clearMouseArea
                    anchors.fill: parent
                    cursorShape: NotificationService.history.count > 0 ? Qt.PointingHandCursor : Qt.ArrowCursor
                    enabled: NotificationService.history.count > 0
                    hoverEnabled: NotificationService.history.count > 0
                    onClicked: NotificationService.clearAll()
                }
            }
        }
    }
}
