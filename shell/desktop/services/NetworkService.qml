pragma ComponentBehavior: Bound
pragma Singleton

import QtQuick
import QtQml
import Quickshell
import Quickshell.Networking
import Quickshell.Io


Singleton {
    id: root

    // =========================================================================
    // Public Interface Contract
    // =========================================================================

    // True if NetworkManager backend daemon is accessible
    readonly property bool available: Networking.backend === NetworkBackendType.NetworkManager

    // Current connection transport type: "ethernet" | "wifi" | "none"
    property string connectionType: "none"

    // Number of recognized network devices
    readonly property int deviceCount: Networking.devices && Networking.devices.values ? Networking.devices.values.length : 0

    // True if any managed interface is currently connected
    property bool isConnected: false

    // Semantic transport aliases
    readonly property bool isEthernet: connectionType === "ethernet"
    readonly property bool isWifi: connectionType === "wifi"

    // Active network identifier (SSID or interface ID); explicit "--N/A--" when offline
    property string networkName: "--N/A--"

    // Wireless signal strength normalized [0.0, 1.0]; -1.0 if not connected to Wi-Fi
    property real signalStrength: -1.0

    // True if Wi-Fi subsystem radio is enabled; tracks Networking.wifiEnabled
    readonly property bool wifiEnabled: Boolean(Networking.wifiEnabled)

    // Milestone T6 (Requirement R1): Wi-Fi Discovery & Connection Contract
    property var availableNetworks: []
    property string connectingSsid: ""
    readonly property bool isConnecting: connectingSsid !== ""
    property string lastError: ""
    property bool isScanning: false

    // Categorized network helper accessors
    readonly property var connectedNetworks: availableNetworks ? availableNetworks.filter(n => n.connected) : []
    readonly property var savedNetworks: availableNetworks ? availableNetworks.filter(n => n.known && !n.connected) : []
    readonly property var discoveredNetworks: availableNetworks ? availableNetworks.filter(n => !n.known && !n.connected) : []

    // Milestone 4 (Requirement R6): Watchdog & Connection Timing Parameters
    property int watchdogInterval: 10000
    property int connectionTimeout: 15000

    // Signals
    signal networkStateChanged(bool connected, string connType, string name)
    signal connectionFailed(string ssid, string reason)

    // =========================================================================
    // Sanitization & Elision Helpers
    // =========================================================================

    // Sanitizes non-printable characters and truncates to prevent bar column overflow
    function sanitizeName(raw: string): string {
        if (!raw || raw.trim() === "") {
            return "--N/A--";
        }
        // Remove non-printable / control ASCII characters and trim
        const cleaned = raw.replace(/[^\x20-\x7E]/g, "").trim();
        // Truncate to safe column width (max 32 chars) to prevent layout distortion
        const truncated = cleaned.slice(0, 32);
        return truncated.length > 0 ? truncated : "--N/A--";
    }

    // =========================================================================
    // Reactive State Evaluation
    // =========================================================================

    function _evaluateNetworkState(): void {
        if (!root.available || !Networking.devices) {
            _applyDisconnectedState();
            return;
        }

        const devices = Networking.devices.values;
        if (!devices || devices.length === 0) {
            _applyDisconnectedState();
            return;
        }

        // 1. Evaluate Wired (Ethernet) interfaces first (highest priority)
        for (let i = 0; i < devices.length; i++) {
            const dev = devices[i];
            if (dev && dev.type === DeviceType.Wired && dev.connected) {
                const wiredName = (dev.network && dev.network.name) ? dev.network.name : "Ethernet";
                _applyConnectedState("ethernet", sanitizeName(wiredName), 1.0);
                return;
            }
        }

        // 2. Evaluate Wireless (Wi-Fi) interfaces
        for (let i = 0; i < devices.length; i++) {
            const dev = devices[i];
            if (dev && dev.type === DeviceType.Wifi && dev.connected) {
                let activeSsid = "";
                let activeStrength = 0.0;

                if (dev.networks && dev.networks.values) {
                    for (let j = 0; j < dev.networks.values.length; j++) {
                        const net = dev.networks.values[j];
                        if (net && net.connected) {
                            activeSsid = net.name;
                            activeStrength = typeof net.signalStrength === "number" ? net.signalStrength : 0.0;
                            break;
                        }
                    }
                }

                if (!activeSsid && dev.name) {
                    activeSsid = dev.name;
                }

                _applyConnectedState("wifi", sanitizeName(activeSsid), activeStrength);
                return;
            }
        }

        // 3. Fallback: No connected interface detected
        _applyDisconnectedState();
    }

    function _applyConnectedState(connType: string, name: string, strength: real): void {
        const changed = (!root.isConnected || root.connectionType !== connType || root.networkName !== name);
        root.isConnected = true;
        root.connectionType = connType;
        root.networkName = name;
        root.signalStrength = strength;

        if (root.connectingSsid !== "") {
            const cleanConn = root.sanitizeName(name);
            const cleanTarget = root.sanitizeName(root.connectingSsid);
            if (cleanConn === cleanTarget || name === root.connectingSsid) {
                connectionTimeoutTimer.stop();
                root.connectingSsid = "";
                root.lastError = "";
            }
        }

        if (changed) {
            root.networkStateChanged(true, connType, name);
        }
    }

    function _applyDisconnectedState(): void {
        const changed = (root.isConnected || root.connectionType !== "none" || root.networkName !== "--N/A--");
        root.isConnected = false;
        root.connectionType = "none";
        root.networkName = "--N/A--";
        root.signalStrength = -1.0;

        if (changed) {
            root.networkStateChanged(false, "none", "--N/A--");
        }
    }

    // =========================================================================
    // Public Wi-Fi Controls
    // =========================================================================

    // Toggles the Wi-Fi subsystem radio state via NetworkManager
    function toggleWifi(): void {
        if (!root.available) {
            return;
        }
        if (Networking.wifiEnabled) {
            connectionTimeoutTimer.stop();
            root.connectingSsid = "";
            root.stopScan();
        }
        Networking.wifiEnabled = !Networking.wifiEnabled;
    }

    // Explicitly sets the Wi-Fi subsystem state
    function setWifiEnabled(enabled: bool): void {
        if (!root.available) {
            return;
        }
        if (!enabled) {
            connectionTimeoutTimer.stop();
            root.connectingSsid = "";
            root.stopScan();
        }
        Networking.wifiEnabled = enabled;
    }

    // Requests Wi-Fi network rescan via nmcli
    function scanNetworks(): void {
        if (!root.available || !root.wifiEnabled || rescanProcess.running) {
            return;
        }
        root.isScanning = true;
        rescanProcess.running = true;
    }

    // Stops active scan
    function stopScan(): void {
        if (rescanProcess.running) {
            rescanProcess.running = false;
        }
        root.isScanning = false;
    }

    // Toggles active scanning state
    function toggleScan(): void {
        if (root.isScanning || rescanProcess.running) {
            root.stopScan();
        } else {
            root.scanNetworks();
        }
    }

    // Forces an immediate re-evaluation and rescan
    function refresh(): void {
        root._evaluateNetworkState();
        root._scheduleRebuild();
        if (root.available && root.wifiEnabled) {
            root.scanNetworks();
        }
    }

    // Declarative process for network scanning
    Process {
        id: rescanProcess
        command: ["nmcli", "dev", "wifi", "rescan"]
        running: false

        onExited: function(exitCode) {
            root.isScanning = false;
            root._evaluateNetworkState();
            root._scheduleRebuild();
        }
    }

    // =========================================================================
    // Debounced Network Discovery Model Builder
    // =========================================================================

    // =========================================================================
    // Milestone 4 (Requirement R6): Watchdog & Timeout Timers
    // =========================================================================

    // Periodic Watchdog: Evaluates network state every 10s regardless of model signals
    // Dynamic running expression required; no literal boolean permitted
    Timer {
        id: networkWatchdogTimer
        interval: 10000
        repeat: true
        running: Boolean(root.available && root.watchdogInterval > 0)
        triggeredOnStart: false
        onTriggered: root._evaluateNetworkState()
    }

    // Single-shot 15s connection timeout timer
    Timer {
        id: connectionTimeoutTimer
        interval: 15000
        repeat: false
        onTriggered: {
            if (root.connectingSsid !== "") {
                const timedOutSsid = root.connectingSsid;
                root.connectingSsid = "";
                root.lastError = "Connection timed out";
                root.connectionFailed(timedOutSsid, "Connection timed out");
            }
        }
    }

    Timer {
        id: rebuildDebounceTimer
        interval: 100
        repeat: false
        onTriggered: root._rebuildAvailableNetworks()
    }

    function _scheduleRebuild(): void {
        if (!rebuildDebounceTimer.running) {
            rebuildDebounceTimer.restart();
        }
    }

    function _rebuildAvailableNetworks(): void {
        if (!root.available || !root.wifiEnabled || !Networking.devices) {
            root.availableNetworks = [];
            return;
        }

        const devices = Networking.devices.values;
        if (!devices || devices.length === 0) {
            root.availableNetworks = [];
            return;
        }

        const list = [];
        const seen = new Set();

        for (let i = 0; i < devices.length; i++) {
            const dev = devices[i];
            if (dev && dev.type === DeviceType.Wifi && dev.networks && dev.networks.values) {
                for (let j = 0; j < dev.networks.values.length; j++) {
                    const net = dev.networks.values[j];
                    if (!net || !net.name || net.name.trim() === "") {
                        continue;
                    }

                    const cleanName = root.sanitizeName(net.name);
                    if (cleanName === "--N/A--") {
                        continue;
                    }

                    if (seen.has(cleanName)) {
                        continue;
                    }
                    seen.add(cleanName);

                    const strength = typeof net.signalStrength === "number"
                        ? Math.max(0.0, Math.min(1.0, net.signalStrength))
                        : 0.0;
                    const isKnown = Boolean(net.known);
                    const isConnected = Boolean(net.connected);
                    const isSecured = (net.security !== WifiSecurityType.Open);

                    const entry = {
                        ssid: cleanName,
                        rawSsid: net.name,
                        signalStrength: strength,
                        known: isKnown,
                        connected: isConnected,
                        security: net.security,
                        requiresPassword: (!isKnown && isSecured),
                        network: net
                    };
                    list.push(entry);
                }
            }
        }

        // Sort: Connected first -> Known -> Signal Strength (descending) -> Alphabetical
        list.sort((a, b) => {
            if (a.connected !== b.connected) return a.connected ? -1 : 1;
            if (a.known !== b.known) return a.known ? -1 : 1;
            if (Math.abs(b.signalStrength - a.signalStrength) > 0.05) {
                return b.signalStrength - a.signalStrength;
            }
            return a.ssid.localeCompare(b.ssid);
        });

        root.availableNetworks = list;
    }

    // =========================================================================
    // Wi-Fi Connection & Profile Operations
    // =========================================================================

    function connectToNetwork(ssid: string, key: var): void {
        if (!root.available || !root.wifiEnabled) {
            root.lastError = "Wi-Fi subsystem unavailable";
            return;
        }

        root.connectingSsid = ssid;
        root.lastError = "";
        connectionTimeoutTimer.restart();

        const cleanSsid = root.sanitizeName(ssid);

        let targetNet = null;
        if (Networking.devices && Networking.devices.values) {
            for (let i = 0; i < Networking.devices.values.length; i++) {
                const dev = Networking.devices.values[i];
                if (dev && dev.type === DeviceType.Wifi && dev.networks && dev.networks.values) {
                    for (let j = 0; j < dev.networks.values.length; j++) {
                        const net = dev.networks.values[j];
                        if (net && (net.name === ssid || root.sanitizeName(net.name) === cleanSsid)) {
                            targetNet = net;
                            break;
                        }
                    }
                }
                if (targetNet) break;
            }
        }

        const hasKey = (key !== undefined && key !== null && String(key).length > 0);
        const secret = hasKey ? String(key) : "";

        if (targetNet) {
            if (hasKey) {
                if (typeof targetNet.connectWithPsk === "function") {
                    targetNet.connectWithPsk(secret);
                } else if (typeof targetNet.connect === "function") {
                    targetNet.connect();
                }
            } else {
                if (typeof targetNet.connect === "function") {
                    targetNet.connect();
                }
            }
        } else {
            // Fallback via discrete allowlisted argument array
            if (hasKey) {
                Quickshell.execDetached(["nmcli", "dev", "wifi", "connect", ssid, "password", secret]);
            } else {
                Quickshell.execDetached(["nmcli", "dev", "wifi", "connect", ssid]);
            }
        }
    }

    function disconnectCurrentNetwork(): void {
        connectionTimeoutTimer.stop();
        root.connectingSsid = "";
        if (!root.available || !Networking.devices || !Networking.devices.values) return;
        for (let i = 0; i < Networking.devices.values.length; i++) {
            const dev = Networking.devices.values[i];
            if (dev && dev.type === DeviceType.Wifi && dev.connected) {
                if (typeof dev.disconnect === "function") {
                    dev.disconnect();
                }
                return;
            }
        }
    }

    function forgetNetwork(ssid: string): void {
        if (!root.available || !Networking.devices || !Networking.devices.values) return;
        const cleanSsid = root.sanitizeName(ssid);
        for (let i = 0; i < Networking.devices.values.length; i++) {
            const dev = Networking.devices.values[i];
            if (dev && dev.type === DeviceType.Wifi && dev.networks && dev.networks.values) {
                for (let j = 0; j < dev.networks.values.length; j++) {
                    const net = dev.networks.values[j];
                    if (net && (net.name === ssid || root.sanitizeName(net.name) === cleanSsid)) {
                        if (typeof net.forget === "function") {
                            net.forget();
                        }
                        return;
                    }
                }
            }
        }
        Quickshell.execDetached(["nmcli", "connection", "delete", ssid]);
    }

    // =========================================================================
    // Declarative Reactive Bindings
    // =========================================================================

    Connections {
        target: Networking
        function onConnectivityChanged() {
            root._evaluateNetworkState();
            root._scheduleRebuild();
        }
        function onWifiEnabledChanged() {
            if (!root.wifiEnabled) {
                root.stopScan();
            }
            root._evaluateNetworkState();
            root._scheduleRebuild();
        }
    }

    // Reactively track device model insertions, removals, and state changes
    Instantiator {
        id: deviceTracker
        model: Networking.devices

        delegate: Item {
            id: devDelegate
            required property var modelData

            readonly property var device: modelData

            Binding {
                target: devDelegate.device
                property: "scannerEnabled"
                value: root.wifiEnabled
                when: Boolean(devDelegate.device && devDelegate.device.type === DeviceType.Wifi)
            }

            Connections {
                target: devDelegate.device
                function onConnectedChanged() {
                    root._evaluateNetworkState();
                    root._scheduleRebuild();
                }
                function onStateChanged() {
                    root._evaluateNetworkState();
                    root._scheduleRebuild();
                }
            }

            // For Wi-Fi devices, track individual network model changes and active network state
            Instantiator {
                model: (devDelegate.device && devDelegate.device.networks) ? devDelegate.device.networks : null
                delegate: Item {
                    id: netDelegate
                    required property var modelData
                    readonly property var network: modelData

                    Connections {
                        target: netDelegate.network
                        function onConnectedChanged() {
                            if (netDelegate.network && netDelegate.network.connected) {
                                if (root.connectingSsid === netDelegate.network.name ||
                                    root.connectingSsid === root.sanitizeName(netDelegate.network.name)) {
                                    connectionTimeoutTimer.stop();
                                    root.connectingSsid = "";
                                    root.lastError = "";
                                }
                            }
                            root._evaluateNetworkState();
                            root._scheduleRebuild();
                        }
                        function onNameChanged() {
                            root._evaluateNetworkState();
                            root._scheduleRebuild();
                        }
                        function onSignalStrengthChanged() {
                            root._evaluateNetworkState();
                            root._scheduleRebuild();
                        }
                        function onKnownChanged() {
                            root._scheduleRebuild();
                        }
                        function onConnectionFailed(reason) {
                            let reasonStr = "Connection failed";
                            if (typeof ConnectionFailReason !== "undefined") {
                                switch (reason) {
                                case ConnectionFailReason.NoSecrets:
                                    reasonStr = "Invalid credentials";
                                    break;
                                case ConnectionFailReason.WifiAuthTimeout:
                                    reasonStr = "Authentication timeout";
                                    break;
                                case ConnectionFailReason.WifiNetworkLost:
                                    reasonStr = "Network lost";
                                    break;
                                case ConnectionFailReason.WifiClientFailed:
                                    reasonStr = "Client configuration error";
                                    break;
                                }
                            }
                            const netName = (netDelegate.network && netDelegate.network.name) ? netDelegate.network.name : "";
                            if (root.connectingSsid === netName ||
                                root.connectingSsid === root.sanitizeName(netName)) {
                                connectionTimeoutTimer.stop();
                                root.connectingSsid = "";
                                root.lastError = reasonStr;
                            }
                            root.connectionFailed(netName, reasonStr);
                        }
                    }

                    Component.onCompleted: {
                        root._evaluateNetworkState();
                        root._scheduleRebuild();
                    }
                    Component.onDestruction: {
                        root._evaluateNetworkState();
                        root._scheduleRebuild();
                    }
                }
            }

            Component.onCompleted: {
                root._evaluateNetworkState();
                root._scheduleRebuild();
            }
            Component.onDestruction: {
                root._evaluateNetworkState();
                root._scheduleRebuild();
            }
        }

        onCountChanged: {
            root._evaluateNetworkState();
            root._scheduleRebuild();
        }
    }

    onAvailableChanged: {
        if (!root.available) {
            root.stopScan();
            connectionTimeoutTimer.stop();
            if (root.connectingSsid !== "") {
                const failedSsid = root.connectingSsid;
                root.connectingSsid = "";
                root.lastError = "NetworkManager daemon unavailable";
                root.connectionFailed(failedSsid, "NetworkManager daemon unavailable");
            }
        }
    }

    Component.onCompleted: {
        root._evaluateNetworkState();
        root._scheduleRebuild();
    }
}
