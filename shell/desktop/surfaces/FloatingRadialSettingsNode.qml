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
    implicitHeight: 380
    height: 380

    // Rate formatting helper for telemetry
    function formatBytesRate(bytes: real): string {
        if (bytes >= 1048576) {
            return (bytes / 1048576).toFixed(1) + " MB/s";
        }
        if (bytes >= 1024) {
            return (bytes / 1024).toFixed(1) + " KB/s";
        }
        return Math.round(bytes) + " B/s";
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusMedium
        color: Theme.background
        border.color: Theme.accent
        border.width: Theme.borderWidth
        clip: true

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Theme.paddingXl
            spacing: Theme.spacingMedium
            
            Text {
                text: "// SYSTEM TELEMETRY"
                color: Theme.accent
                font.family: Theme.fontFamilyMonospace
                font.pixelSize: Theme.fontSizeSegment
                font.weight: Theme.fontWeightBold
            }

                            // Card 1: CPU Telemetry
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 80
                    color: Theme.gray800
                    border.color: Theme.gray700
                    border.width: Theme.borderWidth
                    radius: Theme.radiusSmall

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: Theme.paddingMedium
                        spacing: 4

                        RowLayout {
                            Layout.fillWidth: true

                            Text {
                                text: "CPU TOTAL LOAD"
                                color: Theme.textSecondary
                                font.family: Theme.fontFamilyMonospace
                                font.pixelSize: Theme.fontSizeCaption
                                font.weight: Theme.fontWeightBold
                            }

                            Item {
                                Layout.fillWidth: true
                            }

                            Text {
                                text: Math.round(SystemMonitorService.cpuTotal * 100) + "%"
                                color: SystemMonitorService.cpuTotal > 0.85 ? Theme.warningRed : Theme.acidGreen
                                font.family: Theme.fontFamilyMonospace
                                font.pixelSize: Theme.fontSizeCaption
                                font.weight: Theme.fontWeightBold
                            }
                        }

                        // CPU Meter Bar
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 8
                            color: Theme.gray700
                            radius: 4

                            Rectangle {
                                width: Math.max(0, Math.min(parent.width, parent.width * SystemMonitorService.cpuTotal))
                                height: parent.height
                                radius: 4
                                color: SystemMonitorService.cpuTotal > 0.85 ? Theme.warningRed : Theme.acidGreen
                            }
                        }

                        Text {
                            text: SystemMonitorService.cpuThreadLoads.length > 0
                                ? (SystemMonitorService.cpuThreadLoads.length + " THREADS MONITORED // PROCFS ACTIVE")
                                : "SYSTEM CORES ONLINE"
                            color: Theme.textMuted
                            font.family: Theme.fontFamilyMonospace
                            font.pixelSize: 10
                        }
                    }
                }

                // Card 2: Memory Allocation
                Rectangle {
                    id: memCard
                    Layout.fillWidth: true
                    Layout.preferredHeight: 80
                    color: Theme.gray800
                    border.color: Theme.gray700
                    border.width: Theme.borderWidth
                    radius: Theme.radiusSmall

                    readonly property real memPercent: SystemMonitorService.memTotalBytes > 0
                        ? (SystemMonitorService.memUsedBytes / SystemMonitorService.memTotalBytes)
                        : 0.0

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: Theme.paddingMedium
                        spacing: 4

                        RowLayout {
                            Layout.fillWidth: true

                            Text {
                                text: "MEMORY USAGE"
                                color: Theme.textSecondary
                                font.family: Theme.fontFamilyMonospace
                                font.pixelSize: Theme.fontSizeCaption
                                font.weight: Theme.fontWeightBold
                            }

                            Item {
                                Layout.fillWidth: true
                            }

                            Text {
                                text: Math.round(memCard.memPercent * 100) + "%"
                                color: memCard.memPercent > 0.9 ? Theme.warningRed : Theme.acidGreen
                                font.family: Theme.fontFamilyMonospace
                                font.pixelSize: Theme.fontSizeCaption
                                font.weight: Theme.fontWeightBold
                            }
                        }

                        // Memory Meter Bar
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 8
                            color: Theme.gray700
                            radius: 4

                            Rectangle {
                                width: Math.max(0, Math.min(parent.width, parent.width * memCard.memPercent))
                                height: parent.height
                                radius: 4
                                color: memCard.memPercent > 0.9 ? Theme.warningRed : Theme.acidGreen
                            }
                        }

                        Text {
                            text: (SystemMonitorService.memUsedBytes / 1073741824).toFixed(1) + " GB / " +
                                  (SystemMonitorService.memTotalBytes / 1073741824).toFixed(1) + " GB (" +
                                  (SystemMonitorService.swapUsedBytes / 1073741824).toFixed(1) + " GB SWAP)"
                            color: Theme.textMuted
                            font.family: Theme.fontFamilyMonospace
                            font.pixelSize: 10
                        }
                    }
                }

                // Card 3: Network Bandwidth Flow
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 88
                    color: Theme.gray800
                    border.color: Theme.gray700
                    border.width: Theme.borderWidth
                    radius: Theme.radiusSmall

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: Theme.paddingMedium
                        spacing: 4

                        RowLayout {
                            Layout.fillWidth: true

                            Text {
                                text: "NETWORK FLOW"
                                color: Theme.textSecondary
                                font.family: Theme.fontFamilyMonospace
                                font.pixelSize: Theme.fontSizeCaption
                                font.weight: Theme.fontWeightBold
                            }

                            Item {
                                Layout.fillWidth: true
                            }

                            Text {
                                text: NetworkService.connectionType.toUpperCase()
                                color: NetworkService.isConnected ? Theme.acidGreen : Theme.textMuted
                                font.family: Theme.fontFamilyMonospace
                                font.pixelSize: Theme.fontSizeCaption
                                font.weight: Theme.fontWeightBold
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2

                                Text {
                                    text: "RX FLOW"
                                    color: Theme.textMuted
                                    font.family: Theme.fontFamilyMonospace
                                    font.pixelSize: 10
                                }

                                Text {
                                    text: root.formatBytesRate(SystemMonitorService.netRxBytesPerSec)
                                    color: Theme.acidGreen
                                    font.family: Theme.fontFamilyMonospace
                                    font.pixelSize: Theme.fontSizeCaption
                                    font.weight: Theme.fontWeightBold
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2

                                Text {
                                    text: "TX FLOW"
                                    color: Theme.textMuted
                                    font.family: Theme.fontFamilyMonospace
                                    font.pixelSize: 10
                                }

                                Text {
                                    text: root.formatBytesRate(SystemMonitorService.netTxBytesPerSec)
                                    color: Theme.pastelBlue
                                    font.family: Theme.fontFamilyMonospace
                                    font.pixelSize: Theme.fontSizeCaption
                                    font.weight: Theme.fontWeightBold
                                }
                            }
                        }

                        Text {
                            text: "INTERFACE: " + NetworkService.networkName
                            color: Theme.textMuted
                            font.family: Theme.fontFamilyMonospace
                            font.pixelSize: 10
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }
                }

        }
    }
}
