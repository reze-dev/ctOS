pragma Singleton

import QtQuick
import Quickshell

Singleton {
    id: root

    property int _updateTrigger: 0

    Connections {
        target: (typeof DesktopEntries !== "undefined" && DesktopEntries.applications) ? DesktopEntries.applications : null
        function onValuesChanged(): void {
            root._updateTrigger++;
        }
    }

    readonly property var applications: {
        const _ = root._updateTrigger;
        const raw = (typeof DesktopEntries !== "undefined" && DesktopEntries.applications && DesktopEntries.applications.values) ? DesktopEntries.applications.values : [];
        const list = [];
        for (let i = 0; i < raw.length; ++i) {
            const entry = raw[i];
            if (!entry || entry.noDisplay || !entry.name)
                continue;
            list.push({
                category: "Applications",
                isApp: true,
                id: entry.id || "",
                name: entry.name || "",
                title: entry.name || "",
                genericName: entry.genericName || "",
                comment: entry.comment || "",
                description: entry.genericName || entry.comment || "",
                desc: entry.genericName || entry.comment || "",
                icon: entry.icon || "application-x-executable",
                enabled: true,
                destructive: false,
                disabledNote: "",
                entry: entry,
                execute: function () {
                    if (entry && typeof entry.execute === "function") {
                        entry.execute();
                    }
                }
            });
        }
        list.sort(function (a, b) {
            return a.name.localeCompare(b.name);
        });
        return list;
    }

    readonly property var actions: [
        {
            category: "Actions",
            isApp: false,
            id: "action-toggle-cpu-hex",
            name: "Toggle CPU Hex-Grid",
            title: "Toggle CPU Hex-Grid",
            description: "Show or hide CPU Hex-Grid telemetry widget",
            desc: "Show or hide CPU Hex-Grid telemetry widget",
            icon: "preferences-system",
            enabled: true,
            destructive: false,
            disabledNote: "",
            keywords: ["cpu", "hex", "grid", "core", "load", "utilization", "telemetry", "widget", "toggle"],
            execute: function () {
                Settings.widgetCpuHexGridVisible = !Settings.widgetCpuHexGridVisible;
                Settings.save();
            }
        },
        {
            category: "Actions",
            isApp: false,
            id: "action-toggle-network-flow",
            name: "Toggle Network Flow Matrix",
            title: "Toggle Network Flow Matrix",
            description: "Show or hide Network Flow Matrix telemetry widget",
            desc: "Show or hide Network Flow Matrix telemetry widget",
            icon: "network",
            enabled: true,
            destructive: false,
            disabledNote: "",
            keywords: ["network", "flow", "matrix", "bandwidth", "rx", "tx", "traffic", "telemetry", "widget", "toggle"],
            execute: function () {
                Settings.widgetNetworkFlowVisible = !Settings.widgetNetworkFlowVisible;
                Settings.save();
            }
        },
        {
            category: "Actions",
            isApp: false,
            id: "action-toggle-ram-block",
            name: "Toggle RAM Block Bar",
            title: "Toggle RAM Block Bar",
            description: "Show or hide RAM/Swap Block Bar telemetry widget",
            desc: "Show or hide RAM/Swap Block Bar telemetry widget",
            icon: "drive-harddisk",
            enabled: true,
            destructive: false,
            disabledNote: "",
            keywords: ["ram", "memory", "swap", "block", "bar", "telemetry", "widget", "toggle"],
            execute: function () {
                Settings.widgetRamBlockBarVisible = !Settings.widgetRamBlockBarVisible;
                Settings.save();
            }
        },
        {
            category: "Actions",
            isApp: false,
            id: "action-toggle-all-widgets",
            name: "Toggle All Desktop Widgets",
            title: "Toggle All Desktop Widgets",
            description: "Show or hide all desktop telemetry widgets",
            desc: "Show or hide all desktop telemetry widgets",
            icon: "preferences-system",
            enabled: true,
            destructive: false,
            disabledNote: "",
            keywords: ["all", "widgets", "telemetry", "desktop", "toggle", "cpu", "ram", "network"],
            execute: function () {
                const anyVisible = Settings.widgetCpuHexGridVisible || Settings.widgetNetworkFlowVisible || Settings.widgetRamBlockBarVisible;
                const nextState = !anyVisible;
                Settings.widgetCpuHexGridVisible = nextState;
                Settings.widgetNetworkFlowVisible = nextState;
                Settings.widgetRamBlockBarVisible = nextState;
                Settings.save();
            }
        },
        {
            category: "Actions",
            isApp: false,
            id: "action-lock",
            name: "Lock Session",
            title: "Lock Session",
            description: "Lock workstation immediately",
            desc: "Lock workstation immediately",
            icon: "system-lock-screen",
            enabled: true,
            destructive: false,
            disabledNote: "",
            keywords: ["lock", "screen", "session", "workstation"],
            execute: function () {
                OverlayController.close();
                Quickshell.execDetached(["loginctl", "lock-session"]);
            }
        },
        {
            category: "Actions",
            isApp: false,
            id: "action-system-rail",
            name: "Open System Rail",
            title: "Open System Rail",
            description: "Hardware controls, audio, network, and power",
            desc: "Hardware controls, audio, network, and power",
            icon: "preferences-system",
            enabled: true,
            destructive: false,
            disabledNote: "",
            keywords: ["system", "rail", "settings", "volume", "audio", "network", "wifi", "power", "battery"],
            execute: function () {
                OverlayController.openSystemRail();
            }
        },
        {
            category: "Actions",
            isApp: false,
            id: "action-event-log",
            name: "Open Event Log",
            title: "Open Event Log",
            description: "Recent notifications and alert history",
            desc: "Recent notifications and alert history",
            icon: "preferences-desktop-notification-bell",
            enabled: true,
            destructive: false,
            disabledNote: "",
            keywords: ["event", "log", "notifications", "alerts", "history", "bell"],
            execute: function () {
                OverlayController.openEventLog();
            }
        },
        {
            category: "Actions",
            isApp: false,
            id: "action-logout",
            name: "Log Out",
            title: "Log Out",
            description: "End current desktop session",
            desc: "End current desktop session",
            icon: "system-log-out",
            enabled: true,
            destructive: true,
            disabledNote: "",
            keywords: ["logout", "log", "out", "exit", "quit", "session"],
            execute: function () {
                OverlayController.openSystemRailWithAction("logout");
            }
        },
        {
            category: "Actions",
            isApp: false,
            id: "action-reboot",
            name: "Reboot System",
            title: "Reboot System",
            description: "Restart computer",
            desc: "Restart computer",
            icon: "system-reboot",
            enabled: true,
            destructive: true,
            disabledNote: "",
            keywords: ["reboot", "restart", "system"],
            execute: function () {
                OverlayController.openSystemRailWithAction("reboot");
            }
        },
        {
            category: "Actions",
            isApp: false,
            id: "action-poweroff",
            name: "Power Off",
            title: "Power Off",
            description: "Shut down computer",
            desc: "Shut down computer",
            icon: "system-shutdown",
            enabled: true,
            destructive: true,
            disabledNote: "",
            keywords: ["power", "off", "poweroff", "shutdown", "halt"],
            execute: function () {
                OverlayController.openSystemRailWithAction("poweroff");
            }
        }
    ]

    function _matchesWordBoundary(text, query) {
        if (!text || !query)
            return false;
        const words = text.toLowerCase().split(/[\s\-_.:/]+/);
        for (let i = 0; i < words.length; ++i) {
            if (words[i].startsWith(query))
                return true;
        }
        return false;
    }

    function search(query: string): var {
        const q = (query || "").trim().toLowerCase();

        // 1. Applications Search & Ranking
        const appResults = [];
        const allApps = root.applications;
        for (let i = 0; i < allApps.length; ++i) {
            const app = allApps[i];
            const name = (app.name || "").toLowerCase();
            const generic = (app.genericName || "").toLowerCase();
            const comment = (app.comment || "").toLowerCase();

            let score = -1;
            if (q === "") {
                score = 10;
            } else if (name === q) {
                score = 0;
            } else if (name.startsWith(q)) {
                score = 1;
            } else if (root._matchesWordBoundary(name, q)) {
                score = 2;
            } else if (name.includes(q)) {
                score = 3;
            } else if (generic.startsWith(q) || generic.includes(q) || comment.includes(q)) {
                score = 4;
            }

            if (score >= 0) {
                appResults.push(Object.assign({}, app, {
                    score: score
                }));
            }
        }

        appResults.sort(function (a, b) {
            if (a.score !== b.score)
                return a.score - b.score;
            return a.name.localeCompare(b.name);
        });

        // 2. Actions Search & Ranking
        const actResults = [];
        const allActs = root.actions;
        for (let i = 0; i < allActs.length; ++i) {
            const act = allActs[i];
            const name = (act.name || "").toLowerCase();
            const desc = (act.description || "").toLowerCase();

            let score = -1;
            if (q === "") {
                score = 10;
            } else if (name === q) {
                score = 0;
            } else if (name.startsWith(q)) {
                score = 1;
            } else if (root._matchesWordBoundary(name, q)) {
                score = 2;
            } else if (name.includes(q)) {
                score = 3;
            } else {
                const kw = act.keywords || [];
                for (let k = 0; k < kw.length; ++k) {
                    const keyword = (kw[k] || "").toLowerCase();
                    if (keyword.startsWith(q) || keyword === q) {
                        score = 4;
                        break;
                    }
                }
                if (score < 0) {
                    for (let k = 0; k < kw.length; ++k) {
                        const keyword = (kw[k] || "").toLowerCase();
                        if (keyword.includes(q)) {
                            score = 4;
                            break;
                        }
                    }
                }
                if (score < 0 && desc.includes(q)) {
                    score = 5;
                }
            }

            if (score >= 0) {
                actResults.push(Object.assign({}, act, {
                    score: score
                }));
            }
        }

        actResults.sort(function (a, b) {
            if (a.score !== b.score)
                return a.score - b.score;
            return 0;
        });

        // Return grouped results: Applications first, then Actions
        return appResults.concat(actResults);
    }
}
