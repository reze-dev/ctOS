pragma Singleton

import QtQuick
import Quickshell
import "../services"

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
                nameLower: (entry.name || "").toLowerCase(),
                genericNameLower: (entry.genericName || "").toLowerCase(),
                commentLower: (entry.comment || "").toLowerCase(),
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
                },
                callback: function () {
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
                SessionService.lock();
                // Quickshell.execDetached(["loginctl", "lock-session"]);
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

    function _isWordBoundary(textLower, originalText, index) {
        if (index === 0)
            return true;
        if (index < 0 || !textLower || index >= textLower.length)
            return false;

        // 1. Delimiter boundary: character after whitespace or punctuation
        const prevChar = textLower[index - 1];
        if (/[\s\-_.:/+,;@#|()\[\]{}<>]/.test(prevChar))
            return true;

        // 2. CamelCase boundary in originalText: uppercase after lowercase or start of capitalized segment
        if (originalText && index < originalText.length) {
            const curr = originalText[index];
            const prev = originalText[index - 1];
            if (curr >= 'A' && curr <= 'Z') {
                if (prev >= 'a' && prev <= 'z')
                    return true;
                if (index + 1 < originalText.length && originalText[index + 1] >= 'a' && originalText[index + 1] <= 'z' && prev >= 'A' && prev <= 'Z')
                    return true;
            }
        }

        // 3. Digit / letter transition
        const currChar = textLower[index];
        const isDigitCurr = (currChar >= '0' && currChar <= '9');
        const isDigitPrev = (prevChar >= '0' && prevChar <= '9');
        if (isDigitCurr !== isDigitPrev)
            return true;

        // 4. Subword boundary for compound words (e.g. "fox" in "firefox")
        if (index >= 3 && /[a-z]/.test(prevChar)) {
            const sub = textLower.substring(index);
            if (/^(fox|bird|box|shark|pass|vim|office|shell|deck|calc|term|view|pad|edit|play|node)/.test(sub))
                return true;
        }

        return false;
    }

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

    function _fuzzyScore(textLower, queryLower, originalText) {
        if (!textLower || !queryLower || typeof textLower !== "string" || typeof queryLower !== "string")
            return null;

        const tLower = textLower.toLowerCase();
        const qLower = queryLower.toLowerCase().trim();
        const tLen = tLower.length;
        const qLen = qLower.length;

        if (qLen === 0 || qLen > tLen)
            return null;

        // Tier 0: Exact match
        if (tLower === qLower) {
            return {
                score: 0,
                firstMatchIdx: 0,
                lastMatchIdx: tLen - 1,
                span: tLen,
                boundaryMatches: qLen,
                maxConsecutive: qLen,
                compactness: 1.0,
                startsAtStart: true,
                isAcronym: false,
                valueOf: function () {
                    return this.score;
                }
            };
        }

        // Tier 1: Prefix match
        if (tLower.startsWith(qLower)) {
            return {
                score: 1,
                firstMatchIdx: 0,
                lastMatchIdx: qLen - 1,
                span: qLen,
                boundaryMatches: 1,
                maxConsecutive: qLen,
                compactness: 1.0,
                startsAtStart: true,
                isAcronym: false,
                valueOf: function () {
                    return this.score;
                }
            };
        }

        // Tier 2: Word boundary match
        if (root._matchesWordBoundary(tLower, qLower)) {
            let matchIdx = -1;
            const words = tLower.split(/[\s\-_.:/]+/);
            let curOffset = 0;
            for (let w = 0; w < words.length; ++w) {
                const word = words[w];
                const foundPos = tLower.indexOf(word, curOffset);
                if (word.startsWith(qLower)) {
                    matchIdx = foundPos;
                    break;
                }
                curOffset = foundPos + word.length;
            }
            const startIdx = matchIdx >= 0 ? matchIdx : tLower.indexOf(qLower);
            return {
                score: 2,
                firstMatchIdx: startIdx,
                lastMatchIdx: startIdx + qLen - 1,
                span: qLen,
                boundaryMatches: 1,
                maxConsecutive: qLen,
                compactness: 1.0,
                startsAtStart: (startIdx === 0),
                isAcronym: false,
                valueOf: function () {
                    return this.score;
                }
            };
        }

        // Tier 3: Contiguous substring match
        if (tLower.includes(qLower)) {
            const startIdx = tLower.indexOf(qLower);
            return {
                score: 3,
                firstMatchIdx: startIdx,
                lastMatchIdx: startIdx + qLen - 1,
                span: qLen,
                boundaryMatches: 0,
                maxConsecutive: qLen,
                compactness: 1.0,
                startsAtStart: (startIdx === 0),
                isAcronym: false,
                valueOf: function () {
                    return this.score;
                }
            };
        }

        // Tier 3.5: Acronym / Initials match
        // Check if query matches word/subword boundaries in order
        const boundaries = [];
        for (let b = 0; b < tLen; ++b) {
            if (root._isWordBoundary(tLower, originalText, b)) {
                boundaries.push(b);
            }
        }

        let bIdx = 0;
        let bQueryIdx = 0;
        let bFirstIdx = -1;
        let bLastIdx = -1;
        while (bIdx < boundaries.length && bQueryIdx < qLen) {
            const charIdx = boundaries[bIdx];
            if (tLower[charIdx] === qLower[bQueryIdx]) {
                if (bFirstIdx === -1)
                    bFirstIdx = charIdx;
                bLastIdx = charIdx;
                bQueryIdx++;
            }
            bIdx++;
        }

        if (bQueryIdx === qLen) {
            const bSpan = bLastIdx - bFirstIdx + 1;
            return {
                score: 3.5,
                firstMatchIdx: bFirstIdx,
                lastMatchIdx: bLastIdx,
                span: bSpan,
                boundaryMatches: qLen,
                maxConsecutive: 1,
                compactness: qLen / bSpan,
                startsAtStart: (bFirstIdx === 0),
                isAcronym: true,
                valueOf: function () {
                    return this.score;
                }
            };
        }

        // Tier 4.0–4.9: General fuzzy subsequence match
        // Two-pointer linear scan for subsequence matching
        let tIdx = 0;
        let qIdx = 0;
        let firstMatchIdx = -1;
        let lastMatchIdx = -1;
        let consecutiveMatches = 0;
        let maxConsecutive = 0;
        let boundaryMatches = 0;
        let prevMatchIdx = -2;

        while (tIdx < tLen && qIdx < qLen) {
            if (tLower[tIdx] === qLower[qIdx]) {
                if (firstMatchIdx === -1)
                    firstMatchIdx = tIdx;
                lastMatchIdx = tIdx;

                if (root._isWordBoundary(tLower, originalText, tIdx))
                    boundaryMatches++;

                if (tIdx === prevMatchIdx + 1) {
                    consecutiveMatches++;
                    if (consecutiveMatches > maxConsecutive)
                        maxConsecutive = consecutiveMatches;
                } else {
                    consecutiveMatches = 1;
                    if (consecutiveMatches > maxConsecutive)
                        maxConsecutive = consecutiveMatches;
                }

                prevMatchIdx = tIdx;
                qIdx++;
            }
            tIdx++;
        }

        // All characters in query must be found in order
        if (qIdx < qLen)
            return null;

        const span = lastMatchIdx - firstMatchIdx + 1;
        const compactness = qLen / span;
        const startsAtStart = (firstMatchIdx === 0);

        const spanPenalty = (1.0 - compactness) * 0.5;
        const boundaryBonus = Math.min(0.2, (boundaryMatches / qLen) * 0.2);
        const startBonus = startsAtStart ? 0.1 : 0.0;
        const penalty = Math.max(0.0, Math.min(0.9, spanPenalty + 0.3 - boundaryBonus - startBonus));
        const score = Math.round((4.0 + penalty) * 100) / 100;

        return {
            score: score,
            firstMatchIdx: firstMatchIdx,
            lastMatchIdx: lastMatchIdx,
            span: span,
            boundaryMatches: boundaryMatches,
            maxConsecutive: maxConsecutive,
            compactness: compactness,
            startsAtStart: startsAtStart,
            isAcronym: false,
            valueOf: function () {
                return this.score;
            }
        };
    }

    function search(query: string): var {
        const q = (query || "").trim().toLowerCase();

        // 1. Applications Search & Ranking
        const appResults = [];
        const allApps = root.applications;
        let nameMatches = 0;
        for (let i = 0; i < allApps.length; ++i) {
            const app = allApps[i];
            const name = app.nameLower;
            const generic = app.genericNameLower;
            const comment = app.commentLower;

            let score = -1;
            if (q === "") {
                score = 10;
            } else {
                const nameScore = root._fuzzyScore(name, q, app.name || "");
                if (nameScore !== null) {
                    score = nameScore.score;
                    nameMatches++;
                } else if (nameMatches < 15) {
                    if (generic.startsWith(q) || generic.includes(q) || comment.includes(q)) {
                        score = 5.0;
                    } else {
                        const genericScore = root._fuzzyScore(generic, q, app.genericName || "");
                        const commentScore = root._fuzzyScore(comment, q, app.comment || "");
                        if (genericScore !== null || commentScore !== null) {
                            score = 6.0;
                        }
                    }
                }
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
            } else {
                const actNameScore = root._fuzzyScore(name, q, act.name || "");
                if (actNameScore !== null && actNameScore.score <= 3.5) {
                    score = actNameScore.score;
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
                    if (score < 0 && actNameScore !== null) {
                        score = actNameScore.score;
                    }
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
            return a.name.localeCompare(b.name);
        });

        // Return grouped results: Applications first, then Actions
        return appResults.concat(actResults).slice(0, 50);
    }
}
