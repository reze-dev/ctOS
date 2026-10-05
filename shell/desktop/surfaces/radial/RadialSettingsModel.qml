import QtQuick
import Quickshell
import "../../core"
import "../../services"

Item {
    id: root

    // Reactive counter to trigger view refreshes when settings mutate
    property int revision: 0

    // =========================================================================
    // Palette options
    //
    // Display label -> persisted value, kept here rather than inline on the node
    // so valueText() and execute() can both read them. A node object literal has
    // no binding for itself, so an inline list would force these functions to
    // reach through `this`, which works right up until it is destructured.
    //
    // The values are Settings.theme strings and must match Theme._registry's
    // keys. Theme falls back loudly to ctos-pine on anything it does not
    // recognise, so a typo here shows up as the picker disagreeing with the
    // shell rather than as an error at the point of the mistake.
    // =========================================================================
    readonly property var paletteOptions: [
        { label: "PINE", value: "ctos-pine" },
        { label: "ACID", value: "ctos-dark" }
    ]

    function paletteLabel(value) {
        for (var i = 0; i < root.paletteOptions.length; ++i) {
            if (root.paletteOptions[i].value === value) return root.paletteOptions[i].label;
        }
        return String(value);
    }

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
            icon: "cpu",
            description: "Hardware telemetry monitors, procfs kernel scheduler, and CPU thread profiling matrix.",
            nodes: [
                {
                    id: "sys-core",
                    title: "KERNEL CORE",
                    subtitle: "SYS.01 // SCHEDULER",
                    icon: "cpu",
                    description: "ctOS Linux kernel telemetry subsystem and process scheduler core.",
                    locked: false,
                    lockReason: "",
                    requires: [],
                    pos: { x: 98, y: -25 },
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
                    icon: "memory",
                    description: "Per-core CPU utilization hex matrix in the ambient desktop status bar.",
                    locked: false,
                    lockReason: "",
                    requires: ["sys-core"],
                    pos: { x: 238, y: -130 },
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
                    icon: "storage",
                    description: "Physical memory and swap page allocation telemetry bar widget.",
                    locked: false,
                    lockReason: "",
                    requires: ["sys-core"],
                    pos: { x: 260, y: 97 },
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
                    icon: "terminal",
                    description: "Active system process profiler and execution latency inspector.",
                    locked: false,
                    lockReason: "",
                    requires: ["sys-cpu-hex"],
                    pos: { x: 430, y: -61 },
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
            subtitle: "VISUAL PIPELINE // BACKDROP",
            icon: "palette",
            description: "Compositor styling engine, palette, reduced motion dampening, panel geometry, and desktop backdrop.",
            nodes: [
                {
                    id: "app-engine",
                    title: "DISPLAY ENGINE",
                    subtitle: "APP.01 // THEME",
                    icon: "palette",
                    description: "ctOS visual styling pipeline and industrial cyberpunk theme framework.",
                    locked: false,
                    lockReason: "",
                    requires: [],
                    pos: { x: 76, y: 33 },
                    edges: ["app-motion", "app-bar-height", "app-wallpaper"],
                    controlType: "readonly",
                    value: function() { return 1; },
                    valueText: function() { return Settings.theme.toUpperCase(); },
                    execute: function() {}
                },
                {
                    id: "app-motion",
                    title: "TACTICAL MOTION",
                    subtitle: "APP.02 // KINETICS",
                    icon: "timer",
                    description: "High-speed cybernetic UI animations, transitions, and kinetic physics.",
                    locked: false,
                    lockReason: "",
                    requires: ["app-engine"],
                    pos: { x: 214, y: -132 },
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
                    id: "app-wallpaper",
                    title: "WALLPAPER",
                    subtitle: "APP.05 // BACKDROP",
                    icon: "layers",
                    description: WallpaperService.available
                        ? "Desktop backdrop. Fades over one second."
                        : "Desktop backdrop. The awww daemon is not answering, so switching is unavailable.",
                    locked: !WallpaperService.available,
                    lockReason: "The awww wallpaper daemon is not running.",
                    requires: [],
                    pos: { x: 387, y: 130 },
                    edges: [],
                    controlType: "browser",
                    value: function() { return Settings.wallpaper; },
                    valueText: function() { return Settings.wallpaper; },
                    execute: function(name) {
                        if (typeof name !== "string" || name.length === 0) return;

                        // Persist regardless of whether the apply succeeded. The
                        // selection is what the user asked for; if the daemon is
                        // briefly down the service retries on its own, and
                        // refusing to record the choice would make the browser
                        // snap back under them.
                        Settings.wallpaper = name;
                        Settings.save();
                        root.revision++;

                        if (!WallpaperService.apply(name)) {
                            console.warn("[RadialSettingsModel] wallpaper not applied: " + name);
                        } else {
                            console.log("[RadialSettingsModel] WALLPAPER_SET: " + name);
                        }
                    }
                },
                {
                    id: "app-bar-height",
                    title: "BAR HEIGHT",
                    subtitle: "APP.03 // GEOMETRY",
                    icon: "layers",
                    description: "Vertical pixel thickness of the top ambient system telemetry bar.",
                    locked: false,
                    lockReason: "",
                    requires: ["app-engine"],
                    pos: { x: 195, y: 89 },
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
                    title: "COLORWAY",
                    subtitle: "APP.04 // COLORWAY",
                    icon: "palette",
                    description: "Shell palette. Repaints every surface immediately; no restart.",
                    locked: false,
                    lockReason: "",
                    requires: [],
                    pos: { x: 387, y: -130 },
                    edges: [],
                    controlType: "picker",
                    options: root.paletteOptions,
                    value: function() { return Settings.theme; },
                    valueText: function() { return root.paletteLabel(Settings.theme); },
                    execute: function(val) {
                        // No argument means "advance", which is what ENTER reaches
                        // through ContextPanel.executeCurrentNode(). A picker cannot
                        // be arrow-driven -- NavigationController already spends
                        // Left/Right on moving between nodes -- so cycling on ENTER
                        // and selecting by click are the two paths.
                        var opts = root.paletteOptions;
                        var target = val;
                        if (typeof target !== "string" || target.length === 0) {
                            var idx = 0;
                            for (var k = 0; k < opts.length; ++k) {
                                if (opts[k].value === Settings.theme) { idx = k; break; }
                            }
                            target = opts[(idx + 1) % opts.length].value;
                        }
                        if (target === Settings.theme) return;
                        Settings.theme = target;
                        Settings.save();
                        // Settings writes the file asynchronously; bump the model
                        // revision as well so the chips restyle on the same frame
                        // as the Theme repaint rather than a beat later.
                        root.revision++;
                        console.log("[RadialSettingsModel] THEME_SET: " + target);
                    }
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
            icon: "layers",
            description: "Wayland compositor surfaces, Command Deck application launcher, and side hubs.",
            nodes: [
                {
                    id: "dt-compositor",
                    title: "WAYLAND CORE",
                    subtitle: "DT.01 // SERVER",
                    icon: "layers",
                    description: "Native Wayland compositor session (Hyprland / Niri protocols).",
                    locked: false,
                    lockReason: "",
                    requires: [],
                    pos: { x: 59, y: -28 },
                    edges: ["dt-command-deck", "dt-command-center"],
                    controlType: "readonly",
                    value: function() { return 1; },
                    valueText: function() { return SessionService.compositorName.toUpperCase(); },
                    execute: function() {}
                },
                {
                    id: "dt-command-deck",
                    title: "COMMAND DECK",
                    subtitle: "DT.02 // LAUNCHER",
                    icon: "terminal",
                    description: "Fuzzy search launcher and system action execution console.",
                    locked: false,
                    lockReason: "",
                    requires: ["dt-compositor"],
                    pos: { x: 238, y: -105 },
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
                    id: "dt-command-center",
                    title: "COMMAND CENTER",
                    subtitle: "DT.03 // CCC",
                    icon: "power",
                    description: "Adaptive Command & Control Center: hardware controls and audio routing.",
                    locked: false,
                    lockReason: "",
                    requires: ["dt-compositor"],
                    pos: { x: 248, y: 106 },
                    edges: [],
                    controlType: "toggle",
                    value: function() { return Settings.featuresCommandCenter; },
                    valueText: function() { return Settings.featuresCommandCenter ? "ENABLED" : "DISABLED"; },
                    execute: function() {
                        Settings.featuresCommandCenter = !Settings.featuresCommandCenter;
                        Settings.save();
                        root.revision++;
                    }
                },
                {
                    id: "dt-notifications",
                    title: "ALERT TOASTS",
                    subtitle: "DT.04 // NOTIFIER",
                    icon: "warning",
                    description: "Tactical notification alert toasts and desktop signal daemon.",
                    locked: false,
                    lockReason: "",
                    requires: ["dt-command-deck"],
                    pos: { x: 370, y: -93 },
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
                    pos: { x: 75, y: -14 },
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
                    icon: "storage",
                    description: "Real-time bandwidth throughput matrix in ambient status bar.",
                    locked: false,
                    lockReason: "",
                    requires: ["net-core"],
                    pos: { x: 224, y: -131 },
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
                    icon: "bolt",
                    description: "Hop latency tracer and subnet target ping telemetry widget.",
                    locked: false,
                    lockReason: "",
                    requires: ["net-core"],
                    pos: { x: 267, y: 81 },
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
                    icon: "policy",
                    description: "Deep packet inspection and socket surveillance matrix.",
                    locked: true,
                    lockReason: "Requires raw CAP_NET_RAW / promiscuous socket privileges.",
                    requires: ["net-flow"],
                    pos: { x: 418, y: -109 },
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
            icon: "tune",
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
                    pos: { x: 50, y: 19 },
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
                    icon: "volume-mute",
                    description: "Master output hardware gate toggle.",
                    locked: false,
                    lockReason: "",
                    requires: ["audio-master"],
                    pos: { x: 238, y: -106 },
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
                    icon: "tune",
                    description: "Real-time FFT audio surveillance frequency visualization widget.",
                    locked: false,
                    lockReason: "",
                    requires: ["audio-master"],
                    pos: { x: 261, y: 88 },
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
                    icon: "memory",
                    description: "Hardware acoustic spatializer and real-time noise cancellation matrix.",
                    locked: true,
                    lockReason: "DSP kernel pipeline locked by audio server driver.",
                    requires: ["audio-mute"],
                    pos: { x: 391, y: -133 },
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
            icon: "keyboard",
            description: "Pointer acceleration, keyboard repeat rate, and multi-finger gestures.",
            nodes: [
                {
                    id: "in-engine",
                    title: "INPUT ENGINE",
                    subtitle: "INP.01 // LIBINPUT",
                    icon: "keyboard",
                    description: "Kernel evdev abstraction and libinput driver layer.",
                    locked: false,
                    lockReason: "",
                    requires: [],
                    pos: { x: 59, y: -36 },
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
                    icon: "mouse",
                    description: "Pointer acceleration profile and sensitivity curves.",
                    locked: false,
                    lockReason: "",
                    requires: ["in-engine"],
                    pos: { x: 230, y: -89 },
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
                    icon: "timer",
                    description: "Keyboard repeat delay and typematic strike frequency.",
                    locked: false,
                    lockReason: "",
                    requires: ["in-engine"],
                    pos: { x: 224, y: 68 },
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
                    icon: "layers",
                    description: "Multi-touch workspace navigation and boundary swipe recognition.",
                    locked: true,
                    lockReason: "No supported precision touchpad hardware detected.",
                    requires: ["in-pointer"],
                    pos: { x: 377, y: -68 },
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
            icon: "bolt",
            description: "Energy governor, battery charge conservation, and display DPMS timeouts.",
            nodes: [
                {
                    id: "pwr-governor",
                    title: "ENERGY DAEMON",
                    subtitle: "PWR.01 // UPOWER",
                    icon: "bolt",
                    description: "UPower daemon connection and system power supply status.",
                    locked: false,
                    lockReason: "",
                    requires: [],
                    pos: { x: 70, y: -13 },
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
                    icon: "battery",
                    description: "Lithium-ion energy storage cell state and charge level.",
                    locked: false,
                    lockReason: "",
                    requires: ["pwr-governor"],
                    pos: { x: 253, y: -90 },
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
                    icon: "timer",
                    description: "Display DPMS timeout and screen power conservation.",
                    locked: false,
                    lockReason: "",
                    requires: ["pwr-governor"],
                    pos: { x: 248, y: 78 },
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
                    icon: "battery-charging",
                    description: "Firmware-level 80% battery longevity threshold limit.",
                    locked: true,
                    lockReason: "Requires ACPI battery charge threshold driver support.",
                    requires: ["pwr-supply"],
                    pos: { x: 383, y: -123 },
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
            icon: "shield",
            description: "Session lock supervisor, notification privacy filters, and encrypted vault.",
            nodes: [
                {
                    id: "sec-subsystem",
                    title: "SUPERVISOR",
                    subtitle: "SEC.01 // PAM",
                    icon: "verified-user",
                    description: "ctOS session security supervisor and authentication guard.",
                    locked: false,
                    lockReason: "",
                    requires: [],
                    pos: { x: 61, y: 31 },
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
                    pos: { x: 258, y: -107 },
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
                    icon: "visibility-off",
                    description: "Enforce anti-spam cooldown intervals on notification popups.",
                    locked: false,
                    lockReason: "",
                    requires: ["sec-subsystem"],
                    pos: { x: 264, y: 114 },
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
                    icon: "vpn-key",
                    description: "Hardware security module and encrypted credentials vault.",
                    locked: true,
                    lockReason: "Requires LUKS hardware token or biometric key-ring authorization.",
                    requires: ["sec-lock"],
                    pos: { x: 424, y: -89 },
                    edges: [],
                    controlType: "readonly",
                    value: function() { return 0; },
                    valueText: function() { return "RESTRICTED"; },
                }
            ]

        } // END OF CATEGORIES
    ]


    readonly property int categoryCount: categories ? categories.length : 0

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
