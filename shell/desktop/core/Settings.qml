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
    property bool featuresCommandDeck: true
    property bool featuresNotifications: true
    property bool featuresSystemRail: true

    // Indicator if configuration was successfully loaded from disk
    property bool isLoaded: false

    // =========================================================================
    // Typed Public Properties (with safe default values)
    // =========================================================================

    property bool reducedMotion: false

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

            isLoaded = true;
            settingsLoaded();
        } catch (err) {
            console.warn("[Settings] Failed to parse settings JSON; falling back to default configuration:", err);
            resetToDefaults();
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
