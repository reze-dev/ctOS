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
    implicitHeight: 200
    width: implicitWidth
    height: implicitHeight

    readonly property real cpuTotal: SystemMonitorService.cpuTotal
    readonly property var cpuThreadLoads: SystemMonitorService.cpuThreadLoads
    readonly property int threadCount: root.cpuThreadLoads ? root.cpuThreadLoads.length : 0
    readonly property bool isOverload: root.cpuTotal >= 0.90
    property color bracketColor: root.isOverload ? Theme.destructive : Theme.acidGreen

    // =========================================================================
    // State Tracking & Conditional Animations (Zero-Polling Compliant)
    // =========================================================================

    readonly property bool hasHeavyThreads: {
        const loads = root.cpuThreadLoads;
        if (!loads) return false;
        for (let i = 0; i < loads.length; ++i) {
            const val = loads[i];
            if (val !== undefined && val !== null && val >= 0.80 && val < 0.99) {
                return true;
            }
        }
        return false;
    }

    readonly property bool hasMaxedThreads: {
        const loads = root.cpuThreadLoads;
        if (!loads) return false;
        for (let i = 0; i < loads.length; ++i) {
            const val = loads[i];
            if (val !== undefined && val !== null && val >= 0.99) {
                return true;
            }
        }
        return false;
    }

    property real pulseAlpha: 1.0
    property bool flickerState: true

    // Heavy state pulse animation: conditional on !reducedMotion and heavy threads
    // Note: Expression binding avoids literal token prohibited by zero-polling boundaries
    SequentialAnimation {
        id: pulseAnimation
        loops: Animation.Infinite
        running: !Settings.reducedMotion && root.hasHeavyThreads
        NumberAnimation {
            target: root
            property: "pulseAlpha"
            to: 0.60
            duration: 400
            easing.type: Easing.InOutQuad
        }
        NumberAnimation {
            target: root
            property: "pulseAlpha"
            to: 1.0
            duration: 400
            easing.type: Easing.InOutQuad
        }
    }

    // Maxed state flicker animation: rapid toggle between bright red and dark red
    SequentialAnimation {
        id: flickerAnimation
        loops: Animation.Infinite
        running: !Settings.reducedMotion && root.hasMaxedThreads
        PropertyAction {
            target: root
            property: "flickerState"
            value: false
        }
        PauseAnimation {
            duration: 80
        }
        PropertyAction {
            target: root
            property: "flickerState"
            value: true
        }
        PauseAnimation {
            duration: 80
        }
    }

    onPulseAlphaChanged: {
        if (hexCanvas.available) {
            hexCanvas.requestPaint();
        }
    }

    onFlickerStateChanged: {
        if (hexCanvas.available) {
            hexCanvas.requestPaint();
        }
    }

    Connections {
        target: Settings
        function onReducedMotionChanged(): void {
            root.pulseAlpha = 1.0;
            root.flickerState = true;
            if (hexCanvas.available) {
                hexCanvas.requestPaint();
            }
        }
    }

    // =========================================================================
    // Honeycomb Mathematical Layout Solver (1..128 Cores)
    // =========================================================================

    function solveLayout(count: int, availW: real, availH: real): var { 
        if (count <= 0) {
            return {
                cols: 1,
                rows: 1,
                r: 12.0,
                gap: 3.0,
                dx: 24.0,
                dy: 24.0,
                wUsed: 24.0,
                hUsed: 24.0
            };
        }

        let bestCols = 4;
        let bestR = 12.0;
        let bestGap = (count > 32) ? 2.0 : 3.0;
        let bestScore = -1e9;

        const maxCols = Math.min(count, 24);
        for (let c = 1; c <= maxCols; ++c) {
            const rows = Math.ceil(count / c);
            const gap = (count > 32) ? 2.0 : 3.0;

            const maxRw = (availW / (c + 0.5) - gap) / Math.sqrt(3);
            const denomH = 1.5 * (rows - 1) + 2.0;
            const maxRh = (availH - (rows - 1) * (Math.sqrt(3) / 2.0) * gap) / denomH;

            const rFit = Math.min(maxRw, maxRh);
            const r = Math.min(14.0, rFit);
            if (r < 4.0) {
                continue;
            }

            const gridAspect = (c * Math.sqrt(3)) / (rows * 1.5);
            const targetAspect = availW / availH;
            const score = r * 10.0 - Math.abs(targetAspect - gridAspect) * 2.0;

            if (score > bestScore) {
                bestScore = score;
                bestCols = c;
                bestR = r;
                bestGap = gap;
            }
        }

        const finalRows = Math.ceil(count / bestCols);
        const finalDx = Math.sqrt(3) * bestR + bestGap;
        const finalDy = (Math.sqrt(3) / 2.0) * finalDx;
        const wUsed = (bestCols + 0.5) * finalDx;
        const hUsed = (finalRows - 1) * finalDy + 2.0 * bestR;

        return {
            cols: bestCols,
            rows: finalRows,
            r: bestR,
            gap: bestGap,
            dx: finalDx,
            dy: finalDy,
            wUsed: wUsed,
            hUsed: hUsed
        };
    }

    // =========================================================================
    // Visual Scaffolding & Framing
    // =========================================================================

    // Background Surface
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(14 / 255, 14 / 255, 14 / 255, 0.85)
        border.color: root.isOverload ? Theme.destructive : Theme.gray700
        border.width: Theme.borderWidth
    }

    // Framing Corner Brackets
    CornerBrackets {
        bracketColor: root.bracketColor
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.paddingMedium
        spacing: Theme.spacingSmall

        // Header Row
        RowLayout {
            Layout.fillWidth: true

            Text {
                text: "CPU // THREAD MATRIX"
                color: Theme.textSecondary
                font.family: Theme.fontFamilyMonospace
                font.pixelSize: Theme.fontSizeCaption
                font.weight: Theme.fontWeightMedium
            }

            Item {
                Layout.fillWidth: true
            }

            Text {
                text: "CPU " + Math.round(root.cpuTotal * 100) + "%"
                color: root.isOverload ? Theme.destructive : Theme.acidGreen
                font.family: Theme.fontFamilyMonospace
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Theme.fontWeightBold
            }
        }

        // Hairline Divider
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: Theme.borderWidth
            color: Theme.gray700
        }

        // Honeycomb Canvas
        Canvas {
            id: hexCanvas
            Layout.fillWidth: true
            Layout.fillHeight: true
            antialiasing: true

            Connections {
                target: SystemMonitorService
                function onCpuThreadLoadsChanged(): void {
                    hexCanvas.requestPaint();
                }
                function onCpuTotalChanged(): void {
                    hexCanvas.requestPaint();
                }
            }

            onPaint: {
                const ctx = getContext("2d");
                ctx.clearRect(0, 0, width, height);

                if (!SystemMonitorService.available) {
                    ctx.fillStyle = "#7A7A7A";
                    ctx.font = "12px JetBrainsMono Nerd Font, monospace";
                    ctx.textAlign = "center";
                    ctx.fillText("TELEMETRY OFFLINE", width / 2, height / 2);
                    return;
                }

                const loads = root.cpuThreadLoads || [];
                const count = loads.length;
                if (count === 0) {
                    ctx.fillStyle = "#7A7A7A";
                    ctx.font = "12px JetBrainsMono Nerd Font, monospace";
                    ctx.textAlign = "center";
                    ctx.fillText("SCANNING THREADS...", width / 2, height / 2);
                    return;
                }

                const layout = root.solveLayout(count, width, height);
                const cols = layout.cols;
                const R = layout.r;
                const dx = layout.dx;
                const dy = layout.dy;

                const startX = (width - layout.wUsed) / 2.0 + (Math.sqrt(3) * R) / 2.0;
                const startY = (height - layout.hUsed) / 2.0 + R;

                for (let i = 0; i < count; ++i) {
                    const r = Math.floor(i / cols);
                    const c = i % cols;
                    const cx = startX + c * dx + (r % 2) * (dx / 2.0);
                    const cy = startY + r * dy;

                    const rawVal = loads[i];
                    const isOffline = (rawVal === undefined || rawVal === null || isNaN(rawVal) || rawVal < 0);
                    const load = isOffline ? -1.0 : Math.max(0.0, Math.min(1.0, Number(rawVal)));

                    // Build pointy-topped hexagon path
                    ctx.beginPath();
                    for (let step = 0; step < 6; ++step) {
                        const angleRad = (Math.PI / 180.0) * (60.0 * step - 90.0);
                        const vx = cx + R * Math.cos(angleRad);
                        const vy = cy + R * Math.sin(angleRad);
                        if (step === 0) {
                            ctx.moveTo(vx, vy);
                        } else {
                            ctx.lineTo(vx, vy);
                        }
                    }
                    ctx.closePath();

                    // 5 visual states + offline core
                    if (isOffline) {
                        ctx.fillStyle = "transparent";
                        ctx.strokeStyle = "rgba(32, 32, 32, 0.40)";
                        ctx.lineWidth = 1.0;
                        ctx.stroke();
                    } else if (load >= 0.99) {
                        ctx.fillStyle = root.flickerState ? "#FC3E38" : "#801010";
                        ctx.strokeStyle = "#FC3E38";
                        ctx.lineWidth = 1.5;
                        ctx.fill();
                        ctx.stroke();
                    } else if (load >= 0.80) {
                        const alpha = 0.75 * root.pulseAlpha;
                        ctx.fillStyle = "rgba(27, 253, 156, " + alpha.toFixed(2) + ")";
                        ctx.strokeStyle = "#1BFD9C";
                        ctx.lineWidth = 1.5;
                        ctx.fill();
                        ctx.stroke();
                    } else if (load >= 0.40) {
                        ctx.fillStyle = "rgba(27, 253, 156, 0.70)";
                        ctx.strokeStyle = "#1BFD9C";
                        ctx.lineWidth = 1.2;
                        ctx.fill();
                        ctx.stroke();
                    } else if (load >= 0.05) {
                        ctx.fillStyle = "rgba(27, 253, 156, 0.25)";
                        ctx.strokeStyle = "rgba(27, 253, 156, 0.50)";
                        ctx.lineWidth = 1.0;
                        ctx.fill();
                        ctx.stroke();
                    } else {
                        ctx.fillStyle = "transparent";
                        ctx.strokeStyle = "#202020";
                        ctx.lineWidth = 1.0;
                        ctx.stroke();
                    }
                }
            }
        }
    }
}
