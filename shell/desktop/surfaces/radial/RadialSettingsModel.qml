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
    // Lock state is computed, never authored.
    //
    // Every node used to carry `locked` and `lockReason` by hand: 27 of the 31
    // said false and "", and the four that mattered each repeated a service check
    // that their own parent already made -- audio-mic-mute declared the same
    // `!AudioService.micAvailable` as audio-mic, so the two had to be kept in step
    // by hand and nothing enforced that. Worse, nothing derived a child's state
    // from its parent, so a node whose parent was unavailable could still present
    // itself as usable.
    //
    // Now a node declares only when *it* is unavailable, and everything else
    // follows: a node is locked if it or any ancestor above it reports a reason,
    // and the reason shown is the nearest one up. Ancestry comes from
    // RadialTopology, so the tree and the lock state cannot disagree.
    //
    // Evaluated as a binding rather than on demand, so the reads inside
    // unavailable() are tracked: starting awww un-locks the wallpaper subtree
    // without anything asking this to re-run.
    readonly property var categories: _deriveLockState(rawCategories)

    function _deriveLockState(cats: var): var {
        var out = [];
        if (!cats) return out;

        for (var i = 0; i < cats.length; ++i) {
            var cat = cats[i];
            if (!cat || !cat.nodes) { out.push(cat); continue; }

            // Per-node reason first, so lookup below is one pass.
            var reason = {};
            for (var n = 0; n < cat.nodes.length; ++n) {
                var nd = cat.nodes[n];
                var why = "";
                if (typeof nd.unavailable === "function") {
                    try { why = nd.unavailable() || ""; } catch (e) { why = ""; }
                }
                reason[nd.id] = why;
            }

            var nodes = [];
            for (var m = 0; m < cat.nodes.length; ++m) {
                var node = cat.nodes[m];
                var locked = false;
                var why2 = reason[node.id] || "";

                if (why2) {
                    locked = true;
                } else {
                    var ancestors = RadialTopology.ancestorsOf(cat.id, node.id);
                    for (var a = 0; a < ancestors.length; ++a) {
                        if (reason[ancestors[a]]) {
                            locked = true;
                            why2 = reason[ancestors[a]];
                            break;
                        }
                    }
                }

                // Shallow copy: the node keeps its own fields and closures, and
                // gains the two values that used to be typed out by hand.
                var copy = {};
                for (var key in node) copy[key] = node[key];
                copy.locked = locked;
                copy.lockReason = locked ? why2 : "";
                nodes.push(copy);
            }

            out.push(Object.assign({}, cat, { nodes: nodes }));
        }
        return out;
    }

    readonly property var rawCategories: [
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
                    controlType: "toggle",
                    // Was `!Settings.reducedMotion`, so the switch read ON when
                    // motion was switched OFF. execute() flipped the setting the
                    // right way round, which meant the control worked and its
                    // readout was the inverse of the thing it controlled -- the
                    // toggle showed enabled while animations were damped to
                    // nothing. valueText below already reported the setting
                    // honestly, so the two disagreed on screen simultaneously.
                    value: function() { return !Settings.reducedMotion; },
                    valueText: function() { return Settings.reducedMotion ? "REDUCED" : "FULL FX"; },
                    execute: function() {
                        Settings.reducedMotion = !Settings.reducedMotion;
                        Settings.save();
                        root.revision++;
                        console.log("[RadialSettingsModel] MOTION_SET: "
                            + (Settings.reducedMotion ? "reduced" : "full"));
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
                    unavailable: function() {
                        return WallpaperService.available ? "" : "The awww wallpaper daemon is not running.";
                    },
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
                    // A transport state, not the network's name. It used to return
                    // NetworkService.networkName outright, which on wifi is the SSID
                    // and on a wired link is the NetworkManager profile name -- so one
                    // field meant "which network" on one transport and "which profile"
                    // on the other, under a node titled LINK ADAPTER.
                    description: "Primary network interface connection and transport controller.",
                    controlType: "readonly",
                    value: function() { return NetworkService.isConnected ? 1 : 0; },
                    valueText: function() {
                        if (!NetworkService.isConnected) return "OFFLINE";
                        return NetworkService.connectionType === "ethernet" ? "WIRED" : NetworkService.networkName;
                    },
                    execute: function() {}
                },
                {
                    id: "net-flow",
                    title: "FLOW MATRIX",
                    subtitle: "NET.02 // BANDWIDTH",
                    icon: "storage",
                    description: "Real-time bandwidth throughput matrix in ambient status bar.",
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
                    // Was "PACKET SNIFFER": locked behind an invented CAP_NET_RAW
                    // privilege reason with a RESTRICTED readout, promising a packet
                    // inspector that does not exist. Replaced with the one network
                    // capability the shell can actually drive.
                    id: "net-wifi-radio",
                    title: "WI-FI RADIO",
                    subtitle: "NET.04 // RADIO",
                    icon: "wifi",
                    description: "Wi-Fi subsystem radio. Turning it off drops the current association.",
                    unavailable: function() {
                        return NetworkService.available ? "" : "NetworkManager is not available.";
                    },
                    controlType: "toggle",
                    value: function() { return NetworkService.wifiEnabled; },
                    valueText: function() { return NetworkService.wifiEnabled ? "ENABLED" : "DISABLED"; },
                    execute: function() {
                        NetworkService.setWifiEnabled(!NetworkService.wifiEnabled);
                        root.revision++;
                    }
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
                    // Was "DSP SPATIALIZER": locked behind an invented kernel-driver
                    // reason with a RESTRICTED readout, for a filter that does not
                    // exist. Replaced with capture control, which the shell can drive
                    // and which the CCC is being stripped of.
                    id: "audio-mic",
                    title: "MIC VOLUME",
                    subtitle: "AUD.04 // CAPTURE",
                    icon: "microphone",
                    description: AudioService.micAvailable
                        ? "Capture gain for the default input device."
                        : "No input device is available.",
                    unavailable: function() {
                        return AudioService.micAvailable ? "" : "No input device is available.";
                    },
                    controlType: "slider",
                    // The slider contract is minVal/maxVal/step -- those are the
                    // names ContextPanel reads (and the only ones it reads). This
                    // node used minValue/maxValue/stepSize, which nothing reads,
                    // so it silently inherited the defaults minVal 0 / maxVal 100
                    // / step 1. Against a 0..1 gain that made the track render at
                    // micVolume/100 -- empty even at full gain -- and turned a
                    // click anywhere past 1% of the track into setMicVolume(100),
                    // which clamps to 1.0. Off or full, nothing between, and the
                    // step buttons had the same two outcomes.
                    value: function() { return AudioService.micVolume; },
                    minVal: 0.0,
                    maxVal: 1.0,
                    step: 0.02,
                    valueText: function() { return Math.round(AudioService.micVolume * 100) + "%"; },
                    execute: function(value) {
                        if (typeof value === "number") {
                            AudioService.setMicVolume(value);
                            // The track width reads model.revision to establish its
                            // dependency, because value() is called imperatively
                            // inside that binding and QML cannot track through a
                            // function call. Without this the bar does not move.
                            root.revision++;
                        }
                    }
                },
                {
                    id: "audio-mic-mute",
                    title: "MIC MUTE",
                    subtitle: "AUD.05 // CAPTURE",
                    icon: "microphone-slash",
                    description: "Mute the default input device without changing its level.",
                    controlType: "toggle",
                    value: function() { return !AudioService.micMuted; },
                    valueText: function() { return AudioService.micMuted ? "MUTED" : "LIVE"; },
                    execute: function() {
                        AudioService.toggleMicMute();
                        root.revision++;
                    }
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
            description: "Pointer acceleration profile and input device sensing.",
            nodes: [
                {
                    id: "in-engine",
                    title: "INPUT ENGINE",
                    subtitle: "INP.01 // LIBINPUT",
                    icon: "keyboard",
                    description: "Kernel evdev abstraction and libinput driver layer.",
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
                    controlType: "action",
                    actionLabel: "CYCLE PROFILE",
                    value: function() { return 1; },
                    valueText: function() { return "FLAT"; },
                    execute: function() {
                        root.revision++;
                    }
                },

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
                    controlType: "readonly",
                    value: function() { return PowerService.isBatteryPresent ? PowerService.percentage : 100; },
                    valueText: function() { return PowerService.isBatteryPresent ? Math.round(PowerService.percentage) + "%" : "AC MAINS"; },
                    execute: function() {}
                },

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
                    id: "sec-toolkit",
                    title: "TOOLKIT",
                    subtitle: "SEC.04 // TOOLKIT",
                    icon: "terminal",
                    description: ToolkitService.scanned
                        ? "Security and diagnostic tooling present in the Nix profile."
                        : "Scanning the Nix profile for installed tooling.",
                    controlType: "readonly",
                    value: function() { return ToolkitService.installedCount; },
                    valueText: function() {
                        if (!ToolkitService.scanned) return "SCANNING";
                        if (ToolkitService.installedCount === 0) return "NOT INSTALLED";
                        return ToolkitService.installedCount + " / " + ToolkitService.totalCount + " TOOLS";
                    },
                    execute: function() {
                        ToolkitService.rescan();
                        root.revision++;
                    }
                },

                // One node per tool group, generated rather than hand-written so
                // the group list lives in exactly one place. These are readouts,
                // not switches: Nix decides what is installed, so a toggle here
                // would be a control that cannot do what it says.
                ...ToolkitService.groups.map(function (g) {
                    return {
                        id: "sec-tk-" + g.id,
                        title: g.label,
                        subtitle: "TK // " + g.id.toUpperCase(),
                        icon: g.icon,
                        description: g.tools.join(", "),
                        controlType: "readonly",
                        value: function() { return ToolkitService.groupInstalled(g.id); },
                        valueText: function() {
                            if (!ToolkitService.scanned) return "SCANNING";
                            const n = ToolkitService.groupInstalled(g.id);
                            return n + " / " + g.tools.length;
                        },
                        execute: function() {}
                    };
                }),

                {
                    id: "sec-privacy",
                    title: "ALERT PRIVACY",
                    subtitle: "SEC.03 // COOLDOWN",
                    icon: "visibility-off",
                    description: "Enforce anti-spam cooldown intervals on notification popups.",
                    controlType: "toggle",
                    value: function() { return Settings.notificationCooldownSeconds > 0; },
                    valueText: function() { return Settings.notificationCooldownSeconds > 0 ? "ENABLED" : "DISABLED"; },
                    execute: function() {
                        Settings.notificationCooldownSeconds = (Settings.notificationCooldownSeconds > 0 ? 0 : 30);
                        Settings.save();
                        root.revision++;
                    }
                },

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
