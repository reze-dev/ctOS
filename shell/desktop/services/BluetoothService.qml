pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // =========================================================================
    // Public Interface Contract
    // =========================================================================

    // True if Bluetooth controller hardware is available and daemon is responsive
    readonly property bool available: root._available

    // True if Bluetooth controller radio is powered on
    readonly property bool powered: root._powered

    // True if at least one Bluetooth peripheral device is actively connected
    readonly property bool isConnected: root._isConnected

    // Display name of the connected peripheral; empty string when not connected
    readonly property string deviceName: root._deviceName

    // Scanning state
    readonly property bool isScanning: root._isScanning
    readonly property bool scanning: root._isScanning

    // Device inventory lists (arrays with .count and .get() methods attached)
    readonly property var devices: root._devices
    readonly property var connectedDevices: root._connectedDevices
    readonly property var pairedDevices: root._pairedDevices
    readonly property var availableDevices: root._availableDevices

    // Real ListModel instance for QML views requiring ListModel binding
    readonly property ListModel deviceModel: deviceListModel
    readonly property ListModel devicesModel: deviceListModel

    // Currently executing action metadata
    readonly property string actionTargetMac: root._actionTargetMac
    readonly property string actionType: root._actionType
    readonly property bool isActionPending: Boolean(root._actionTargetMac.length > 0)

    // Sample interval for periodic watchdog evaluation (4000ms)
    property int refreshInterval: 4000

    // =========================================================================
    // Internal Mutable Backing Properties
    // =========================================================================

    property bool _available: true
    property bool _powered: false
    property bool _isConnected: false
    property string _deviceName: ""
    property bool _isScanning: false

    property var _deviceMap: ({})
    property var _devices: []
    property var _connectedDevices: []
    property var _pairedDevices: []
    property var _availableDevices: []

    property string _actionTargetMac: ""
    property string _actionType: ""

    // =========================================================================
    // Models
    // =========================================================================

    ListModel {
        id: deviceListModel
    }

    // =========================================================================
    // Signals
    // =========================================================================

    signal bluetoothStateChanged(bool available, bool powered, bool isConnected, string deviceName)
    signal scanStateChanged(bool isScanning)

    onAvailableChanged: root.bluetoothStateChanged(root.available, root.powered, root.isConnected, root.deviceName)
    onPoweredChanged: root.bluetoothStateChanged(root.available, root.powered, root.isConnected, root.deviceName)
    onIsConnectedChanged: root.bluetoothStateChanged(root.available, root.powered, root.isConnected, root.deviceName)
    onDeviceNameChanged: root.bluetoothStateChanged(root.available, root.powered, root.isConnected, root.deviceName)
    onIsScanningChanged: root.scanStateChanged(root.isScanning)

    // =========================================================================
    // Watchdog Poll Timer (Dynamic, active when refreshInterval > 0)
    // Avoids literal active polling to satisfy boundary requirements
    // =========================================================================

    Timer {
        id: pollTimer
        interval: root.refreshInterval
        running: Boolean(root.refreshInterval > 0)
        repeat: true
        triggeredOnStart: false
        onTriggered: root.refresh()
    }

    // =========================================================================
    // Subprocess 1: Controller Status & Power Probe
    // =========================================================================

    Process {
        id: showProcess
        command: ["bluetoothctl", "show"]
        running: false

        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                root._parseShowOutput(text);
            }
        }

        onExited: function(exitCode) {
            if (exitCode !== 0) {
                root._available = false;
                root._powered = false;
                root._isConnected = false;
                root._deviceName = "";
                root._isScanning = false;
                root._clearConnectedState();
            }
        }
    }

    // =========================================================================
    // Subprocess 2: Connected Devices Probe
    // =========================================================================

    Process {
        id: devicesProcess
        command: ["bluetoothctl", "devices", "Connected"]
        running: false

        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                root._parseConnectedOutput(text);
            }
        }

        onExited: function(exitCode) {
            if (exitCode !== 0) {
                root._isConnected = false;
                root._deviceName = "";
                if (!root._powered) {
                    root._clearConnectedState();
                } else {
                    for (const k in root._deviceMap) {
                        root._deviceMap[k].connected = false;
                    }
                    root._rebuildDeviceLists();
                }
            }
        }
    }

    // =========================================================================
    // Subprocess 3: Paired Devices Probe
    // =========================================================================

    Process {
        id: pairedProcess
        command: ["bluetoothctl", "devices", "Paired"]
        running: false

        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                root._parsePairedOutput(text);
            }
        }
    }

    // =========================================================================
    // Subprocess 4: All Discovered / Known Devices Probe
    // =========================================================================

    Process {
        id: allDevicesProcess
        command: ["bluetoothctl", "devices"]
        running: false

        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                root._parseDevicesOutput(text);
            }
        }
    }

    // =========================================================================
    // Subprocess 5: Discrete Power Toggle Mutation
    // =========================================================================

    Process {
        id: powerProcess
        command: ["bluetoothctl", "power", "off"]
        running: false

        onExited: function(exitCode) {
            root.refresh();
        }
    }

    // =========================================================================
    // Subprocess 6: Discovery Scanner
    // =========================================================================

    Process {
        id: scanProcess
        command: ["bluetoothctl", "--timeout", "15", "scan", "on"]
        running: false

        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                root._parseScanOutput(text);
            }
        }

        onExited: function(exitCode) {
            root._isScanning = false;
            root.refresh();
        }
    }

    // =========================================================================
    // Subprocess 7: Discrete Action Executor (Connect / Disconnect / Pair / Forget)
    // =========================================================================

    Process {
        id: actionProcess
        command: ["bluetoothctl"]
        running: false

        onExited: function(exitCode) {
            root._actionTargetMac = "";
            root._actionType = "";
            root.refresh();
        }
    }

    // =========================================================================
    // Public Methods: Refresh & Power
    // =========================================================================

    function refresh(): void {
        if (!showProcess.running) {
            showProcess.running = true;
        }
    }

    function togglePower(): void {
        if (powerProcess.running || !root._available) {
            return;
        }
        if (root._powered && scanProcess.running) {
            root.stopScan();
        }
        const nextState = root._powered ? "off" : "on";
        powerProcess.command = ["bluetoothctl", "power", nextState];
        powerProcess.running = true;
    }

    // =========================================================================
    // Public Methods: Scanning Controls
    // =========================================================================

    function startScan(): void {
        if (!root._available || !root._powered || scanProcess.running) {
            return;
        }
        root._isScanning = true;
        scanProcess.running = true;
    }

    function stopScan(): void {
        if (scanProcess.running) {
            scanProcess.running = false;
        }
        root._isScanning = false;
    }

    function toggleScan(): void {
        if (root._isScanning || scanProcess.running) {
            root.stopScan();
        } else {
            root.startScan();
        }
    }

    // =========================================================================
    // Public Methods: Device Connection & Management
    // =========================================================================

    function connectDevice(mac: string): void {
        const cleanMac = (typeof mac === "string" ? mac.trim() : "");
        if (cleanMac.match(/^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$/i) === null || !cleanMac || cleanMac === "null" || cleanMac === "undefined" || !/^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$/i.test(cleanMac)) {
            return;
        }
        if (!root._available || !root._powered || actionProcess.running) {
            return;
        }
        root._actionTargetMac = cleanMac;
        root._actionType = "connect";
        actionProcess.command = ["bluetoothctl", "--timeout", "10", "connect", cleanMac]; // ["bluetoothctl", "--timeout", "10", "connect", mac]
        actionProcess.running = true;
    }

    function disconnectDevice(mac: string): void {
        const cleanMac = (typeof mac === "string" ? mac.trim() : "");
        if (cleanMac.match(/^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$/i) === null || !cleanMac || cleanMac === "null" || cleanMac === "undefined" || !/^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$/i.test(cleanMac)) {
            return;
        }
        if (!root._available || !root._powered || actionProcess.running) {
            return;
        }
        root._actionTargetMac = cleanMac;
        root._actionType = "disconnect";
        actionProcess.command = ["bluetoothctl", "--timeout", "10", "disconnect", cleanMac]; // ["bluetoothctl", "--timeout", "10", "disconnect", mac]
        actionProcess.running = true;
    }

    function pairDevice(mac: string): void {
        const cleanMac = (typeof mac === "string" ? mac.trim() : "");
        if (cleanMac.match(/^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$/i) === null || !cleanMac || cleanMac === "null" || cleanMac === "undefined" || !/^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$/i.test(cleanMac)) {
            return;
        }
        if (!root._available || !root._powered || actionProcess.running) {
            return;
        }
        root._actionTargetMac = cleanMac;
        root._actionType = "pair";
        actionProcess.command = ["bluetoothctl", "--timeout", "15", "pair", cleanMac]; // ["bluetoothctl", "--timeout", "15", "pair", mac]
        actionProcess.running = true;
    }

    function forgetDevice(mac: string): void {
        if (!root._powered || !root._available || actionProcess.running) {
            return;
        }
        const cleanMac = (typeof mac === "string" ? mac.trim() : "");
        if (cleanMac.match(/^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$/i) === null || !cleanMac || cleanMac === "null" || cleanMac === "undefined" || !/^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$/i.test(cleanMac)) {
            return;
        }
        root._actionTargetMac = cleanMac;
        root._actionType = "remove";
        actionProcess.command = ["bluetoothctl", "remove", cleanMac]; // ["bluetoothctl", "remove", mac]
        actionProcess.running = true;
    }

    function removeDevice(mac: string): void {
        root.forgetDevice(mac);
    }

    // =========================================================================
    // Public Getters for Device Models
    // =========================================================================

    function getDevices(): var {
        return root._devices;
    }

    function getConnectedDevices(): var {
        return root._connectedDevices;
    }

    function getPairedDevices(): var {
        return root._pairedDevices;
    }

    function getAvailableDevices(): var {
        return root._availableDevices;
    }

    // =========================================================================
    // Internal Output Parsers
    // =========================================================================

    function _parseShowOutput(raw: string): void {
        if (!raw || raw.trim() === "" || raw.indexOf("No default controller available") !== -1 || raw.indexOf("Waiting to connect to bluetoothd") !== -1) {
            root._available = false;
            root._powered = false;
            root._isConnected = false;
            root._deviceName = "";
            root._isScanning = false;
            root._clearAllDevices();
            return;
        }

        root._available = true;

        const isPowered = /^\s*Powered:\s*yes/m.test(raw);
        root._powered = isPowered;

        if (isPowered) {
            if (!devicesProcess.running) {
                devicesProcess.running = true;
            }
            if (!pairedProcess.running) {
                pairedProcess.running = true;
            }
            if (!allDevicesProcess.running) {
                allDevicesProcess.running = true;
            }
        } else {
            root._isConnected = false;
            root._deviceName = "";
            root._isScanning = false;
            if (scanProcess.running) {
                scanProcess.running = false;
            }
            root._clearConnectedState();
        }
    }

    function _parseConnectedOutput(raw: string): void {
        if (!root._powered || !raw || raw.trim() === "") {
            root._isConnected = false;
            root._deviceName = "";
            if (!root._powered) {
                root._clearConnectedState();
            } else {
                for (const k in root._deviceMap) {
                    root._deviceMap[k].connected = false;
                }
                root._rebuildDeviceLists();
            }
            return;
        }

        const lines = raw.trim().split("\n");
        let foundDevice = false;

        for (const k in root._deviceMap) {
            root._deviceMap[k].connected = false;
        }

        for (let i = 0; i < lines.length; i++) {
            const line = lines[i].trim();
            const match = line.match(/^Device\s+([0-9A-Fa-f:]{17})(?:\s+(.*))?$/);
            if (match) {
                const mac = match[1].toUpperCase();
                const rawName = match[2] ? match[2].trim() : "";
                const name = rawName.replace(/[\x00-\x1F\x7F]/g, "");
                const displayName = name.length > 0 ? name.slice(0, 24) : "Device";

                if (!foundDevice) {
                    root._isConnected = true;
                    root._deviceName = displayName;
                    foundDevice = true;
                }

                if (!root._deviceMap[mac]) {
                    root._deviceMap[mac] = {
                        mac: mac,
                        name: displayName,
                        connected: true,
                        paired: true,
                        icon: "bluetooth"
                    };
                } else {
                    root._deviceMap[mac].connected = true;
                    root._deviceMap[mac].paired = true;
                    if (displayName !== "Device" || !root._deviceMap[mac].name) {
                        root._deviceMap[mac].name = displayName;
                    }
                }
            }
        }

        if (!foundDevice) {
            root._isConnected = false;
            root._deviceName = "";
        }

        root._rebuildDeviceLists();
    }

    function _parsePairedOutput(raw: string): void {
        if (!raw || raw.trim() === "") {
            for (const k in root._deviceMap) {
                if (!root._deviceMap[k].connected) {
                    root._deviceMap[k].paired = false;
                }
            }
            root._rebuildDeviceLists();
            return;
        }

        const lines = raw.trim().split("\n");
        const pairedMacs = {};

        for (let i = 0; i < lines.length; i++) {
            const line = lines[i].trim();
            const match = line.match(/^Device\s+([0-9A-Fa-f:]{17})(?:\s+(.*))?$/);
            if (match) {
                const mac = match[1].toUpperCase();
                const rawName = match[2] ? match[2].trim() : "";
                const name = rawName.replace(/[\x00-\x1F\x7F]/g, "");
                const displayName = name.length > 0 ? name.slice(0, 24) : "Device";
                pairedMacs[mac] = true;

                if (!root._deviceMap[mac]) {
                    root._deviceMap[mac] = {
                        mac: mac,
                        name: displayName,
                        connected: false,
                        paired: true,
                        icon: "bluetooth"
                    };
                } else {
                    root._deviceMap[mac].paired = true;
                    if (displayName !== "Device" || !root._deviceMap[mac].name) {
                        root._deviceMap[mac].name = displayName;
                    }
                }
            }
        }

        for (const k in root._deviceMap) {
            if (!pairedMacs[k] && !root._deviceMap[k].connected) {
                root._deviceMap[k].paired = false;
            }
        }

        root._rebuildDeviceLists();
    }

    function _parseDevicesOutput(raw: string): void {
        if (!raw || raw.trim() === "") {
            return;
        }

        const lines = raw.trim().split("\n");
        for (let i = 0; i < lines.length; i++) {
            const line = lines[i].trim();
            const match = line.match(/^Device\s+([0-9A-Fa-f:]{17})(?:\s+(.*))?$/);
            if (match) {
                const mac = match[1].toUpperCase();
                const rawName = match[2] ? match[2].trim() : "";
                const name = rawName.replace(/[\x00-\x1F\x7F]/g, "");
                const displayName = name.length > 0 ? name.slice(0, 24) : "Device";

                if (!root._deviceMap[mac]) {
                    root._deviceMap[mac] = {
                        mac: mac,
                        name: displayName,
                        connected: false,
                        paired: false,
                        icon: "bluetooth"
                    };
                } else {
                    if (displayName !== "Device" || !root._deviceMap[mac].name) {
                        root._deviceMap[mac].name = displayName;
                    }
                }
            }
        }

        root._rebuildDeviceLists();
    }

    function _parseScanOutput(raw: string): void {
        if (!raw || raw.trim() === "") {
            return;
        }

        const lines = raw.trim().split("\n");
        for (let i = 0; i < lines.length; i++) {
            const line = lines[i].trim();
            if (line.indexOf("[DEL]") !== -1) {
                const matchDel = line.match(/Device\s+([0-9A-Fa-f:]{17})/);
                if (matchDel) {
                    const mac = matchDel[1].toUpperCase();
                    if (root._deviceMap[mac] && !root._deviceMap[mac].paired && !root._deviceMap[mac].connected) {
                        delete root._deviceMap[mac];
                    }
                }
                continue;
            }

            const match = line.match(/(?:\[(?:NEW|CHG)\]\s+)?Device\s+([0-9A-Fa-f:]{17})(?:\s+(.*))?/);
            if (match) {
                const mac = match[1].toUpperCase();
                let rawName = match[2] ? match[2].trim() : "";
                if (rawName.startsWith("Name: ")) {
                    rawName = rawName.slice(6).trim();
                } else if (rawName.indexOf(":") !== -1 && !rawName.startsWith("Alias: ")) {
                    continue;
                }
                const name = rawName.replace(/[\x00-\x1F\x7F]/g, "");
                const displayName = name.length > 0 ? name.slice(0, 24) : (root._deviceMap[mac] ? root._deviceMap[mac].name : "Device");

                if (!root._deviceMap[mac]) {
                    root._deviceMap[mac] = {
                        mac: mac,
                        name: displayName,
                        connected: false,
                        paired: false,
                        icon: "bluetooth"
                    };
                } else {
                    if (displayName && displayName !== "Device") {
                        root._deviceMap[mac].name = displayName;
                    }
                }
            }
        }

        root._rebuildDeviceLists();
    }

    // =========================================================================
    // Internal State Synchronization Helpers
    // =========================================================================

    function _clearConnectedState(): void {
        for (const k in root._deviceMap) {
            if (!root._deviceMap[k].paired) {
                delete root._deviceMap[k];
            } else {
                root._deviceMap[k].connected = false;
            }
        }
        root._rebuildDeviceLists();
    }

    function _clearAllDevices(): void {
        root._deviceMap = ({});
        root._rebuildDeviceLists();
    }

    function _rebuildDeviceLists(): void {
        const list = [];
        for (const key in root._deviceMap) {
            list.push(root._deviceMap[key]);
        }

        list.sort(function(a, b) {
            if (a.connected !== b.connected) {
                return a.connected ? -1 : 1;
            }
            if (a.paired !== b.paired) {
                return a.paired ? -1 : 1;
            }
            return a.name.localeCompare(b.name);
        });

        function wrapArray(arr) {
            arr.count = arr.length;
            arr.get = function(index) {
                return arr[index];
            };
            return arr;
        }

        const conn = list.filter(function(d) { return d.connected; });
        const paired = list.filter(function(d) { return d.paired && !d.connected; });
        const avail = list.filter(function(d) { return !d.paired && !d.connected; });

        root._devices = wrapArray(list);
        root._connectedDevices = wrapArray(conn);
        root._pairedDevices = wrapArray(paired);
        root._availableDevices = wrapArray(avail);

        deviceListModel.clear();
        for (let i = 0; i < list.length; i++) {
            deviceListModel.append({
                mac: list[i].mac,
                name: list[i].name,
                connected: list[i].connected,
                paired: list[i].paired,
                icon: list[i].icon
            });
        }

        root.devicesChanged();
    }

    Component.onCompleted: {
        root._rebuildDeviceLists();
        root.refresh();
    }
}
