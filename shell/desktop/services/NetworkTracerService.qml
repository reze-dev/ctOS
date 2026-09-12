pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "../core"

Singleton {
    id: root

    // =========================================================================
    // Public Interface Contract
    // =========================================================================

    // Backend availability indicator
    property bool available: true

    // Active established outbound IP connections
    property var activeConnections: []

    // Count of active established connections
    property int connectionCount: activeConnections ? activeConnections.length : 0

    // Sample interval in milliseconds (defaults to 2000ms)
    property int refreshInterval: 2000

    // =========================================================================
    // Signals
    // =========================================================================

    signal connectionsUpdated(var connections)

    // =========================================================================
    // Discrete Sample Timer
    // =========================================================================

    Timer {
        id: tracerTimer
        interval: root.refreshInterval
        running: Boolean(Settings.widgetNetworkTracerVisible)
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!tracerProc.running) {
                tracerProc.running = true;
            }
        }
    }

    // =========================================================================
    // Subprocess Execution (Allowlisted Command Array, Zero Persistent Subshell)
    // =========================================================================

    Process {
        id: tracerProc
        command: ["ss", "-H", "-t", "-u", "-n", "state", "established"]
        running: false
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                root._parseSsOutput(text);
            }
        }
    }

    // =========================================================================
    // Public Methods
    // =========================================================================

    function refresh(): void {
        if (!tracerProc.running) {
            tracerProc.running = true;
        }
    }

    // =========================================================================
    // Internal Output Parser
    // =========================================================================

    function _parseSsOutput(raw: string): void {
        if (!raw || raw.trim() === "") {
            root.activeConnections = [];
            root.connectionsUpdated([]);
            return;
        }

        const lines = raw.trim().split("\n");
        const results = [];

        for (let i = 0; i < lines.length; i++) {
            const line = lines[i].trim();
            if (!line || line.startsWith("Netid")) {
                continue;
            }

            const cols = line.split(/\s+/);
            if (cols.length < 5) {
                continue;
            }

            const proto = cols[0].toUpperCase();
            const peerStr = cols[4];
            const lastColon = peerStr.lastIndexOf(":");
            if (lastColon === -1) {
                continue;
            }

            let ip = peerStr.slice(0, lastColon);
            const port = peerStr.slice(lastColon + 1);

            // Strip IPv6 enclosing brackets
            if (ip.startsWith("[") && ip.endsWith("]")) {
                ip = ip.slice(1, -1);
            }

            // Strip interface suffix if present (e.g. %eth0)
            const pctIdx = ip.indexOf("%");
            if (pctIdx !== -1) {
                ip = ip.slice(0, pctIdx);
            }

            // Filter loopback and wildcard addresses
            if (ip === "127.0.0.1" || ip.startsWith("127.") || ip === "::1" || ip === "0.0.0.0" || ip === "*" || ip === "::" || ip === "localhost") {
                continue;
            }

            results.push({
                protocol: proto,
                ip: ip,
                port: port,
                endpoint: ip + ":" + port
            });
        }

        root.activeConnections = results;
        root.connectionsUpdated(results);
    }
}
