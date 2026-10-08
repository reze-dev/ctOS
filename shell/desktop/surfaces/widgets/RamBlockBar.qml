import QtQuick
import QtQuick.Layouts
import "../../core"
import "../../services"

Item {
    id: root

    // =========================================================================
    // Public Interface Contract
    // =========================================================================

    implicitWidth: 280
    implicitHeight: 110
    width: implicitWidth
    height: implicitHeight

    // Memory Ratios & Critical Threshold
    readonly property real memRatio: (SystemMonitorService.memTotalBytes > 0)
        ? Math.max(0.0, Math.min(1.0, SystemMonitorService.memUsedBytes / SystemMonitorService.memTotalBytes))
        : 0.0

    readonly property bool isCritical: root.memRatio >= 0.80

    // 20 Blocks total (5% per block)
    readonly property int totalBlocks: 20
    readonly property int filledRamBlocks: Math.max(root.memRatio > 0 ? 1 : 0, Math.min(20, Math.round(root.memRatio * 20)))

    // Swap Ratios
    readonly property bool hasSwap: SystemMonitorService.swapTotalBytes > 0
    readonly property real swapRatio: root.hasSwap
        ? Math.max(0.0, Math.min(1.0, SystemMonitorService.swapUsedBytes / SystemMonitorService.swapTotalBytes))
        : 0.0
    readonly property int filledSwapBlocks: root.hasSwap ? Math.min(20, Math.round(root.swapRatio * 20)) : 0

    // Formatting helper (GB with 1 decimal)
    function formatGB(bytes: real): string {
        return (bytes / 1073741824.0).toFixed(1);
    }

    // =========================================================================
    // Background Surface & Framing
    // =========================================================================

    Rectangle {
        id: bgSurface
        anchors.fill: parent
        color: Theme.surfaceScrim
        border.color: root.isCritical ? Theme.destructive : Theme.gray700
        border.width: Theme.borderWidth
    }

    // Framing Corner Brackets (Transitions to destructive red when RAM >= 80%)
    CornerBrackets {
        bracketColor: root.isCritical ? Theme.destructive : Theme.statusGreen
    }

    // =========================================================================
    // Widget Content Layout
    // =========================================================================

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.paddingMedium
        spacing: Theme.spacingSmall

        // RAM Header Row: Title & Terse Monospace Usage Label
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingSmall

            Text {
                text: "RAM // 20-BLOCK MATRIX"
                color: Theme.textSecondary
                font.family: Theme.fontFamilyMonospace
                font.pixelSize: Theme.fontSizeCaption
                font.weight: Theme.fontWeightMedium
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                elide: Text.ElideRight
            }

            // Terse Label: RAM 8.2 / 16.0 GB
            Text {
                text: "RAM " + root.formatGB(SystemMonitorService.memUsedBytes) + " / " + root.formatGB(SystemMonitorService.memTotalBytes) + " GB"
                color: root.isCritical ? Theme.destructive : Theme.textPrimary
                font.family: Theme.fontFamilyMonospace
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Theme.fontWeightMedium
                // Takes its natural width and is capped. It must NOT also fill:
                // with both texts filling, the row splits evenly and the value
                // elides too, which is the same clipping in nicer clothing.
                Layout.preferredWidth: implicitWidth
                Layout.maximumWidth: 150
                horizontalAlignment: Text.AlignRight
                elide: Text.ElideRight
            }
        }

        // Chunky Segmented RAM Progress Bar (20 blocks, ~5% each)
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 16
            spacing: Theme.spacingXs

            Repeater {
                model: root.totalBlocks

                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: Theme.radiusNone

                    readonly property bool isFilled: index < root.filledRamBlocks

                    // Color transitions to Theme.destructive when usage >= 80%
                    color: {
                        if (!isFilled) return Theme.gray900;
                        return root.isCritical ? Theme.destructive : Theme.statusGreen;
                    }

                    border.color: {
                        if (!isFilled) return Theme.gray700;
                        return root.isCritical ? Theme.destructive : Qt.alpha(Theme.statusGreen, 0.85);
                    }
                    border.width: Theme.borderWidth
                }
            }
        }

        // Swap Sub-Section Header Row
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingSmall

            Text {
                text: "SWAP"
                color: Theme.textSecondary
                font.family: Theme.fontFamilyMonospace
                font.pixelSize: Theme.fontSizeCaption - 1
                font.weight: Theme.fontWeightMedium
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                elide: Text.ElideRight
            }

            Text {
                text: root.hasSwap
                    ? ("SWP " + root.formatGB(SystemMonitorService.swapUsedBytes) + " / " + root.formatGB(SystemMonitorService.swapTotalBytes) + " GB")
                    : "SWP NONE"
                color: Theme.textSecondary
                font.family: Theme.fontFamilyMonospace
                font.pixelSize: Theme.fontSizeCaption - 1
                font.weight: Theme.fontWeightMedium
                horizontalAlignment: Text.AlignRight
                elide: Text.ElideRight
                Layout.preferredWidth: implicitWidth
                Layout.maximumWidth: 170
            }
        }

        // Secondary Swap Segmented Bar (Slimmer: 6px height, 20 blocks)
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 6
            spacing: Theme.spacingXs

            Repeater {
                model: root.totalBlocks

                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: Theme.radiusNone

                    readonly property bool isFilled: index < root.filledSwapBlocks

                    color: {
                        if (!root.hasSwap || !isFilled) return Theme.gray900;
                        return (root.swapRatio >= 0.80) ? Theme.destructive : Theme.gray300;
                    }

                    border.color: {
                        if (!root.hasSwap || !isFilled) return Theme.gray700;
                        return (root.swapRatio >= 0.80) ? Theme.destructive : Theme.gray400;
                    }
                    border.width: Theme.borderWidth
                }
            }
        }
    }
}
