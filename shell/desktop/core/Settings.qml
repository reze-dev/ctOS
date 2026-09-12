pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property int barHeight: 32
    property string compositor: "hyprland"

    // =========================================================================
    // Configuration Path
    // =========================================================================

    // User-configurable path pointing to user settings file.
    // Defaults to "~/.config/ctos/settings.json". Never hardcodes /etc/ctos.
    property string configPath: "~/.config/ctos/settings.json"
    readonly property int defaultBarHeight: 32
    readonly property string defaultCompositor: "hyprland"
    readonly property bool defaultFeaturesCommandDeck: true
    readonly property bool defaultFeaturesNotifications: true
    readonly property bool defaultFeaturesSystemRail: true

    // =========================================================================
    // Default Constants (immutable fallback values)
    // =========================================================================

    readonly property bool defaultReducedMotion: false
    readonly property string defaultTheme: "ctos-dark"
    readonly property string defaultWallpaper: ""
    readonly property bool defaultWidgetCpuHexGridVisible: true
    readonly property bool defaultWidgetNetworkFlowVisible: true
    readonly property bool defaultWidgetRamBlockBarVisible: true
    readonly property bool defaultWidgetNetworkTracerVisible: true
    readonly property bool defaultWidgetAudioSurveillanceVisible: true
    readonly property bool defaultWidgetTargetProfilerVisible: true
    property bool featuresCommandDeck: true
    property bool featuresNotifications: true
    property bool featuresSystemRail: true

    // Indicator if configuration was successfully loaded from disk
    property bool isLoaded: false

    // =========================================================================
    // Typed Public Properties (with safe default values)
    // =========================================================================

    property bool reducedMotion: false
    property bool widgetCpuHexGridVisible: true
    property bool widgetNetworkFlowVisible: true
    property bool widgetRamBlockBarVisible: true
    property bool widgetNetworkTracerVisible: true
    property bool widgetAudioSurveillanceVisible: true
    property bool widgetTargetProfilerVisible: true

    // Dynamic widget positioning state
    property var widgetPositions: ({})

    // Resolved path expanding leading "~/" to user HOME and honoring CTOS_SETTINGS_PATH override
    readonly property string resolvedConfigPath: {
        const envOverride = Quickshell.env("CTOS_SETTINGS_PATH");
        const rawTarget = envOverride ? envOverride : (configPath && configPath.trim() !== "" ? configPath : "~/.config/ctos/settings.json");
        const target = rawTarget || "~/.config/ctos/settings.json";
        if (target.startsWith("~/")) {
            const home = Quickshell.env("HOME") || "";
            return home + target.slice(1);
        }
        return target;
    }
    property string theme: "ctos-dark"
    property string wallpaper: ""

    signal settingsLoadFailed(int error)
    signal settingsSaved
    signal settingsSaveFailed(int error)

    // =========================================================================
    // Signals
    // =========================================================================

    signal settingsLoaded

    function parseConfig(rawText: string): void {
        if (!rawText || rawText.trim() === "") {
            resetToDefaults();
            return;
        }

        try {
            const data = JSON.parse(rawText);
            if (typeof data !== "object" || data === null) {
                resetToDefaults();
                return;
            }

            // reducedMotion: supports flat key or nested animation.reducedMotion
            if (typeof data.reducedMotion === "boolean") {
                reducedMotion = data.reducedMotion;
            } else if (data.animation && typeof data.animation.reducedMotion === "boolean") {
                reducedMotion = data.animation.reducedMotion;
            } else {
                reducedMotion = defaultReducedMotion;
            }

            // featuresCommandDeck: supports flat key or nested features.commandDeck
            if (typeof data.featuresCommandDeck === "boolean") {
                featuresCommandDeck = data.featuresCommandDeck;
            } else if (data.features && typeof data.features.commandDeck === "boolean") {
                featuresCommandDeck = data.features.commandDeck;
            } else {
                featuresCommandDeck = defaultFeaturesCommandDeck;
            }

            // featuresSystemRail: supports flat key or nested features.systemRail
            if (typeof data.featuresSystemRail === "boolean") {
                featuresSystemRail = data.featuresSystemRail;
            } else if (data.features && typeof data.features.systemRail === "boolean") {
                featuresSystemRail = data.features.systemRail;
            } else {
                featuresSystemRail = defaultFeaturesSystemRail;
            }

            // featuresNotifications: supports flat key or nested features.notifications
            if (typeof data.featuresNotifications === "boolean") {
                featuresNotifications = data.featuresNotifications;
            } else if (data.features && typeof data.features.notifications === "boolean") {
                featuresNotifications = data.features.notifications;
            } else {
                featuresNotifications = defaultFeaturesNotifications;
            }

            // barHeight: supports flat key or nested bar.height
            if (typeof data.barHeight === "number" && Number.isInteger(data.barHeight) && data.barHeight > 0) {
                barHeight = data.barHeight;
            } else if (data.bar && typeof data.bar.height === "number" && Number.isInteger(data.bar.height) && data.bar.height > 0) {
                barHeight = data.bar.height;
            } else {
                barHeight = defaultBarHeight;
            }

            // theme: string
            if (typeof data.theme === "string" && data.theme.length > 0) {
                theme = data.theme;
            } else {
                theme = defaultTheme;
            }

            // wallpaper: string
            if (typeof data.wallpaper === "string") {
                wallpaper = data.wallpaper;
            } else {
                wallpaper = defaultWallpaper;
            }

            // compositor: string
            if (typeof data.compositor === "string" && data.compositor.length > 0) {
                compositor = data.compositor;
            } else {
                compositor = defaultCompositor;
            }

            // widgetCpuHexGridVisible: supports flat key or nested widgets.cpuHexGridVisible / widgets.cpuHexGrid
            if (typeof data.widgetCpuHexGridVisible === "boolean") {
                widgetCpuHexGridVisible = data.widgetCpuHexGridVisible;
            } else if (data.widgets && typeof data.widgets.cpuHexGridVisible === "boolean") {
                widgetCpuHexGridVisible = data.widgets.cpuHexGridVisible;
            } else if (data.widgets && typeof data.widgets.cpuHexGrid === "boolean") {
                widgetCpuHexGridVisible = data.widgets.cpuHexGrid;
            } else if (data.widgets && data.widgets.cpuHexGrid && typeof data.widgets.cpuHexGrid.visible === "boolean") {
                widgetCpuHexGridVisible = data.widgets.cpuHexGrid.visible;
            } else {
                widgetCpuHexGridVisible = defaultWidgetCpuHexGridVisible;
            }

            // widgetNetworkFlowVisible: supports flat key or nested widgets.networkFlowVisible / widgets.networkFlow
            if (typeof data.widgetNetworkFlowVisible === "boolean") {
                widgetNetworkFlowVisible = data.widgetNetworkFlowVisible;
            } else if (data.widgets && typeof data.widgets.networkFlowVisible === "boolean") {
                widgetNetworkFlowVisible = data.widgets.networkFlowVisible;
            } else if (data.widgets && typeof data.widgets.networkFlow === "boolean") {
                widgetNetworkFlowVisible = data.widgets.networkFlow;
            } else if (data.widgets && data.widgets.networkFlow && typeof data.widgets.networkFlow.visible === "boolean") {
                widgetNetworkFlowVisible = data.widgets.networkFlow.visible;
            } else {
                widgetNetworkFlowVisible = defaultWidgetNetworkFlowVisible;
            }

            // widgetRamBlockBarVisible: supports flat key or nested widgets.ramBlockBarVisible / widgets.ramBlockBar
            if (typeof data.widgetRamBlockBarVisible === "boolean") {
                widgetRamBlockBarVisible = data.widgetRamBlockBarVisible;
            } else if (data.widgets && typeof data.widgets.ramBlockBarVisible === "boolean") {
                widgetRamBlockBarVisible = data.widgets.ramBlockBarVisible;
            } else if (data.widgets && typeof data.widgets.ramBlockBar === "boolean") {
                widgetRamBlockBarVisible = data.widgets.ramBlockBar;
            } else if (data.widgets && data.widgets.ramBlockBar && typeof data.widgets.ramBlockBar.visible === "boolean") {
                widgetRamBlockBarVisible = data.widgets.ramBlockBar.visible;
            } else {
                widgetRamBlockBarVisible = defaultWidgetRamBlockBarVisible;
            }

            // widgetNetworkTracerVisible: supports flat key or nested widgets.networkTracerVisible / widgets.networkTracer
            if (typeof data.widgetNetworkTracerVisible === "boolean") {
                widgetNetworkTracerVisible = data.widgetNetworkTracerVisible;
            } else if (data.widgets && typeof data.widgets.networkTracerVisible === "boolean") {
                widgetNetworkTracerVisible = data.widgets.networkTracerVisible;
            } else if (data.widgets && typeof data.widgets.networkTracer === "boolean") {
                widgetNetworkTracerVisible = data.widgets.networkTracer;
            } else if (data.widgets && data.widgets.networkTracer && typeof data.widgets.networkTracer.visible === "boolean") {
                widgetNetworkTracerVisible = data.widgets.networkTracer.visible;
            } else {
                widgetNetworkTracerVisible = defaultWidgetNetworkTracerVisible;
            }

            // widgetAudioSurveillanceVisible: supports flat key or nested widgets.audioSurveillanceVisible / widgets.audioSurveillance
            if (typeof data.widgetAudioSurveillanceVisible === "boolean") {
                widgetAudioSurveillanceVisible = data.widgetAudioSurveillanceVisible;
            } else if (data.widgets && typeof data.widgets.audioSurveillanceVisible === "boolean") {
                widgetAudioSurveillanceVisible = data.widgets.audioSurveillanceVisible;
            } else if (data.widgets && typeof data.widgets.audioSurveillance === "boolean") {
                widgetAudioSurveillanceVisible = data.widgets.audioSurveillance;
            } else if (data.widgets && data.widgets.audioSurveillance && typeof data.widgets.audioSurveillance.visible === "boolean") {
                widgetAudioSurveillanceVisible = data.widgets.audioSurveillance.visible;
            } else {
                widgetAudioSurveillanceVisible = defaultWidgetAudioSurveillanceVisible;
            }

            // widgetTargetProfilerVisible: supports flat key or nested widgets.targetProfilerVisible / widgets.targetProfiler
            if (typeof data.widgetTargetProfilerVisible === "boolean") {
                widgetTargetProfilerVisible = data.widgetTargetProfilerVisible;
            } else if (data.widgets && typeof data.widgets.targetProfilerVisible === "boolean") {
                widgetTargetProfilerVisible = data.widgets.targetProfilerVisible;
            } else if (data.widgets && typeof data.widgets.targetProfiler === "boolean") {
                widgetTargetProfilerVisible = data.widgets.targetProfiler;
            } else if (data.widgets && data.widgets.targetProfiler && typeof data.widgets.targetProfiler.visible === "boolean") {
                widgetTargetProfilerVisible = data.widgets.targetProfiler.visible;
            } else {
                widgetTargetProfilerVisible = defaultWidgetTargetProfilerVisible;
            }

            // =================================================================
            // Dynamic Widget Positions Normalization
            // =================================================================
            const newPositions = {};

            function extractPositionConfig(wKey, flatKey) {
                if (data.widgets && typeof data.widgets === "object") {
                    if (data.widgets[wKey] && typeof data.widgets[wKey] === "object") {
                        return data.widgets[wKey];
                    }
                    if (data.widgets[wKey + "Position"] && typeof data.widgets[wKey + "Position"] === "object") {
                        return data.widgets[wKey + "Position"];
                    }
                }
                if (flatKey) {
                    if (data[flatKey + "Position"] && typeof data[flatKey + "Position"] === "object") {
                        return data[flatKey + "Position"];
                    }
                    if (data[flatKey] && typeof data[flatKey] === "object") {
                        return data[flatKey];
                    }
                }
                return null;
            }

            const cpuCfg = extractPositionConfig("cpuHexGrid", "widgetCpuHexGrid");
            newPositions["cpuHexGrid"] = normalizePosition(cpuCfg, { top: true, right: true }, { top: 48, right: 24 });

            const ramCfg = extractPositionConfig("ramBlockBar", "widgetRamBlockBar");
            newPositions["ramBlockBar"] = normalizePosition(ramCfg, { top: true, right: true }, { top: 264, right: 24 });

            const netCfg = extractPositionConfig("networkFlow", "widgetNetworkFlow");
            newPositions["networkFlow"] = normalizePosition(netCfg, { bottom: true, right: true }, { bottom: 24, right: 24 });

            const tracerCfg = extractPositionConfig("networkTracer", "widgetNetworkTracer");
            newPositions["networkTracer"] = normalizePosition(tracerCfg, { top: true, left: true }, { top: 260, left: 24 });

            const audioCfg = extractPositionConfig("audioSurveillance", "widgetAudioSurveillance");
            newPositions["audioSurveillance"] = normalizePosition(audioCfg, { bottom: true, left: true }, { bottom: 24, left: 24 });

            const profilerCfg = extractPositionConfig("targetProfiler", "widgetTargetProfiler");
            newPositions["targetProfiler"] = normalizePosition(profilerCfg, { top: true, left: true }, { top: 48, left: 24 });

            widgetPositions = newPositions;

            isLoaded = true;
            settingsLoaded();
        } catch (err) {
            console.warn("[Settings] Failed to parse settings JSON; falling back to default configuration:", err);
            resetToDefaults();
        }
    }

    function save(): void {
        let data = {};
        try {
            const raw = fileView.text();
            if (raw && raw.trim() !== "") {
                const parsed = JSON.parse(raw);
                if (typeof parsed === "object" && parsed !== null) {
                    data = parsed;
                }
            }
        } catch (e) {
            data = {};
        }

        data.reducedMotion = root.reducedMotion;
        data.featuresCommandDeck = root.featuresCommandDeck;
        data.featuresSystemRail = root.featuresSystemRail;
        data.featuresNotifications = root.featuresNotifications;
        data.barHeight = root.barHeight;
        data.theme = root.theme;
        data.wallpaper = root.wallpaper;
        data.compositor = root.compositor;

        data.widgetCpuHexGridVisible = root.widgetCpuHexGridVisible;
        data.widgetNetworkFlowVisible = root.widgetNetworkFlowVisible;
        data.widgetRamBlockBarVisible = root.widgetRamBlockBarVisible;
        data.widgetNetworkTracerVisible = root.widgetNetworkTracerVisible;
        data.widgetAudioSurveillanceVisible = root.widgetAudioSurveillanceVisible;
        data.widgetTargetProfilerVisible = root.widgetTargetProfilerVisible;

        if (typeof data.widgets === "object" && data.widgets !== null) {
            data.widgets.cpuHexGridVisible = root.widgetCpuHexGridVisible;
            data.widgets.networkFlowVisible = root.widgetNetworkFlowVisible;
            data.widgets.ramBlockBarVisible = root.widgetRamBlockBarVisible;
            data.widgets.networkTracerVisible = root.widgetNetworkTracerVisible;
            data.widgets.audioSurveillanceVisible = root.widgetAudioSurveillanceVisible;
            data.widgets.targetProfilerVisible = root.widgetTargetProfilerVisible;

            const widgetEntries = [
                { id: "cpuHexGrid", isVis: root.widgetCpuHexGridVisible },
                { id: "networkFlow", isVis: root.widgetNetworkFlowVisible },
                { id: "ramBlockBar", isVis: root.widgetRamBlockBarVisible },
                { id: "networkTracer", isVis: root.widgetNetworkTracerVisible },
                { id: "audioSurveillance", isVis: root.widgetAudioSurveillanceVisible },
                { id: "targetProfiler", isVis: root.widgetTargetProfilerVisible }
            ];

            for (let i = 0; i < widgetEntries.length; ++i) {
                const item = widgetEntries[i];
                const id = item.id;
                // If data.widgets[id] is an object (holding positioning data { x, y, anchor, margins }),
                // preserve all positioning properties and update visible property on it.
                if (typeof data.widgets[id] === "object" && data.widgets[id] !== null) {
                    data.widgets[id].visible = item.isVis;
                } else if (typeof data.widgets[id] === "boolean") {
                    data.widgets[id] = item.isVis;
                }
            }
        }

        try {
            fileView.setText(JSON.stringify(data, null, 2) + "\n");
        } catch (err) {
            console.warn("[Settings] Failed to save configuration to disk:", err);
            root.settingsSaveFailed(-1);
        }
    }

    function reload(): void {
        fileView.reload();
    }

    // =========================================================================
    // Helper Methods
    // =========================================================================

    function normalizePosition(cfg: var, defaultAnchors: var, defaultMargins: var): var {
        const defAnchors = Object.assign({ top: false, bottom: false, left: false, right: false }, defaultAnchors || {});
        const defMargins = Object.assign({ top: 0, bottom: 0, left: 0, right: 0 }, defaultMargins || {});

        const res = {
            anchors: {
                top: !!defAnchors.top,
                bottom: !!defAnchors.bottom,
                left: !!defAnchors.left,
                right: !!defAnchors.right
            },
            margins: {
                top: Math.max(0, Math.round(typeof defMargins.top === "number" ? defMargins.top : 0)),
                bottom: Math.max(0, Math.round(typeof defMargins.bottom === "number" ? defMargins.bottom : 0)),
                left: Math.max(0, Math.round(typeof defMargins.left === "number" ? defMargins.left : 0)),
                right: Math.max(0, Math.round(typeof defMargins.right === "number" ? defMargins.right : 0))
            },
            hasExplicitMargin: { top: false, bottom: false, left: false, right: false },
            hasExplicitPosition: false
        };

        if (!cfg || typeof cfg !== "object") {
            return res;
        }

        // Format 1: Direct X/Y coordinates (relative to top-left)
        if (typeof cfg.x === "number" && typeof cfg.y === "number") {
            res.anchors = { top: true, bottom: false, left: true, right: false };
            res.margins = {
                top: Math.max(0, Math.round(cfg.y)),
                bottom: 0,
                left: Math.max(0, Math.round(cfg.x)),
                right: 0
            };
            res.hasExplicitMargin = { top: true, bottom: false, left: true, right: false };
            res.hasExplicitPosition = true;
            return res;
        }

        // Format 2: Named string anchor (e.g. "top-left", "top-right", "bottom-left", "bottom-right")
        if (typeof cfg.anchor === "string") {
            const a = cfg.anchor.toLowerCase().trim();
            res.anchors = {
                top: a.indexOf("top") !== -1,
                bottom: a.indexOf("bottom") !== -1,
                left: a.indexOf("left") !== -1,
                right: a.indexOf("right") !== -1
            };

            const hasOffX = (typeof cfg.offsetX === "number") || (typeof cfg.x === "number");
            const hasOffY = (typeof cfg.offsetY === "number") || (typeof cfg.y === "number");
            const rawOffX = (typeof cfg.offsetX === "number") ? cfg.offsetX : ((typeof cfg.x === "number") ? cfg.x : 0);
            const rawOffY = (typeof cfg.offsetY === "number") ? cfg.offsetY : ((typeof cfg.y === "number") ? cfg.y : 0);
            const offX = Math.max(0, Math.round(rawOffX));
            const offY = Math.max(0, Math.round(rawOffY));

            res.margins = {
                top: res.anchors.top ? offY : 0,
                bottom: res.anchors.bottom ? offY : 0,
                left: res.anchors.left ? offX : 0,
                right: res.anchors.right ? offX : 0
            };

            res.hasExplicitMargin = {
                top: res.anchors.top && hasOffY,
                bottom: res.anchors.bottom && hasOffY,
                left: res.anchors.left && hasOffX,
                right: res.anchors.right && hasOffX
            };

            if (cfg.margins && typeof cfg.margins === "object") {
                if (typeof cfg.margins.top === "number") { res.margins.top = Math.max(0, Math.round(cfg.margins.top)); res.hasExplicitMargin.top = true; }
                if (typeof cfg.margins.bottom === "number") { res.margins.bottom = Math.max(0, Math.round(cfg.margins.bottom)); res.hasExplicitMargin.bottom = true; }
                if (typeof cfg.margins.left === "number") { res.margins.left = Math.max(0, Math.round(cfg.margins.left)); res.hasExplicitMargin.left = true; }
                if (typeof cfg.margins.right === "number") { res.margins.right = Math.max(0, Math.round(cfg.margins.right)); res.hasExplicitMargin.right = true; }
            }

            res.hasExplicitPosition = true;
            return res;
        }

        // Format 3: Explicit anchors & margins maps (or flat properties)
        let hasAnyExplicit = false;
        const srcAnchors = (cfg.anchors && typeof cfg.anchors === "object") ? cfg.anchors : cfg;
        if (typeof srcAnchors.top === "boolean") { res.anchors.top = srcAnchors.top; hasAnyExplicit = true; }
        if (typeof srcAnchors.bottom === "boolean") { res.anchors.bottom = srcAnchors.bottom; hasAnyExplicit = true; }
        if (typeof srcAnchors.left === "boolean") { res.anchors.left = srcAnchors.left; hasAnyExplicit = true; }
        if (typeof srcAnchors.right === "boolean") { res.anchors.right = srcAnchors.right; hasAnyExplicit = true; }

        const srcMargins = (cfg.margins && typeof cfg.margins === "object") ? cfg.margins : cfg;
        if (typeof srcMargins.top === "number") { res.margins.top = Math.max(0, Math.round(srcMargins.top)); res.hasExplicitMargin.top = true; hasAnyExplicit = true; }
        if (typeof srcMargins.bottom === "number") { res.margins.bottom = Math.max(0, Math.round(srcMargins.bottom)); res.hasExplicitMargin.bottom = true; hasAnyExplicit = true; }
        if (typeof srcMargins.left === "number") { res.margins.left = Math.max(0, Math.round(srcMargins.left)); res.hasExplicitMargin.left = true; hasAnyExplicit = true; }
        if (typeof srcMargins.right === "number") { res.margins.right = Math.max(0, Math.round(srcMargins.right)); res.hasExplicitMargin.right = true; hasAnyExplicit = true; }

        if (typeof cfg.x === "number") {
            res.anchors.left = true;
            res.margins.left = Math.max(0, Math.round(cfg.x));
            res.hasExplicitMargin.left = true;
            hasAnyExplicit = true;
        }
        if (typeof cfg.y === "number") {
            res.anchors.top = true;
            res.margins.top = Math.max(0, Math.round(cfg.y));
            res.hasExplicitMargin.top = true;
            hasAnyExplicit = true;
        }

        res.hasExplicitPosition = hasAnyExplicit;
        return res;
    }

    function hasWidgetPosition(widgetId: string): bool {
        return !!(root.widgetPositions && root.widgetPositions[widgetId]);
    }

    function hasWidgetMargin(widgetId: string, side: string): bool {
        const p = root.widgetPositions ? root.widgetPositions[widgetId] : null;
        return !!(p && p.hasExplicitMargin && p.hasExplicitMargin[side]);
    }

    function getWidgetAnchor(widgetId: string, side: string, fallback: bool): bool {
        const p = root.widgetPositions ? root.widgetPositions[widgetId] : null;
        if (p && p.anchors && typeof p.anchors[side] === "boolean") {
            return p.anchors[side];
        }
        return fallback;
    }

    function getWidgetMargin(widgetId: string, side: string, fallback: int): int {
        const p = root.widgetPositions ? root.widgetPositions[widgetId] : null;
        if (p && p.margins && typeof p.margins[side] === "number") {
            return p.margins[side];
        }
        return fallback;
    }

    function resetToDefaults(): void {
        reducedMotion = defaultReducedMotion;
        featuresCommandDeck = defaultFeaturesCommandDeck;
        featuresSystemRail = defaultFeaturesSystemRail;
        featuresNotifications = defaultFeaturesNotifications;
        barHeight = defaultBarHeight;
        theme = defaultTheme;
        wallpaper = defaultWallpaper;
        compositor = defaultCompositor;
        widgetCpuHexGridVisible = defaultWidgetCpuHexGridVisible;
        widgetNetworkFlowVisible = defaultWidgetNetworkFlowVisible;
        widgetRamBlockBarVisible = defaultWidgetRamBlockBarVisible;
        widgetNetworkTracerVisible = defaultWidgetNetworkTracerVisible;
        widgetAudioSurveillanceVisible = defaultWidgetAudioSurveillanceVisible;
        widgetTargetProfilerVisible = defaultWidgetTargetProfilerVisible;

        const defaultPositions = {};
        defaultPositions["cpuHexGrid"] = normalizePosition(null, { top: true, right: true }, { top: 48, right: 24 });
        defaultPositions["ramBlockBar"] = normalizePosition(null, { top: true, right: true }, { top: 264, right: 24 });
        defaultPositions["networkFlow"] = normalizePosition(null, { bottom: true, right: true }, { bottom: 24, right: 24 });
        defaultPositions["networkTracer"] = normalizePosition(null, { top: true, left: true }, { top: 260, left: 24 });
        defaultPositions["audioSurveillance"] = normalizePosition(null, { bottom: true, left: true }, { bottom: 24, left: 24 });
        defaultPositions["targetProfiler"] = normalizePosition(null, { top: true, left: true }, { top: 48, left: 24 });
        widgetPositions = defaultPositions;

        isLoaded = false;
    }

    Component.onCompleted: {
        if (!root.isLoaded) {
            root.resetToDefaults();
        }
    }

    // =========================================================================
    // FileView Loader
    // =========================================================================

    FileView {
        id: fileView

        path: root.resolvedConfigPath
        printErrors: false
        watchChanges: true

        onFileChanged: {
            fileView.reload();
        }
        onSaved: {
            root.settingsSaved();
        }
        onSaveFailed: function (error) {
            console.warn(`[Settings] Configuration save failed for '${root.resolvedConfigPath}' (error code: ${error})`);
            root.settingsSaveFailed(error);
        }
        onLoadFailed: function (error) {
            // Missing or unreadable configuration is handled gracefully without terminating the shell.
            // Never terminate the shell process; safely apply defaults.
            console.info(`[Settings] Configuration file '${root.resolvedConfigPath}' not loaded (error code: ${error}); defaults applied.`);
            root.resetToDefaults();
            root.settingsLoadFailed(error);
        }
        onLoaded: {
            root.parseConfig(fileView.text());
        }
    }
}
