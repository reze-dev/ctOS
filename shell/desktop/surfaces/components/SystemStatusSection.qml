pragma ComponentBehavior: Bound

import QtQuick
import "../../core"
import "../../services"
import "StatRing.qml"

// Quick system telemetry: CPU, memory and disk as rings, with current network
// throughput alongside.
//
// Deliberately a plain card rather than an AccordionSection. The other CCC
// sections are accordions because they hide input behind disclosure; this one
// only reports, so there is nothing to collapse and nothing for a header action
// to do. Height is stated directly instead of being measured through a Loader,
// which keeps the Column's layout arithmetic trivial.
//
// Chrome matches the accordion sections: a bordered header bar with the content
// below it, unbordered.
Item {
    id: root

    readonly property real memFraction: SystemMonitorService.memTotalBytes > 0
        ? Math.min(1.0, SystemMonitorService.memUsedBytes / SystemMonitorService.memTotalBytes)
        : 0.0

    function pct(f: real): string {
        return Math.round(Math.max(0, Math.min(1, f)) * 100) + "%";
    }

    implicitWidth: parent ? parent.width : undefined
    implicitHeight: Theme.accordionHeaderHeight + Theme.spacingMedium + 76
    height: Theme.accordionHeaderHeight + Theme.spacingMedium + 76
    width: parent ? parent.width : undefined

    Rectangle {
        id: headerBar
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: Theme.accordionHeaderHeight
        color: Theme.surfaceActive
        border.color: Theme.accent
        border.width: Theme.borderWidth
        radius: Theme.radiusSmall

        Text {
            anchors.left: parent.left
            anchors.leftMargin: Theme.spacingMedium
            anchors.verticalCenter: parent.verticalCenter
            text: "▼"
            color: Theme.accent
            font.family: Theme.fontFamilyMonospace
            font.pixelSize: Theme.fontSizeCaption
        }

        Text {
            anchors.left: parent.left
            anchors.leftMargin: Theme.spacingLarge + Theme.spacingSmall
            anchors.verticalCenter: parent.verticalCenter
            text: "// SYSTEM STATUS"
            color: Theme.accent
            font.family: Theme.fontFamilyMonospace
            font.pixelSize: Theme.fontSizeCaption
            font.weight: Theme.fontWeightBold
        }
    }

    Row {
        id: body
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: headerBar.bottom
        anchors.topMargin: Theme.spacingMedium
        height: 76
        spacing: Theme.spacingLarge

        StatRing {
            fraction: SystemMonitorService.cpuTotal
            ringColor: Theme.statusGreen
            valueText: root.pct(SystemMonitorService.cpuTotal)
            caption: "CPU"
        }

        StatRing {
            fraction: root.memFraction
            ringColor: Theme.accentBlue
            valueText: root.pct(root.memFraction)
            caption: "MEMORY"
        }

        StatRing {
            fraction: SystemMonitorService.diskFraction
            ringColor: Theme.accentMagenta
            valueText: root.pct(SystemMonitorService.diskFraction)
            caption: "DISK"
        }

        Item {
            width: Math.max(0, body.width - 56 * 3 - Theme.spacingLarge * 3)
            height: 76

            Row {
                anchors.right: parent.right
                anchors.top: parent.top
                spacing: Theme.spacingSmall

                Text {
                    text: "↑"
                    color: Theme.accentBlue
                    font.family: Theme.fontFamilyMonospace
                    font.pixelSize: Theme.fontSizeBody
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    text: SystemMonitorService.formatBytes(SystemMonitorService.netRxBytesPerSec) + "/s"
                    color: Theme.textPrimary
                    font.family: Theme.fontFamilyMonospace
                    font.pixelSize: Theme.fontSizeSmall
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            Row {
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.topMargin: 22
                spacing: Theme.spacingSmall

                Text {
                    text: "↓"
                    color: Theme.accentMagenta
                    font.family: Theme.fontFamilyMonospace
                    font.pixelSize: Theme.fontSizeBody
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    text: SystemMonitorService.formatBytes(SystemMonitorService.netTxBytesPerSec) + "/s"
                    color: Theme.textPrimary
                    font.family: Theme.fontFamilyMonospace
                    font.pixelSize: Theme.fontSizeSmall
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            Text {
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.topMargin: 44
                text: "NETWORK"
                color: Theme.textSecondary
                font.family: Theme.fontFamilyMonospace
                font.pixelSize: Theme.fontSizeCaption
                font.weight: Theme.fontWeightBold
            }
        }
    }
}