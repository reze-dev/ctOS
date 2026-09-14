import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../core"

Item {
    id: root

    signal toggleCalendar

    readonly property date currentDate: systemClock.date
    readonly property string dateString: Qt.formatDateTime(systemClock.date, "yyyy-MM-dd")
    readonly property string timeString: Qt.formatDateTime(systemClock.date, "HH:mm")

    implicitHeight: layout.implicitHeight
    implicitWidth: layout.implicitWidth

    SystemClock {
        id: systemClock

        precision: SystemClock.Seconds
    }

    RowLayout {
        id: layout

        anchors.centerIn: parent
        spacing: Theme.spacingSmall

        Text {
            Layout.alignment: Qt.AlignVCenter
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
            Layout.alignment: Qt.AlignVCenter
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
}
