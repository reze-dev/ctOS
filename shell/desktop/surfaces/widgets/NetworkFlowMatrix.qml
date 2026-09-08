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
    implicitHeight: 140
    width: implicitWidth
    height: implicitHeight

    // History Configuration (30 seconds of telemetry buffer)
    property int maxSamples: 30
    property real minCeilingBytesPerSec: 65536.0

    // Data buffers
    property var rxHistory: []
    property var txHistory: []

    // Formatting helper
    function formatRate(bytesPerSec: real): string {
        const rate = Math.max(0.0, bytesPerSec || 0.0);
        if (rate >= 1073741824) {
            return (rate / 1073741824).toFixed(1) + " GB/s";
        }
        if (rate >= 1048576) {
            return (rate / 1048576).toFixed(1) + " MB/s";
        }
        if (rate >= 1024) {
            return (rate / 1024).toFixed(1) + " KB/s";
        }
        return Math.round(rate).toString() + " B/s";
    }

    // History buffer management
    function pushSample(rxRate: real, txRate: real): void {
        const newRx = root.rxHistory.slice();
        const newTx = root.txHistory.slice();

        newRx.push(Math.max(0.0, rxRate || 0.0));
        newTx.push(Math.max(0.0, txRate || 0.0));

        while (newRx.length > root.maxSamples) {
            newRx.shift();
        }
        while (newTx.length > root.maxSamples) {
            newTx.shift();
        }

        root.rxHistory = newRx;
        root.txHistory = newTx;
        if (graphCanvas.available) {
            graphCanvas.requestPaint();
        }
    }

    // Initialize buffer with baseline
    Component.onCompleted: {
        const initRx = [];
        const initTx = [];
        for (let i = 0; i < root.maxSamples; ++i) {
            initRx.push(0.0);
            initTx.push(0.0);
        }
        root.rxHistory = initRx;
        root.txHistory = initTx;
        if (graphCanvas.available) {
            graphCanvas.requestPaint();
        }
    }

    // Reactive telemetry binding (Zero Polling: 1 Hz event-driven)
    Connections {
        target: SystemMonitorService
        function onNetworkTelemetryUpdated(rxPerSec, txPerSec): void {
            root.pushSample(rxPerSec, txPerSec);
        }
    }

    // =========================================================================
    // Background Surface & Framing
    // =========================================================================

    Rectangle {
        id: bgSurface
        anchors.fill: parent
        color: Qt.rgba(14 / 255, 14 / 255, 14 / 255, 0.85)
        border.color: Theme.gray700
        border.width: Theme.borderWidth
    }

    CornerBrackets {
        bracketColor: Theme.acidGreen
    }

    // =========================================================================
    // Widget Content Layout
    // =========================================================================

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.paddingMedium
        spacing: Theme.spacingSmall

        // Header Row: Title & Terse Monospace Speed Labels
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingSmall

            Text {
                text: "NET // FLOW MATRIX"
                color: Theme.textSecondary
                font.family: Theme.fontFamilyMonospace
                font.pixelSize: Theme.fontSizeCaption
                font.weight: Theme.fontWeightMedium
            }

            Item {
                Layout.fillWidth: true
            }

            // RX Speed Label (Theme.acidGreen)
            Text {
                text: "↓ " + root.formatRate(SystemMonitorService.netRxBytesPerSec)
                color: Theme.acidGreen
                font.family: Theme.fontFamilyMonospace
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Theme.fontWeightMedium
            }

            Text {
                text: " "
                color: Theme.gray700
                font.family: Theme.fontFamilyMonospace
                font.pixelSize: Theme.fontSizeSmall
            }

            // TX Speed Label (Theme.gray300)
            Text {
                text: "↑ " + root.formatRate(SystemMonitorService.netTxBytesPerSec)
                color: Theme.gray300
                font.family: Theme.fontFamilyMonospace
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Theme.fontWeightMedium
            }
        }

        // Hairline Divider
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: Theme.borderWidth
            color: Theme.gray700
        }

        // Scrolling Real-Time Line Graph Canvas
        Canvas {
            id: graphCanvas
            Layout.fillWidth: true
            Layout.fillHeight: true
            antialiasing: true

            onPaint: {
                const ctx = getContext("2d");
                const w = width;
                const h = height;

                ctx.clearRect(0, 0, w, h);

                if (!SystemMonitorService.available) {
                    ctx.fillStyle = "#7A7A7A";
                    ctx.font = "12px JetBrainsMono Nerd Font, monospace";
                    ctx.textAlign = "center";
                    ctx.fillText("NETWORK OFFLINE", w / 2, h / 2);
                    return;
                }

                // -------------------------------------------------------------
                // 1. Wireframe Grid Lines (Theme.gray700: #202020)
                // -------------------------------------------------------------
                ctx.strokeStyle = "#202020";
                ctx.lineWidth = 1.0;

                // Horizontal wireframe grid lines (4 equal divisions)
                const hDivisions = 4;
                for (let i = 1; i <= hDivisions; ++i) {
                    const y = Math.round((h / hDivisions) * i) - 0.5;
                    ctx.beginPath();
                    ctx.moveTo(0, y);
                    ctx.lineTo(w, y);
                    ctx.stroke();
                }

                // Vertical wireframe time markers (every 5 samples)
                const samples = root.maxSamples;
                const stepX = w / Math.max(1, samples - 1);
                for (let i = 0; i < samples; i += 5) {
                    const x = Math.round(i * stepX) + 0.5;
                    ctx.beginPath();
                    ctx.moveTo(x, 0);
                    ctx.lineTo(x, h);
                    ctx.stroke();
                }

                const rx = root.rxHistory;
                const tx = root.txHistory;
                const n = rx.length;
                if (n < 2) return;

                // -------------------------------------------------------------
                // 2. Dynamic Ceiling Auto-Scaling (with 64 KB/s floor)
                // -------------------------------------------------------------
                let peak = root.minCeilingBytesPerSec;
                for (let i = 0; i < n; ++i) {
                    if (rx[i] > peak) peak = rx[i];
                    if (tx[i] > peak) peak = tx[i];
                }
                const maxVal = peak * 1.15; // 15% headroom

                const plotY = function (val) {
                    const clamped = Math.max(0.0, val || 0.0);
                    const ratio = Math.min(1.0, clamped / maxVal);
                    return (h - 2) - ratio * (h - 4);
                };

                const startOffset = w - (n - 1) * stepX;

                // -------------------------------------------------------------
                // 3. Draw TX Line (Theme.gray300: #C3C3C3)
                // -------------------------------------------------------------
                ctx.strokeStyle = "#C3C3C3";
                ctx.lineWidth = 1.5;
                ctx.beginPath();
                for (let i = 0; i < n; ++i) {
                    const x = startOffset + i * stepX;
                    const y = plotY(tx[i]);
                    if (i === 0) ctx.moveTo(x, y);
                    else ctx.lineTo(x, y);
                }
                ctx.stroke();

                // -------------------------------------------------------------
                // 4. Draw RX Area Glow & Line (Theme.acidGreen: #1BFD9C)
                // -------------------------------------------------------------
                // Faint tactical gradient fill under RX curve
                ctx.fillStyle = "rgba(27, 253, 156, 0.08)";
                ctx.beginPath();
                ctx.moveTo(startOffset, h - 2);
                for (let i = 0; i < n; ++i) {
                    ctx.lineTo(startOffset + i * stepX, plotY(rx[i]));
                }
                ctx.lineTo(startOffset + (n - 1) * stepX, h - 2);
                ctx.closePath();
                ctx.fill();

                // Crisp RX Stroke
                ctx.strokeStyle = "#1BFD9C";
                ctx.lineWidth = 1.5;
                ctx.beginPath();
                for (let i = 0; i < n; ++i) {
                    const x = startOffset + i * stepX;
                    const y = plotY(rx[i]);
                    if (i === 0) ctx.moveTo(x, y);
                    else ctx.lineTo(x, y);
                }
                ctx.stroke();
            }
        }
    }
}
