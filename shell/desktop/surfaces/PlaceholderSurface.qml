import QtQuick
import QtQuick.Layouts
import "../core"

Rectangle {
    id: root

    property string title: {
        if (OverlayController.activeSurface === OverlayController.Surface.SystemRail) {
            return "SYSTEM RAIL // [T5 OFFLINE]";
        }
        if (OverlayController.activeSurface === OverlayController.Surface.EventLog) {
            return "EVENT LOG // [T6 OFFLINE]";
        }
        return "UTILITY SURFACE // [OFFLINE]";
    }
    property string subtitle: "Utility surface scheduled for Milestone T5/T6. Press ESC or click outside to dismiss."

    implicitWidth: 360
    width: 360
    anchors.top: parent ? parent.top : undefined
    anchors.bottom: parent ? parent.bottom : undefined

    color: Theme.gray900
    border.color: Theme.borderMuted
    border.width: Theme.borderWidth

    // Consume mouse events inside placeholder so clicking inside does not dismiss overlay
    MouseArea {
        id: consumeArea
        anchors.fill: parent
        hoverEnabled: true
        preventStealing: true
        onClicked: function(mouse) {
            mouse.accepted = true;
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.paddingXl
        spacing: Theme.spacingLarge

        // Header
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingMedium

            Rectangle {
                Layout.alignment: Qt.AlignVCenter
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
                text: root.title
            }

            Rectangle {
                Layout.alignment: Qt.AlignVCenter
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

        // Hairline divider
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: Theme.borderWidth
            color: Theme.borderMuted
        }

        // Diagnostics / Status Panel
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 90
            border.color: Theme.borderMuted
            border.width: Theme.borderWidth
            color: Theme.surfaceHover
            radius: Theme.radiusSmall

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Theme.paddingMedium
                spacing: Theme.spacingSmall

                Text {
                    color: Theme.textSecondary
                    font.family: Theme.fontFamilyMonospace
                    font.pixelSize: Theme.fontSizeCaption
                    text: "SUBSYSTEM // STANDBY"
                }

                Text {
                    Layout.fillWidth: true
                    color: Theme.textPrimary
                    font.family: Theme.fontFamilyMonospace
                    font.pixelSize: Theme.fontSizeSmall
                    text: root.subtitle
                    wrapMode: Text.WordWrap
                }
            }
        }

        Item {
            Layout.fillHeight: true
        }

        // Footer hint
        Text {
            Layout.alignment: Qt.AlignHCenter
            color: Theme.textMuted
            font.family: Theme.fontFamilyMonospace
            font.pixelSize: Theme.fontSizeCaption
            text: "PRESS ESC OR CLICK OUTSIDE TO DISMISS"
        }
    }
}
