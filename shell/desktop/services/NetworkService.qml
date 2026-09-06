pragma ComponentBehavior: Bound
pragma Singleton

import QtQuick
import QtQml
import Quickshell
import Quickshell.Networking

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

    // Signals
    signal networkStateChanged(bool connected, string connType, string name)

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
    // Declarative Reactive Bindings
    // =========================================================================

    Connections {
        target: Networking
        function onConnectivityChanged() {
            root._evaluateNetworkState();
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

            Connections {
                target: devDelegate.device
                function onConnectedChanged() {
                    root._evaluateNetworkState();
                }
                function onStateChanged() {
                    root._evaluateNetworkState();
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
                            root._evaluateNetworkState();
                        }
                        function onNameChanged() {
                            root._evaluateNetworkState();
                        }
                        function onSignalStrengthChanged() {
                            root._evaluateNetworkState();
                        }
                    }

                    Component.onCompleted: root._evaluateNetworkState()
                    Component.onDestruction: root._evaluateNetworkState()
                }
            }

            Component.onCompleted: root._evaluateNetworkState()
            Component.onDestruction: root._evaluateNetworkState()
        }

        onCountChanged: root._evaluateNetworkState()
    }

    Component.onCompleted: {
        root._evaluateNetworkState();
    }
}
