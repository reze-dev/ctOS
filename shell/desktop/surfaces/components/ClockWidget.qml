import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../core"

Item {
    id: root

    readonly property date currentDate: systemClock.date
    readonly property string dateString: Qt.formatDateTime(systemClock.date, "yyyy-MM-dd")
    readonly property string timeString: Qt.formatDateTime(systemClock.date, "HH:mm")

    implicitHeight: Theme.barHeight
    implicitWidth: layout.implicitWidth + Theme.paddingSmall * 2

    SystemClock {
        id: systemClock

        precision: SystemClock.Seconds
    }

    Rectangle {
        id: container

        anchors.fill: parent
        anchors.margins: Theme.paddingXs
        border.color: hoverHandler.hovered ? Theme.ctosGray : "transparent"
        border.width: Theme.borderWidth
        color: hoverHandler.hovered ? Theme.surfaceHover : "transparent"
        radius: Theme.radiusSmall

        RowLayout {
            id: layout

            anchors.centerIn: parent
            spacing: Theme.spacingSmall

            Text {
                color: Theme.textSecondary
                elide: Text.ElideRight
                font.family: Theme.fontFamilyMonospace
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Theme.fontWeightNormal
                maximumLineCount: 1
                text: root.dateString
                wrapMode: Text.NoWrap
            }

            Text {
                color: Theme.textPrimary
                elide: Text.ElideRight
                font.family: Theme.fontFamilyMonospace
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Theme.fontWeightDemiBold
                maximumLineCount: 1
                text: root.timeString
                wrapMode: Text.NoWrap
            }
        }

        HoverHandler {
            id: hoverHandler

            cursorShape: Qt.PointingHandCursor
        }

        TapHandler {
            onTapped: {
                OverlayController.toggleEventLog();
            }
        }
    }
}
