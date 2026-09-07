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
            } else {
                widgetRamBlockBarVisible = defaultWidgetRamBlockBarVisible;
            }

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

        if (typeof data.widgets === "object" && data.widgets !== null) {
            data.widgets.cpuHexGridVisible = root.widgetCpuHexGridVisible;
            data.widgets.networkFlowVisible = root.widgetNetworkFlowVisible;
            data.widgets.ramBlockBarVisible = root.widgetRamBlockBarVisible;
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
        isLoaded = false;
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
