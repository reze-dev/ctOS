import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import "../../core"

Item {
    id: root

    // =========================================================================
    // Public Interface & Dimension Contracts
    // =========================================================================

    implicitWidth: 280
    implicitHeight: 220
    width: implicitWidth
    height: implicitHeight

    // Active state controlling background polling timers (Zero-polling compliant)
    property bool active: true

    // System Telemetry Properties
    property string hostName: "HOST_NODE"
    property alias hostname: root.hostName
    property alias target: root.hostName

    property string kernelVersion: "UNKNOWN"
    property alias kernel: root.kernelVersion

    property string osName: "ctOS / Linux"
    property alias os: root.osName

    property string uptimeString: "0d 0h 0m"
    property alias uptime: root.uptimeString

    property string threatLevel: "NOMINAL // LEVEL 5"
    property alias threat: root.threatLevel

    property color bracketColor: Theme.acidGreen

    // =========================================================================
    // Virtual Procfs & System File Loaders (Quickshell.Io.FileView)
    // =========================================================================

    FileView {
        id: hostFile
        path: "/proc/sys/kernel/hostname"
        printErrors: false
        onLoaded: {
            const raw = hostFile.text();
            if (raw && raw.trim() !== "") {
                root.hostName = raw.trim();
            }
        }
        onLoadFailed: function (error) {
            fallbackHostFile.reload();
        }
    }

    FileView {
        id: fallbackHostFile
        path: "/etc/hostname"
        printErrors: false
        onLoaded: {
            if (!root.hostName || root.hostName === "HOST_NODE" || root.hostName === "UNKNOWN") {
                const raw = fallbackHostFile.text();
                if (raw && raw.trim() !== "") {
                    root.hostName = raw.trim();
                }
            }
        }
    }

    FileView {
        id: kernelFile
        path: "/proc/sys/kernel/osrelease"
        printErrors: false
        onLoaded: {
            const raw = kernelFile.text();
            if (raw && raw.trim() !== "") {
                root.kernelVersion = raw.trim();
            }
        }
    }

    FileView {
        id: osFile
        path: "/etc/os-release"
        printErrors: false
        onLoaded: {
            const raw = osFile.text();
            if (raw) {
                root.osName = root._parseOsRelease(raw);
            }
        }
    }

    FileView {
        id: uptimeFile
        path: "/proc/uptime"
        printErrors: false
        onLoaded: {
            const raw = uptimeFile.text();
            if (raw) {
                root.uptimeString = root._parseUptime(raw);
            }
        }
    }

    // Discrete 10s Timer for Uptime Refresh (Zero-Polling Compliant)
    Timer {
        id: uptimeTimer
        interval: 10000
        running: root.active && root.visible
        repeat: true
        onTriggered: {
            uptimeFile.reload();
        }
    }

    // =========================================================================
    // Parsing & Formatting Helpers
    // =========================================================================

    function formatUptime(totalSeconds: real): string {
        const s = Math.max(0, totalSeconds);
        const days = Math.floor(s / 86400);
        const hours = Math.floor((s % 86400) / 3600);
        const mins = Math.floor((s % 3600) / 60);
        return days + "d " + hours + "h " + mins + "m";
    }

    function _parseUptime(raw: string): string {
        if (!raw || raw.trim() === "") {
            return "0d 0h 0m";
        }
        const parts = raw.trim().split(/\s+/);
        const secs = parseFloat(parts[0]) || 0;
        return root.formatUptime(secs);
    }

    function _parseOsRelease(raw: string): string {
        if (!raw || raw.trim() === "") {
            return "ctOS / Linux";
        }
        const prettyMatch = raw.match(/^PRETTY_NAME="?([^"\n]+)"?/m);
        if (prettyMatch && prettyMatch[1]) {
            return prettyMatch[1].trim();
        }
        const nameMatch = raw.match(/^NAME="?([^"\n]+)"?/m);
        if (nameMatch && nameMatch[1]) {
            return nameMatch[1].trim();
        }
        return "Linux";
    }

    function refresh(): void {
        hostFile.reload();
        kernelFile.reload();
        osFile.reload();
        uptimeFile.reload();
    }

    Component.onCompleted: {
        if (hostFile.text()) {
            const h = hostFile.text().trim();
            if (h !== "") root.hostName = h;
        }
        if (kernelFile.text()) {
            const k = kernelFile.text().trim();
            if (k !== "") root.kernelVersion = k;
        }
        if (osFile.text()) {
            root.osName = root._parseOsRelease(osFile.text());
        }
        if (uptimeFile.text()) {
            root.uptimeString = root._parseUptime(uptimeFile.text());
        }
    }

    // =========================================================================
    // Visual Framing & Background Surface
    // =========================================================================

    Rectangle {
        id: bgSurface
        anchors.fill: root
        color: Qt.rgba(14 / 255, 14 / 255, 14 / 255, 0.85)
        border.color: Theme.gray700
        border.width: Theme.borderWidth
    }

    // Framing Corner Brackets in Theme.acidGreen
    CornerBrackets {
        id: brackets
        bracketColor: root.bracketColor
    }

    // =========================================================================
    // Widget Content Layout
    // =========================================================================

    ColumnLayout {
        id: mainLayout
        anchors.fill: root
        anchors.margins: Theme.paddingMedium
        spacing: Theme.spacingSmall

        // Header Row: Reticle & Title + Status [PROFILED]
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingSmall

            Text {
                id: headerTitle
                text: "⌖ TARGET PROFILER"
                color: Theme.textSecondary
                font.family: Theme.fontFamilyMonospace
                font.pixelSize: Theme.fontSizeCaption
                font.weight: Theme.fontWeightMedium
            }

            Item {
                Layout.fillWidth: true
            }

            Text {
                id: profiledBadge
                text: "[PROFILED]"
                color: Theme.acidGreen
                font.family: Theme.fontFamilyMonospace
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Theme.fontWeightBold
            }
        }

        // Hairline Divider
        Rectangle {
            id: headerDivider
            Layout.fillWidth: true
            Layout.preferredHeight: Theme.borderWidth
            color: Theme.gray700
        }

        // Watch Dogs Data Grid: TARGET, OS, KERNEL, UPTIME, THREAT LEVEL
        GridLayout {
            id: dataGrid
            Layout.fillWidth: true
            columns: 2
            columnSpacing: Theme.spacingMedium
            rowSpacing: Theme.spacingSmall

            Text {
                text: "TARGET:"
                color: Theme.textMuted
                font.family: Theme.fontFamilyMonospace
                font.pixelSize: 11
                font.weight: Theme.fontWeightNormal
            }

            Text {
                text: root.hostName
                color: Theme.textPrimary
                font.family: Theme.fontFamilyMonospace
                font.pixelSize: 11
                font.weight: Theme.fontWeightBold
                elide: Text.ElideRight
                Layout.fillWidth: true
            }

            Text {
                text: "OS:"
                color: Theme.textMuted
                font.family: Theme.fontFamilyMonospace
                font.pixelSize: 11
                font.weight: Theme.fontWeightNormal
            }

            Text {
                text: root.osName
                color: Theme.textPrimary
                font.family: Theme.fontFamilyMonospace
                font.pixelSize: 11
                font.weight: Theme.fontWeightMedium
                elide: Text.ElideRight
                Layout.fillWidth: true
            }

            Text {
                text: "KERNEL:"
                color: Theme.textMuted
                font.family: Theme.fontFamilyMonospace
                font.pixelSize: 11
                font.weight: Theme.fontWeightNormal
            }

            Text {
                text: root.kernelVersion
                color: Theme.textPrimaryDim
                font.family: Theme.fontFamilyMonospace
                font.pixelSize: 11
                font.weight: Theme.fontWeightMedium
                elide: Text.ElideRight
                Layout.fillWidth: true
            }

            Text {
                text: "UPTIME:"
                color: Theme.textMuted
                font.family: Theme.fontFamilyMonospace
                font.pixelSize: 11
                font.weight: Theme.fontWeightNormal
            }

            Text {
                text: root.uptimeString
                color: Theme.acidGreen
                font.family: Theme.fontFamilyMonospace
                font.pixelSize: 11
                font.weight: Theme.fontWeightBold
                Layout.fillWidth: true
            }

            Text {
                text: "THREAT LEVEL:"
                color: Theme.textMuted
                font.family: Theme.fontFamilyMonospace
                font.pixelSize: 11
                font.weight: Theme.fontWeightNormal
            }

            Text {
                text: root.threatLevel
                color: Theme.acidGreen
                font.family: Theme.fontFamilyMonospace
                font.pixelSize: 11
                font.weight: Theme.fontWeightBold
                Layout.fillWidth: true
            }
        }

        Item {
            id: verticalSpacer
            Layout.fillHeight: true
        }

        // Decorative Barcode & Geometric Accents
        ColumnLayout {
            id: barcodeSection
            Layout.fillWidth: true
            spacing: Theme.spacingXs

            // Geometric Accent Divider with Diamond Reticle Pip
            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spacingSmall

                Rectangle {
                    Layout.fillWidth: true
                    height: Theme.borderWidth
                    color: Theme.gray700
                }

                Rectangle {
                    width: 4
                    height: 4
                    color: Theme.acidGreen
                    rotation: 45
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: Theme.borderWidth
                    color: Theme.gray700
                }
            }

            // Barcode Graphic: Row of vertical rectangles
            Row {
                id: barcodeRow
                Layout.alignment: Qt.AlignHCenter
                spacing: 2
                readonly property var widths: [2, 1, 3, 1, 1, 4, 2, 1, 3, 1, 2, 4, 1, 2, 1, 3, 2, 1, 4, 1, 2, 3, 1, 2, 4]

                Repeater {
                    model: barcodeRow.widths

                    Rectangle {
                        width: modelData
                        height: 14
                        color: Theme.textPrimary
                    }
                }
            }

            // Barcode Caption
            Text {
                id: barcodeCaption
                Layout.alignment: Qt.AlignHCenter
                text: "||| ctOS-SYS-4091-B |||"
                color: Theme.textMuted
                font.family: Theme.fontFamilyMonospace
                font.pixelSize: 9
                font.weight: Theme.fontWeightMedium
            }
        }
    }
}
