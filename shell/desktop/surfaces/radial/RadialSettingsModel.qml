import QtQuick
import Quickshell
import "../../core"
import "../../services"

Item {
    id: root

    // Reactive counter to trigger view refreshes when settings mutate
    property int revision: 0

    Connections {
        target: Settings
        function onSettingsSaved(): void {
            root.revision++;
        }
    }

    Connections {
        target: SystemMonitorService
        function onTelemetryUpdated(): void {
            root.revision++;
        }
    }

    Connections {
        target: NetworkService
        function onNetworkStateChanged(): void {
            root.revision++;
        }
    }

    readonly property int categoryCount: categories.length

    // 8 Categories arranged clockwise starting at 12 o'clock (-90 deg):
    // 0: SYSTEM (-90 deg)
    // 1: APPEARANCE (-45 deg)
    // 2: DESKTOP (0 deg)
    // 3: NETWORK (45 deg)
    // 4: AUDIO (90 deg)
    // 5: INPUT (135 deg)
    // 6: POWER (180 deg)
    // 7: SECURITY (-135 deg)
    readonly property var categories: [
        // =====================================================================
        // 0. SYSTEM
        // =====================================================================
        {
            id: "system",
            name: "SYSTEM",
            subtitle: "KERNEL TELEMETRY // SCHEDULER",
            icon: "gear",
            description: "Hardware telemetry monitors, procfs kernel scheduler, and CPU thread profiling matrix.",
            nodes: [
                {
                    id: "sys-core",
                    title: "KERNEL CORE",
                    subtitle: "SYS.01 // SCHEDULER",
                    icon: "gear",
                    description: "ctOS Linux kernel telemetry subsystem and process scheduler core.",
                    locked: false,
                    lockReason: "",
                    requires: [],
                    pos: { x: 70, y: 0 },
                    edges: ["sys-cpu-hex", "sys-ram-bar"],
                    controlType: "readonly",
                    value: function() { return SystemMonitorService.available ? 1 : 0; },
                    valueText: function() { return SystemMonitorService.available ? "ONLINE" : "OFFLINE"; },
                    execute: function() {}
                },
                {
                    id: "sys-cpu-hex",
                    title: "CPU HEX-GRID",
                    subtitle: "SYS.02 // CORES",
                    icon: "gear",
                    description: "Per-core CPU utilization hex matrix in the ambient desktop status bar.",
                    locked: false,
                    lockReason: "",
                    requires: ["sys-core"],
                    pos: { x: 230, y: -100 },
                    edges: ["sys-profiler"],
                    controlType: "toggle",
                    value: function() { return Settings.widgetCpuHexGridVisible; },
                    valueText: function() { return Settings.widgetCpuHexGridVisible ? "ENABLED" : "DISABLED"; },
                    execute: function() {
                        Settings.widgetCpuHexGridVisible = !Settings.widgetCpuHexGridVisible;
                        Settings.save();
                        root.revision++;
                    }
                },
                {
                    id: "sys-ram-bar",
                    title: "RAM BLOCK-BAR",
                    subtitle: "SYS.03 // MEMORY",
                    icon: "gear",
                    description: "Physical memory and swap page allocation telemetry bar widget.",
                    locked: false,
                    lockReason: "",
                    requires: ["sys-core"],
                    pos: { x: 230, y: 100 },
                    edges: [],
                    controlType: "toggle",
                    value: function() { return Settings.widgetRamBlockBarVisible; },
                    valueText: function() { return Settings.widgetRamBlockBarVisible ? "ENABLED" : "DISABLED"; },
                    execute: function() {
                        Settings.widgetRamBlockBarVisible = !Settings.widgetRamBlockBarVisible;
                        Settings.save();
                        root.revision++;
                    }
                },
                {
                    id: "sys-profiler",
                    title: "TARGET PROFILER",
                    subtitle: "SYS.04 // THREADS",
                    icon: "gear",
                    description: "Active system process profiler and execution latency inspector.",
                    locked: false,
                    lockReason: "",
                    requires: ["sys-cpu-hex"],
                    pos: { x: 390, y: -100 },
                    edges: [],
                    controlType: "toggle",
                    value: function() { return Settings.widgetTargetProfilerVisible; },
                    valueText: function() { return Settings.widgetTargetProfilerVisible ? "ENABLED" : "DISABLED"; },
                    execute: function() {
                        Settings.widgetTargetProfilerVisible = !Settings.widgetTargetProfilerVisible;
                        Settings.save();
                        root.revision++;
                    }
                }
            ]
        },

        // =====================================================================
        // 1. APPEARANCE
        // =====================================================================
        {
            id: "appearance",
            name: "APPEARANCE",
            subtitle: "VISUAL PIPELINE // MOTION",
            icon: "brightness",
            description: "Compositor styling engine, reduced motion dampening, and panel geometry dimensions.",
            nodes: [
                {
                    id: "app-engine",
                    title: "DISPLAY ENGINE",
                    subtitle: "APP.01 // THEME",
                    icon: "brightness",
                    description: "ctOS visual styling pipeline and industrial cyberpunk theme framework.",
                    locked: false,
                    lockReason: "",
                    requires: [],
                    pos: { x: 70, y: 0 },
                    edges: ["app-motion", "app-bar-height"],
                    controlType: "readonly",
                    value: function() { return 1; },
                    valueText: function() { return Settings.theme.toUpperCase(); },
                    execute: function() {}
                },
                {
                    id: "app-motion",
                    title: "TACTICAL MOTION",
                    subtitle: "APP.02 // KINETICS",
                    icon: "brightness",
                    description: "High-speed cybernetic UI animations, transitions, and kinetic physics.",
                    locked: false,
                    lockReason: "",
                    requires: ["app-engine"],
                    pos: { x: 230, y: -100 },
                    edges: ["app-palette"],
                    controlType: "toggle",
                    value: function() { return !Settings.reducedMotion; },
                    valueText: function() { return Settings.reducedMotion ? "REDUCED" : "FULL FX"; },
                    execute: function() {
                        Settings.reducedMotion = !Settings.reducedMotion;
                        Settings.save();
                        root.revision++;
                    }
                },
                {
                    id: "app-bar-height",
                    title: "BAR HEIGHT",
                    subtitle: "APP.03 // GEOMETRY",
                    icon: "brightness",
                    description: "Vertical pixel thickness of the top ambient system telemetry bar.",
                    locked: false,
                    lockReason: "",
                    requires: ["app-engine"],
                    pos: { x: 230, y: 100 },
                    edges: [],
                    controlType: "slider",
                    minVal: 28,
                    maxVal: 48,
                    step: 4,
                    value: function() { return Settings.barHeight; },
                    valueText: function() { return Settings.barHeight + " PX"; },
                    execute: function(val) {
                        if (typeof val !== "number" || isNaN(val)) {
                            val = Settings.barHeight + 4;
                            if (val > 48) val = 28;
                        }
                        Settings.barHeight = Math.max(28, Math.min(48, Math.round(val)));
                        Settings.save();
                        root.revision++;
                    }
                },
                {
                    id: "app-palette",
                    title: "ACID ACCENT",
                    subtitle: "APP.04 // COLORWAY",
                    icon: "brightness",
                    description: "Primary phosphor luminescence wavelength (Acid Green).",
                    locked: false,
                    lockReason: "",
                    requires: ["app-motion"],
                    pos: { x: 390, y: -100 },
                    edges: [],
                    controlType: "readonly",
                    value: function() { return 1; },
                    valueText: function() { return "ACID GREEN"; },
                    execute: function() {}
                }
            ]
        },

        // =====================================================================
        // 2. DESKTOP
        // =====================================================================
        {
            id: "desktop",
            name: "DESKTOP",
            subtitle: "WAYLAND SHELL // SURFACES",
            icon: "check",
            description: "Wayland compositor surfaces, Command Deck application launcher, and side hubs.",
            nodes: [
                {
                    id: "dt-compositor",
                    title: "WAYLAND CORE",
                    subtitle: "DT.01 // SERVER",
                    icon: "check",
                    description: "Native Wayland compositor session (Hyprland / Niri protocols).",
                    locked: false,
                    lockReason: "",
                    requires: [],
                    pos: { x: 70, y: 0 },
                    edges: ["dt-command-deck", "dt-system-rail"],
                    controlType: "readonly",
                    value: function() { return 1; },
                    valueText: function() { return SessionService.compositorName.toUpperCase(); },
                    execute: function() {}
                },
                {
                    id: "dt-command-deck",
                    title: "COMMAND DECK",
                    subtitle: "DT.02 // LAUNCHER",
                    icon: "check",
                    description: "Fuzzy search launcher and system action execution console.",
                    locked: false,
                    lockReason: "",
                    requires: ["dt-compositor"],
                    pos: { x: 230, y: -100 },
                    edges: ["dt-notifications"],
                    controlType: "toggle",
                    value: function() { return Settings.featuresCommandDeck; },
                    valueText: function() { return Settings.featuresCommandDeck ? "ENABLED" : "DISABLED"; },
                    execute: function() {
                        Settings.featuresCommandDeck = !Settings.featuresCommandDeck;
                        Settings.save();
                        root.revision++;
                    }
                },
                {
                    id: "dt-system-rail",
                    title: "SYSTEM RAIL",
                    subtitle: "DT.03 // SIDE HUB",
                    icon: "check",
                    description: "Collapsible side panel with hardware controls and audio routing.",
                    locked: false,
                    lockReason: "",
                    requires: ["dt-compositor"],
                    pos: { x: 230, y: 100 },
                    edges: [],
                    controlType: "toggle",
                    value: function() { return Settings.featuresSystemRail; },
                    valueText: function() { return Settings.featuresSystemRail ? "ENABLED" : "DISABLED"; },
                    execute: function() {
                        Settings.featuresSystemRail = !Settings.featuresSystemRail;
                        Settings.save();
                        root.revision++;
                    }
                },
                {
                    id: "dt-notifications",
                    title: "ALERT TOASTS",
                    subtitle: "DT.04 // NOTIFIER",
                    icon: "check",
                    description: "Tactical notification alert toasts and desktop signal daemon.",
                    locked: false,
                    lockReason: "",
                    requires: ["dt-command-deck"],
                    pos: { x: 390, y: -100 },
                    edges: [],
                    controlType: "toggle",
                    value: function() { return Settings.featuresNotifications; },
                    valueText: function() { return Settings.featuresNotifications ? "ENABLED" : "DISABLED"; },
                    execute: function() {
                        Settings.featuresNotifications = !Settings.featuresNotifications;
                        Settings.save();
                        root.revision++;
                    }
                }
            ]
        },

        // =====================================================================
        // 3. NETWORK
        // =====================================================================
        {
            id: "network",
            name: "NETWORK",
            subtitle: "INTERFACES // PACKET FLOW",
            icon: "wifi",
            description: "NetworkManager client daemon, packet flow throughput, and subnet node tracer.",
            nodes: [
                {
                    id: "net-core",
                    title: "LINK ADAPTER",
                    subtitle: "NET.01 // INTERFACE",
                    icon: "wifi",
                    description: "Primary network interface connection and transport controller.",
                    locked: false,
                    lockReason: "",
                    requires: [],
                    pos: { x: 70, y: 0 },
                    edges: ["net-flow", "net-tracer"],
                    controlType: "readonly",
                    value: function() { return NetworkService.isConnected ? 1 : 0; },
                    valueText: function() { return NetworkService.isConnected ? NetworkService.networkName : "OFFLINE"; },
                    execute: function() {}
                },
                {
                    id: "net-flow",
                    title: "FLOW MATRIX",
                    subtitle: "NET.02 // BANDWIDTH",
                    icon: "wifi",
                    description: "Real-time bandwidth throughput matrix in ambient status bar.",
                    locked: false,
                    lockReason: "",
                    requires: ["net-core"],
                    pos: { x: 230, y: -100 },
                    edges: ["net-sniffer"],
                    controlType: "toggle",
                    value: function() { return Settings.widgetNetworkFlowVisible; },
                    valueText: function() { return Settings.widgetNetworkFlowVisible ? "ENABLED" : "DISABLED"; },
                    execute: function() {
                        Settings.widgetNetworkFlowVisible = !Settings.widgetNetworkFlowVisible;
                        Settings.save();
                        root.revision++;
                    }
                },
                {
                    id: "net-tracer",
                    title: "SUBNET TRACER",
                    subtitle: "NET.03 // LATENCY",
                    icon: "wifi",
                    description: "Hop latency tracer and subnet target ping telemetry widget.",
                    locked: false,
                    lockReason: "",
                    requires: ["net-core"],
                    pos: { x: 230, y: 100 },
                    edges: [],
                    controlType: "toggle",
                    value: function() { return Settings.widgetNetworkTracerVisible; },
                    valueText: function() { return Settings.widgetNetworkTracerVisible ? "ENABLED" : "DISABLED"; },
                    execute: function() {
                        Settings.widgetNetworkTracerVisible = !Settings.widgetNetworkTracerVisible;
                        Settings.save();
                        root.revision++;
                    }
                },
                {
                    id: "net-sniffer",
                    title: "PACKET SNIFFER",
                    subtitle: "NET.04 // SURVEILLANCE",
                    icon: "wifi",
                    description: "Deep packet inspection and socket surveillance matrix.",
                    locked: true,
                    lockReason: "Requires raw CAP_NET_RAW / promiscuous socket privileges.",
                    requires: ["net-flow"],
                    pos: { x: 390, y: -100 },
                    edges: [],
                    controlType: "readonly",
                    value: function() { return 0; },
                    valueText: function() { return "RESTRICTED"; },
                    execute: function() {}
                }
            ]
        },

        // =====================================================================
        // 4. AUDIO
        // =====================================================================
        {
            id: "audio",
            name: "AUDIO",
            subtitle: "PIPEWIRE // SPECTRUM",
            icon: "volume",
            description: "PipeWire sound server output sinks, microphone input gate, and FFT spectrum.",
            nodes: [
                {
                    id: "audio-master",
                    title: "OUTPUT SINK",
                    subtitle: "AUD.01 // PIPEWIRE",
                    icon: "volume",
                    description: "PipeWire master output stream sink: " + (AudioService.sinkName || "Default"),
                    locked: false,
                    lockReason: "",
                    requires: [],
                    pos: { x: 70, y: 0 },
                    edges: ["audio-mute", "audio-spectrum"],
                    controlType: "slider",
                    minVal: 0,
                    maxVal: 100,
                    step: 5,
                    value: function() { return Math.round(AudioService.volume * 100); },
                    valueText: function() { return Math.round(AudioService.volume * 100) + "%"; },
                    execute: function(val) {
                        if (typeof val !== "number" || isNaN(val)) {
                            val = Math.round(AudioService.volume * 100) + 10;
                            if (val > 100) val = 0;
                        }
                        AudioService.setVolume(Math.max(0, Math.min(100, val)) / 100.0);
                        root.revision++;
                    }
                },
                {
                    id: "audio-mute",
                    title: "MUTE TOGGLE",
                    subtitle: "AUD.02 // ATTENUATION",
                    icon: "volume",
                    description: "Master output hardware gate toggle.",
                    locked: false,
                    lockReason: "",
                    requires: ["audio-master"],
                    pos: { x: 230, y: -100 },
                    edges: ["audio-dsp"],
                    controlType: "toggle",
                    value: function() { return !AudioService.muted; },
                    valueText: function() { return AudioService.muted ? "MUTED" : "ACTIVE"; },
                    execute: function() {
                        AudioService.toggleMute();
                        root.revision++;
                    }
                },
                {
                    id: "audio-spectrum",
                    title: "SPECTRUM SURVEILLANCE",
                    subtitle: "AUD.03 // FFT BARS",
                    icon: "volume",
                    description: "Real-time FFT audio surveillance frequency visualization widget.",
                    locked: false,
                    lockReason: "",
                    requires: ["audio-master"],
                    pos: { x: 230, y: 100 },
                    edges: [],
                    controlType: "toggle",
                    value: function() { return Settings.widgetAudioSurveillanceVisible; },
                    valueText: function() { return Settings.widgetAudioSurveillanceVisible ? "ENABLED" : "DISABLED"; },
                    execute: function() {
                        Settings.widgetAudioSurveillanceVisible = !Settings.widgetAudioSurveillanceVisible;
                        Settings.save();
                        root.revision++;
                    }
                },
                {
                    id: "audio-dsp",
                    title: "DSP SPATIALIZER",
                    subtitle: "AUD.04 // FILTER",
                    icon: "volume",
                    description: "Hardware acoustic spatializer and real-time noise cancellation matrix.",
                    locked: true,
                    lockReason: "DSP kernel pipeline locked by audio server driver.",
                    requires: ["audio-mute"],
                    pos: { x: 390, y: -100 },
                    edges: [],
                    controlType: "readonly",
                    value: function() { return 0; },
                    valueText: function() { return "RESTRICTED"; },
                    execute: function() {}
                }
            ]
        },

        // =====================================================================
        // 5. INPUT
        // =====================================================================
        {
            id: "input",
            name: "INPUT",
            subtitle: "LIBINPUT // HID DEVICES",
            icon: "gear",
            description: "Pointer acceleration, keyboard repeat rate, and multi-finger gestures.",
            nodes: [
                {
                    id: "in-engine",
                    title: "INPUT ENGINE",
                    subtitle: "INP.01 // LIBINPUT",
                    icon: "gear",
                    description: "Kernel evdev abstraction and libinput driver layer.",
                    locked: false,
                    lockReason: "",
                    requires: [],
                    pos: { x: 70, y: 0 },
                    edges: ["in-pointer", "in-repeat"],
                    controlType: "readonly",
                    value: function() { return 1; },
                    valueText: function() { return "ACTIVE"; },
                    execute: function() {}
                },
                {
                    id: "in-pointer",
                    title: "POINTER SENSE",
                    subtitle: "INP.02 // CURSOR",
                    icon: "gear",
                    description: "Pointer acceleration profile and sensitivity curves.",
                    locked: false,
                    lockReason: "",
                    requires: ["in-engine"],
                    pos: { x: 230, y: -100 },
                    edges: ["in-gestures"],
                    controlType: "action",
                    actionLabel: "CYCLE PROFILE",
                    value: function() { return 1; },
                    valueText: function() { return "FLAT"; },
                    execute: function() {
                        root.revision++;
                    }
                },
                {
                    id: "in-repeat",
                    title: "KEY REPEAT",
                    subtitle: "INP.03 // TYPEMATIC",
                    icon: "gear",
                    description: "Keyboard repeat delay and typematic strike frequency.",
                    locked: false,
                    lockReason: "",
                    requires: ["in-engine"],
                    pos: { x: 230, y: 100 },
                    edges: [],
                    controlType: "readonly",
                    value: function() { return 1; },
                    valueText: function() { return "25ms / 600ms"; },
                    execute: function() {}
                },
                {
                    id: "in-gestures",
                    title: "TOUCH GESTURES",
                    subtitle: "INP.04 // PRECISION",
                    icon: "gear",
                    description: "Multi-touch workspace navigation and boundary swipe recognition.",
                    locked: true,
                    lockReason: "No supported precision touchpad hardware detected.",
                    requires: ["in-pointer"],
                    pos: { x: 390, y: -100 },
                    edges: [],
                    controlType: "readonly",
                    value: function() { return 0; },
                    valueText: function() { return "RESTRICTED"; },
                    execute: function() {}
                }
            ]
        },

        // =====================================================================
        // 6. POWER
        // =====================================================================
        {
            id: "power",
            name: "POWER",
            subtitle: "UPOWER // GOVERNOR",
            icon: "power",
            description: "Energy governor, battery charge conservation, and display DPMS timeouts.",
            nodes: [
                {
                    id: "pwr-governor",
                    title: "ENERGY DAEMON",
                    subtitle: "PWR.01 // UPOWER",
                    icon: "power",
                    description: "UPower daemon connection and system power supply status.",
                    locked: false,
                    lockReason: "",
                    requires: [],
                    pos: { x: 70, y: 0 },
                    edges: ["pwr-supply", "pwr-sleep"],
                    controlType: "readonly",
                    value: function() { return PowerService.available ? 1 : 0; },
                    valueText: function() { return PowerService.stateText; },
                    execute: function() {}
                },
                {
                    id: "pwr-supply",
                    title: "BATTERY CAPACITY",
                    subtitle: "PWR.02 // CHARGE",
                    icon: "power",
                    description: "Lithium-ion energy storage cell state and charge level.",
                    locked: false,
                    lockReason: "",
                    requires: ["pwr-governor"],
                    pos: { x: 230, y: -100 },
                    edges: ["pwr-threshold"],
                    controlType: "readonly",
                    value: function() { return PowerService.isBatteryPresent ? PowerService.percentage : 100; },
                    valueText: function() { return PowerService.isBatteryPresent ? Math.round(PowerService.percentage) + "%" : "AC MAINS"; },
                    execute: function() {}
                },
                {
                    id: "pwr-sleep",
                    title: "IDLE BLANKING",
                    subtitle: "PWR.03 // DPMS",
                    icon: "power",
                    description: "Display DPMS timeout and screen power conservation.",
                    locked: false,
                    lockReason: "",
                    requires: ["pwr-governor"],
                    pos: { x: 230, y: 100 },
                    edges: [],
                    controlType: "readonly",
                    value: function() { return 1; },
                    valueText: function() { return "300 SEC"; },
                    execute: function() {}
                },
                {
                    id: "pwr-threshold",
                    title: "CHARGE THRESHOLD",
                    subtitle: "PWR.04 // CONSERVATION",
                    icon: "power",
                    description: "Firmware-level 80% battery longevity threshold limit.",
                    locked: true,
                    lockReason: "Requires ACPI battery charge threshold driver support.",
                    requires: ["pwr-supply"],
                    pos: { x: 390, y: -100 },
                    edges: [],
                    controlType: "readonly",
                    value: function() { return 0; },
                    valueText: function() { return "RESTRICTED"; },
                    execute: function() {}
                }
            ]
        },

        // =====================================================================
        // 7. SECURITY
        // =====================================================================
        {
            id: "security",
            name: "SECURITY",
            subtitle: "PAM AUTH // PRIVACY",
            icon: "lock",
            description: "Session lock supervisor, notification privacy filters, and encrypted vault.",
            nodes: [
                {
                    id: "sec-subsystem",
                    title: "SUPERVISOR",
                    subtitle: "SEC.01 // PAM",
                    icon: "lock",
                    description: "ctOS session security supervisor and authentication guard.",
                    locked: false,
                    lockReason: "",
                    requires: [],
                    pos: { x: 70, y: 0 },
                    edges: ["sec-lock", "sec-privacy"],
                    controlType: "readonly",
                    value: function() { return 1; },
                    valueText: function() { return "SECURE"; },
                    execute: function() {}
                },
                {
                    id: "sec-lock",
                    title: "SESSION LOCK",
                    subtitle: "SEC.02 // DISPLAY",
                    icon: "lock",
                    description: "Immediately engage loginctl lock screen overlay.",
                    locked: false,
                    lockReason: "",
                    requires: ["sec-subsystem"],
                    pos: { x: 230, y: -100 },
                    edges: ["sec-vault"],
                    controlType: "action",
                    actionLabel: "LOCK SESSION",
                    value: function() { return 1; },
                    valueText: function() { return "STANDBY"; },
                    execute: function() {
                        SessionService.lock();
                        root.revision++;
                    }
                },
                {
                    id: "sec-privacy",
                    title: "ALERT PRIVACY",
                    subtitle: "SEC.03 // COOLDOWN",
                    icon: "lock",
                    description: "Enforce anti-spam cooldown intervals on notification popups.",
                    locked: false,
                    lockReason: "",
                    requires: ["sec-subsystem"],
                    pos: { x: 230, y: 100 },
                    edges: [],
                    controlType: "toggle",
                    value: function() { return Settings.notificationCooldownSeconds > 0; },
                    valueText: function() { return Settings.notificationCooldownSeconds > 0 ? "ENABLED" : "DISABLED"; },
                    execute: function() {
                        Settings.notificationCooldownSeconds = (Settings.notificationCooldownSeconds > 0 ? 0 : 30);
                        Settings.save();
                        root.revision++;
                    }
                },
                {
                    id: "sec-vault",
                    title: "ENCRYPTED VAULT",
                    subtitle: "SEC.04 // LUKS-HSM",
                    icon: "lock",
                    description: "Hardware security module and encrypted credentials vault.",
                    locked: true,
                    lockReason: "Requires LUKS hardware token or biometric key-ring authorization.",
                    requires: ["sec-lock"],
                    pos: { x: 390, y: -100 },
                    edges: [],
                    controlType: "readonly",
                    value: function() { return 0; },
                    valueText: function() { return "RESTRICTED"; },
                    execute: function() {}
                }
            ]
        }
    ]

    function getCategory(index) {
        if (index < 0 || index >= categories.length) return null;
        return categories[index];
    }

    function getCategoryById(catId) {
        for (var i = 0; i < categories.length; ++i) {
            if (categories[i].id === catId) return categories[i];
        }
        return null;
    }

    function getNode(catIndex, nodeId) {
        var cat = getCategory(catIndex);
        if (!cat || !cat.nodes) return null;
        for (var i = 0; i < cat.nodes.length; ++i) {
            if (cat.nodes[i].id === nodeId) return cat.nodes[i];
        }
        return null;
    }
}
