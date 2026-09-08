import QtQuick
import "../../core"
import "../../services"

Item {
    id: root

    // =========================================================================
    // Public Interface Contract (Requirement R5)
    // =========================================================================

    // Target item to which spatial jitter displacement is applied (defaults to parent)
    property Item targetItem: root.parent

    // Feature toggles
    property bool cpuDistortionEnabled: true
    property bool chromaticFlashEnabled: true
    property bool autoTrigger: true

    // Thresholds
    property real cpuThreshold: 0.90
    property real networkDeltaThreshold: 1048576.0 // 1 MB/s throughput shift

    // Readonly status
    readonly property bool isGlitching: cpuGlitchSequence.running || chromaSequence.running
    readonly property bool reducedMotionActive: Settings.reducedMotion

    // Timing constants (strictly <= 160ms)
    readonly property int maxGlitchDuration: 130
    readonly property int maxChromaDuration: 120

    anchors.fill: parent
    z: 20

    // Internal state tracking
    property real _lastNetRx: 0.0
    property real _lastNetTx: 0.0
    property real _lastGlitchTimestamp: 0.0

    // =========================================================================
    // Motion Safety Listener
    // =========================================================================

    onReducedMotionActiveChanged: {
        if (reducedMotionActive) {
            root.stop();
        }
    }

    // =========================================================================
    // Reactive Telemetry Triggers (Zero Polling)
    // =========================================================================

    Connections {
        target: SystemMonitorService
        enabled: root.autoTrigger && !root.reducedMotionActive

        function onCpuTelemetryUpdated(total, threads): void {
            if (root.cpuDistortionEnabled && total > root.cpuThreshold) {
                const now = Date.now();
                // Cooldown debounce: minimum 2000ms between automatic CPU spikes
                if (now - root._lastGlitchTimestamp >= 2000) {
                    root._lastGlitchTimestamp = now;
                    root.triggerCpuGlitch();
                }
            }
        }

        function onNetworkTelemetryUpdated(rxPerSec, txPerSec): void {
            if (root.chromaticFlashEnabled) {
                const deltaRx = Math.abs(rxPerSec - root._lastNetRx);
                const deltaTx = Math.abs(txPerSec - root._lastNetTx);
                if (deltaRx > root.networkDeltaThreshold || deltaTx > root.networkDeltaThreshold) {
                    root.triggerChromaticFlash();
                }
            }
            root._lastNetRx = rxPerSec;
            root._lastNetTx = txPerSec;
        }
    }

    Connections {
        target: NetworkService
        enabled: root.autoTrigger && !root.reducedMotionActive

        function onNetworkStateChanged(connected, connType, name): void {
            if (root.chromaticFlashEnabled) {
                root.triggerChromaticFlash();
            }
        }
    }

    // =========================================================================
    // Visual Distortion Overlay Elements
    // =========================================================================

    // Scanline laser shimmer
    Rectangle {
        id: scanline
        x: 0
        y: 0
        width: parent.width
        height: 1
        color: Theme.acidGreen
        opacity: 0.0
        z: 21
    }

    // Chromatic Aberration Red Channel Overlay
    Rectangle {
        id: chromaRed
        anchors.fill: parent
        anchors.leftMargin: 2
        anchors.rightMargin: -2
        color: Theme.destructive
        opacity: 0.0
        z: 22
    }

    // Chromatic Aberration Acid Green Channel Overlay
    Rectangle {
        id: chromaGreen
        anchors.fill: parent
        anchors.leftMargin: -2
        anchors.rightMargin: 2
        color: Theme.acidGreen
        opacity: 0.0
        z: 23
    }

    // =========================================================================
    // Discrete Animation Sequences (Bounded <= 160ms, running: false default)
    // =========================================================================

    // 1. CPU Spike Distortion Sequence (Total Duration: 130ms)
    ParallelAnimation {
        id: cpuGlitchSequence
        running: false
        loops: 1

        // Spatial Jitter Sequence (<= 3px offset, total 130ms)
        SequentialAnimation {
            NumberAnimation {
                target: root.targetItem || root
                property: "x"
                to: root.reducedMotionActive ? 0 : -2.0
                duration: 30
            }
            NumberAnimation {
                target: root.targetItem || root
                property: "x"
                to: root.reducedMotionActive ? 0 : 1.5
                duration: 40
            }
            NumberAnimation {
                target: root.targetItem || root
                property: "x"
                to: root.reducedMotionActive ? 0 : -1.0
                duration: 30
            }
            NumberAnimation {
                target: root.targetItem || root
                property: "x"
                to: 0
                duration: 30
            }
        }

        // Opacity Signal Pulse (subtle, never drops below 0.7, total 130ms)
        SequentialAnimation {
            NumberAnimation {
                target: root.targetItem || root
                property: "opacity"
                to: root.reducedMotionActive ? 1.0 : 0.85
                duration: 35
            }
            NumberAnimation {
                target: root.targetItem || root
                property: "opacity"
                to: root.reducedMotionActive ? 1.0 : 0.95
                duration: 35
            }
            NumberAnimation {
                target: root.targetItem || root
                property: "opacity"
                to: 1.0
                duration: 60
            }
        }

        // Scanline Sweep (total 120ms)
        SequentialAnimation {
            ParallelAnimation {
                NumberAnimation {
                    target: scanline
                    property: "y"
                    from: 0
                    to: root.height
                    duration: 120
                }
                SequentialAnimation {
                    NumberAnimation {
                        target: scanline
                        property: "opacity"
                        from: 0.0
                        to: root.reducedMotionActive ? 0.0 : 0.6
                        duration: 40
                    }
                    NumberAnimation {
                        target: scanline
                        property: "opacity"
                        from: root.reducedMotionActive ? 0.0 : 0.6
                        to: 0.0
                        duration: 80
                    }
                }
            }
            PropertyAction { target: scanline; property: "y"; value: 0 }
            PropertyAction { target: scanline; property: "opacity"; value: 0.0 }
        }
    }

    // 2. Chromatic Aberration Flash Sequence (Total Duration: 120ms)
    ParallelAnimation {
        id: chromaSequence
        running: false
        loops: 1

        // Red Channel Flash
        SequentialAnimation {
            NumberAnimation {
                target: chromaRed
                property: "opacity"
                from: 0.0
                to: root.reducedMotionActive ? 0.0 : 0.4
                duration: 30
            }
            NumberAnimation {
                target: chromaRed
                property: "opacity"
                from: root.reducedMotionActive ? 0.0 : 0.4
                to: 0.0
                duration: 90
            }
        }

        // Green Channel Flash
        SequentialAnimation {
            NumberAnimation {
                target: chromaGreen
                property: "opacity"
                from: 0.0
                to: root.reducedMotionActive ? 0.0 : 0.35
                duration: 30
            }
            NumberAnimation {
                target: chromaGreen
                property: "opacity"
                from: root.reducedMotionActive ? 0.0 : 0.35
                to: 0.0
                duration: 90
            }
        }
    }

    // =========================================================================
    // Public Trigger Methods
    // =========================================================================

    function triggerCpuGlitch(): void {
        if (root.reducedMotionActive) {
            return;
        }
        cpuGlitchSequence.restart();
    }

    function triggerChromaticFlash(): void {
        if (root.reducedMotionActive) {
            return;
        }
        chromaSequence.restart();
    }

    function stop(): void {
        cpuGlitchSequence.stop();
        chromaSequence.stop();
        if (root.targetItem) {
            root.targetItem.x = 0;
            root.targetItem.opacity = 1.0;
        }
        scanline.opacity = 0.0;
        scanline.y = 0;
        chromaRed.opacity = 0.0;
        chromaGreen.opacity = 0.0;
    }

    Component.onDestruction: {
        root.stop();
    }
}
