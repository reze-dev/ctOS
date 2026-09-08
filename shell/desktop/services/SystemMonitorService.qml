pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // =========================================================================
    // Public Interface Contract
    // =========================================================================

    // Backend health indicator (true when procfs files are accessible)
    property bool available: true

    // CPU Telemetry: per-thread utilization [0.0, 1.0] and aggregate [0.0, 1.0]
    property list<real> cpuThreadLoads: []
    property real cpuTotal: 0.0

    // Memory Telemetry: byte counters
    property real memUsedBytes: 0.0
    property real memTotalBytes: 0.0
    property real swapUsedBytes: 0.0
    property real swapTotalBytes: 0.0

    // Network Telemetry: bytes per second rates
    property real netRxBytesPerSec: 0.0
    property real netTxBytesPerSec: 0.0

    // Sample interval in milliseconds
    property int refreshInterval: 1000

    // =========================================================================
    // Public Signals
    // =========================================================================

    signal telemetryUpdated()
    signal cpuTelemetryUpdated(real total, list<real> threads)
    signal memoryTelemetryUpdated(real memUsed, real memTotal, real swapUsed, real swapTotal)
    signal networkTelemetryUpdated(real rxPerSec, real txPerSec)

    // =========================================================================
    // Internal State Tracking
    // =========================================================================

    property var _prevAggregateCpu: null
    property var _prevThreadCpus: []
    property real _prevNetRx: -1.0
    property real _prevNetTx: -1.0
    property real _prevNetTimestampMs: 0.0

    // =========================================================================
    // Discrete Sample Timer
    // =========================================================================

    Timer {
        id: sampleTimer
        interval: root.refreshInterval
        running: root.available
        repeat: true
        onTriggered: root.refresh()
    }

    // =========================================================================
    // Virtual Procfs File Loaders
    // =========================================================================

    FileView {
        id: statFile
        path: "/proc/stat"
        printErrors: false
        onLoaded: root._parseCpuStat(statFile.text())
        onLoadFailed: function (error) {
            root.available = false;
        }
    }

    FileView {
        id: memFile
        path: "/proc/meminfo"
        printErrors: false
        onLoaded: root._parseMemInfo(memFile.text())
        onLoadFailed: function (error) {
            root.available = false;
        }
    }

    FileView {
        id: netFile
        path: "/proc/net/dev"
        printErrors: false
        onLoaded: root._parseNetDev(netFile.text())
        onLoadFailed: function (error) {
            root.available = false;
        }
    }

    // =========================================================================
    // Public Methods
    // =========================================================================

    function refresh(): void {
        statFile.reload();
        memFile.reload();
        netFile.reload();
    }

    function formatBytes(bytes: real): string {
        if (bytes >= 1073741824) {
            return (bytes / 1073741824).toFixed(1) + " GB";
        }
        if (bytes >= 1048576) {
            return (bytes / 1048576).toFixed(1) + " MB";
        }
        if (bytes >= 1024) {
            return (bytes / 1024).toFixed(1) + " KB";
        }
        return Math.max(0, Math.round(bytes)).toString() + " B";
    }

    // =========================================================================
    // Procfs Parsing Algorithms
    // =========================================================================

    function _parseCpuStat(rawContent: string): void {
        if (!rawContent || rawContent.length === 0) {
            return;
        }

        const lines = rawContent.split("\n");
        const threadList = [];
        let newTotal = 0.0;

        for (let i = 0; i < lines.length; i++) {
            const line = lines[i].trim();
            if (!line.startsWith("cpu")) {
                continue;
            }

            const parts = line.split(/\s+/);
            const cpuLabel = parts[0];

            if (parts.length < 5) {
                continue;
            }

            // Linux /proc/stat columns:
            // 1: user, 2: nice, 3: system, 4: idle, 5: iowait, 6: irq, 7: softirq, 8: steal
            const user = parseInt(parts[1], 10) || 0;
            const nice = parseInt(parts[2], 10) || 0;
            const system = parseInt(parts[3], 10) || 0;
            const idle = parseInt(parts[4], 10) || 0;
            const iowait = parseInt(parts[5], 10) || 0;
            const irq = parseInt(parts[6], 10) || 0;
            const softirq = parseInt(parts[7], 10) || 0;
            const steal = parseInt(parts[8], 10) || 0;

            const idleTime = idle + iowait;
            const busyTime = user + nice + system + irq + softirq + steal;
            const totalTime = idleTime + busyTime;

            if (cpuLabel === "cpu") {
                if (root._prevAggregateCpu !== null) {
                    const deltaTotal = totalTime - root._prevAggregateCpu.total;
                    const deltaIdle = idleTime - root._prevAggregateCpu.idle;
                    const deltaBusy = deltaTotal - deltaIdle;
                    if (deltaTotal > 0) {
                        newTotal = Math.max(0.0, Math.min(1.0, deltaBusy / deltaTotal));
                    }
                }
                root._prevAggregateCpu = {
                    total: totalTime,
                    idle: idleTime
                };
            } else if (/^cpu\d+$/.test(cpuLabel)) {
                const threadIndex = parseInt(cpuLabel.slice(3), 10);
                let threadLoad = 0.0;

                if (root._prevThreadCpus[threadIndex] !== undefined && root._prevThreadCpus[threadIndex] !== null) {
                    const prev = root._prevThreadCpus[threadIndex];
                    const deltaTotal = totalTime - prev.total;
                    const deltaIdle = idleTime - prev.idle;
                    const deltaBusy = deltaTotal - deltaIdle;
                    if (deltaTotal > 0) {
                        threadLoad = Math.max(0.0, Math.min(1.0, deltaBusy / deltaTotal));
                    }
                }

                root._prevThreadCpus[threadIndex] = {
                    total: totalTime,
                    idle: idleTime
                };
                threadList[threadIndex] = threadLoad;
            }
        }

        root.cpuTotal = newTotal;
        root.cpuThreadLoads = threadList;
        root.cpuTelemetryUpdated(newTotal, threadList);
        root.telemetryUpdated();
    }

    function _parseMemInfo(rawContent: string): void {
        if (!rawContent || rawContent.length === 0) {
            return;
        }

        const lines = rawContent.split("\n");
        let memTotalKb = 0;
        let memAvailableKb = 0;
        let swapTotalKb = 0;
        let swapFreeKb = 0;

        for (let i = 0; i < lines.length; i++) {
            const line = lines[i];
            if (line.startsWith("MemTotal:")) {
                memTotalKb = parseInt(line.replace(/[^0-9]/g, ""), 10) || 0;
            } else if (line.startsWith("MemAvailable:")) {
                memAvailableKb = parseInt(line.replace(/[^0-9]/g, ""), 10) || 0;
            } else if (line.startsWith("SwapTotal:")) {
                swapTotalKb = parseInt(line.replace(/[^0-9]/g, ""), 10) || 0;
            } else if (line.startsWith("SwapFree:")) {
                swapFreeKb = parseInt(line.replace(/[^0-9]/g, ""), 10) || 0;
            }
        }

        const memUsedKb = Math.max(0, memTotalKb - memAvailableKb);
        const swapUsedKb = Math.max(0, swapTotalKb - swapFreeKb);

        root.memTotalBytes = memTotalKb * 1024.0;
        root.memUsedBytes = memUsedKb * 1024.0;
        root.swapTotalBytes = swapTotalKb * 1024.0;
        root.swapUsedBytes = swapUsedKb * 1024.0;

        root.memoryTelemetryUpdated(root.memUsedBytes, root.memTotalBytes, root.swapUsedBytes, root.swapTotalBytes);
        root.telemetryUpdated();
    }

    function _parseNetDev(rawContent: string): void {
        if (!rawContent || rawContent.length === 0) {
            return;
        }

        const lines = rawContent.split("\n");
        let aggregateRx = 0;
        let aggregateTx = 0;

        for (let i = 2; i < lines.length; i++) {
            const line = lines[i].trim();
            if (!line || line.indexOf(":") === -1) {
                continue;
            }

            const colonIndex = line.indexOf(":");
            const ifaceName = line.slice(0, colonIndex).trim();
            if (ifaceName === "lo") {
                continue;
            }

            const statsPart = line.slice(colonIndex + 1).trim();
            const cols = statsPart.split(/\s+/);
            if (cols.length < 9) {
                continue;
            }

            const rx = parseInt(cols[0], 10) || 0;
            const tx = parseInt(cols[8], 10) || 0;

            aggregateRx += rx;
            aggregateTx += tx;
        }

        const nowMs = Date.now();
        if (root._prevNetRx >= 0 && root._prevNetTx >= 0 && root._prevNetTimestampMs > 0) {
            const elapsedSec = (nowMs - root._prevNetTimestampMs) / 1000.0;
            if (elapsedSec > 0.1) {
                const deltaRx = aggregateRx - root._prevNetRx;
                const deltaTx = aggregateTx - root._prevNetTx;

                root.netRxBytesPerSec = deltaRx >= 0 ? (deltaRx / elapsedSec) : 0.0;
                root.netTxBytesPerSec = deltaTx >= 0 ? (deltaTx / elapsedSec) : 0.0;
            }
        } else {
            root.netRxBytesPerSec = 0.0;
            root.netTxBytesPerSec = 0.0;
        }

        root._prevNetRx = aggregateRx;
        root._prevNetTx = aggregateTx;
        root._prevNetTimestampMs = nowMs;

        root.networkTelemetryUpdated(root.netRxBytesPerSec, root.netTxBytesPerSec);
        root.telemetryUpdated();
    }
}
