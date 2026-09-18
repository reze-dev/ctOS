import QtQuick
import Quickshell
import desktop.core

Scope {
    id: root

    property int passCount: 0
    property int failCount: 0

    function record(testId, desc, condition, details) {
        if (condition) {
            passCount++;
            console.log("[PASS] " + testId + ": " + desc + (details ? " (" + details + ")" : ""));
        } else {
            failCount++;
            console.error("[FAIL] " + testId + ": " + desc + (details ? " (" + details + ")" : ""));
        }
    }

    function runAdversarialTests(): void {
        console.log("=== EXECUTING CHALLENGER 2 ADVERSARIAL TEST HARNESS ===");

        // =============================================================
        // SECTION 1: Exact Action Searches & Preservation
        // =============================================================
        const resLogout = ActionRegistry.search("logout");
        const hasLogout = resLogout.some(function (item) {
            return item.id === "action-logout" && item.score <= 4;
        });
        record("CH2.ACT.01", "Action 'logout' finds action-logout with score <= 4", hasLogout);

        const resLogOutExact = ActionRegistry.search("log out");
        const hasLogOutExact = resLogOutExact.some(function (item) {
            return item.id === "action-logout" && item.score === 0;
        });
        record("CH2.ACT.02", "Action 'log out' exact match yields score 0", hasLogOutExact);

        const resReboot = ActionRegistry.search("reboot");
        const hasReboot = resReboot.some(function (item) {
            return item.id === "action-reboot" && item.score <= 1;
        });
        record("CH2.ACT.03", "Action 'reboot' prefix match yields score <= 1", hasReboot);

        const resRebootSystem = ActionRegistry.search("reboot system");
        const hasRebootSystem = resRebootSystem.some(function (item) {
            return item.id === "action-reboot" && item.score === 0;
        });
        record("CH2.ACT.04", "Action 'reboot system' exact match yields score 0", hasRebootSystem);

        const resPowerOff = ActionRegistry.search("power off");
        const hasPowerOff = resPowerOff.some(function (item) {
            return item.id === "action-poweroff" && item.score === 0;
        });
        record("CH2.ACT.05", "Action 'power off' exact match yields score 0", hasPowerOff);

        const resPowerOffKw = ActionRegistry.search("poweroff");
        const hasPowerOffKw = resPowerOffKw.some(function (item) {
            return item.id === "action-poweroff" && item.score <= 4;
        });
        record("CH2.ACT.06", "Action 'poweroff' keyword match yields score <= 4", hasPowerOffKw);

        const resLock = ActionRegistry.search("lock");
        const hasLock = resLock.some(function (item) {
            return item.id === "action-lock" && item.score <= 1;
        });
        record("CH2.ACT.07", "Action 'lock' prefix match yields score <= 1", hasLock);

        const resLockSession = ActionRegistry.search("lock session");
        const hasLockSession = resLockSession.some(function (item) {
            return item.id === "action-lock" && item.score === 0;
        });
        record("CH2.ACT.08", "Action 'lock session' exact match yields score 0", hasLockSession);

        const resScreen = ActionRegistry.search("screen");
        const hasScreen = resScreen.some(function (item) {
            return item.id === "action-lock" && item.score <= 4;
        });
        record("CH2.ACT.09", "Action 'screen' keyword match for Lock Session yields score <= 4", hasScreen);

        const resSystemRail = ActionRegistry.search("system rail");
        const hasSystemRail = resSystemRail.some(function (item) {
            return item.id === "action-system-rail" && item.score <= 3;
        });
        record("CH2.ACT.10", "Action 'system rail' substring match yields score <= 3", hasSystemRail);

        const resEventLog = ActionRegistry.search("event log");
        const hasEventLog = resEventLog.some(function (item) {
            return item.id === "action-event-log" && item.score <= 3;
        });
        record("CH2.ACT.11", "Action 'event log' substring match yields score <= 3", hasEventLog);

        const resCpu = ActionRegistry.search("cpu");
        const hasCpu = resCpu.some(function (item) {
            return item.id === "action-toggle-cpu-hex" && item.score <= 4;
        });
        record("CH2.ACT.12", "Action 'cpu' keyword match yields score <= 4", hasCpu);

        // =============================================================
        // SECTION 2: Prefix Matching Preservation
        // =============================================================
        const p1 = ActionRegistry._fuzzyScore("Firefox", "fire", "Firefox");
        record("CH2.PRE.01", "Prefix 'fire' in 'Firefox' yields score 1", p1 && p1.score === 1);

        const p2 = ActionRegistry._fuzzyScore("Reboot System", "reboot", "Reboot System");
        record("CH2.PRE.02", "Prefix 'reboot' in 'Reboot System' yields score 1", p2 && p2.score === 1);

        const p3 = ActionRegistry._fuzzyScore("Power Off", "power", "Power Off");
        record("CH2.PRE.03", "Prefix 'power' in 'Power Off' yields score 1", p3 && p3.score === 1);

        const p4 = ActionRegistry._fuzzyScore("Log Out", "log", "Log Out");
        record("CH2.PRE.04", "Prefix 'log' in 'Log Out' yields score 1", p4 && p4.score === 1);

        // =============================================================
        // SECTION 3: Word Boundary Matching Preservation
        // =============================================================
        const wb1 = ActionRegistry._fuzzyScore("Reboot System", "system", "Reboot System");
        record("CH2.WB.01", "Word boundary 'system' in 'Reboot System' yields score 2", wb1 && wb1.score === 2);

        const wb2 = ActionRegistry._fuzzyScore("Power Off", "off", "Power Off");
        record("CH2.WB.02", "Word boundary 'off' in 'Power Off' yields score 2", wb2 && wb2.score === 2);

        const wb3 = ActionRegistry._fuzzyScore("Log Out", "out", "Log Out");
        record("CH2.WB.03", "Word boundary 'out' in 'Log Out' yields score 2", wb3 && wb3.score === 2);

        const wb4 = ActionRegistry._fuzzyScore("Google Chrome", "chrome", "Google Chrome");
        record("CH2.WB.04", "Word boundary 'chrome' in 'Google Chrome' yields score 2", wb4 && wb4.score === 2);

        // =============================================================
        // SECTION 4: Fuzzy Acronym & Subsequence Matching (R1 Core Requirement)
        // =============================================================
        const ac_ff = ActionRegistry._fuzzyScore("Firefox", "ff", "Firefox");
        record("CH2.FUZZY.01", "'ff' in 'Firefox' matches compound initials (score 3.5)", ac_ff && ac_ff.score === 3.5);

        // 'po' starts 'Power Off', so it correctly receives prefix rank (score 1)
        const ac_po = ActionRegistry._fuzzyScore("Power Off", "po", "Power Off");
        record("CH2.FUZZY.02", "'po' in 'Power Off' matches as prefix (score 1)", ac_po && ac_po.score === 1);

        // Initials of 'Reboot System' are 'rs' (R-S)
        const ac_rs = ActionRegistry._fuzzyScore("Reboot System", "rs", "Reboot System");
        record("CH2.FUZZY.03", "'rs' in 'Reboot System' matches as initials (score 3.5)", ac_rs && ac_rs.score === 3.5);

        // 'lo' starts 'Log Out', so it correctly receives prefix rank (score 1)
        const ac_lo = ActionRegistry._fuzzyScore("Log Out", "lo", "Log Out");
        record("CH2.FUZZY.04", "'lo' in 'Log Out' matches as prefix (score 1)", ac_lo && ac_lo.score === 1);

        const ac_ls = ActionRegistry._fuzzyScore("Lock Session", "ls", "Lock Session");
        record("CH2.FUZZY.05", "'ls' in 'Lock Session' matches as initials (score 3.5)", ac_ls && ac_ls.score === 3.5);

        const ac_osr = ActionRegistry._fuzzyScore("Open System Rail", "osr", "Open System Rail");
        record("CH2.FUZZY.06", "'osr' in 'Open System Rail' matches as initials (score 3.5)", ac_osr && ac_osr.score === 3.5);

        const ac_oel = ActionRegistry._fuzzyScore("Open Event Log", "oel", "Open Event Log");
        record("CH2.FUZZY.07", "'oel' in 'Open Event Log' matches as initials (score 3.5)", ac_oel && ac_oel.score === 3.5);

        const fz_fx = ActionRegistry._fuzzyScore("Firefox", "fx", "Firefox");
        record("CH2.FUZZY.08", "'fx' in 'Firefox' matches as general fuzzy (4.0-4.9)", fz_fx && fz_fx.score >= 4.0 && fz_fx.score <= 4.9);

        const fz_rb = ActionRegistry._fuzzyScore("Reboot System", "rb", "Reboot System");
        record("CH2.FUZZY.09", "'rb' in 'Reboot System' matches as general fuzzy (4.0-4.9)", fz_rb && fz_rb.score >= 4.0 && fz_rb.score <= 4.9);

        const fz_pwr = ActionRegistry._fuzzyScore("Power Off", "pwr", "Power Off");
        record("CH2.FUZZY.10", "'pwr' in 'Power Off' matches as general fuzzy (4.0-4.9)", fz_pwr && fz_pwr.score >= 4.0 && fz_pwr.score <= 4.9);

        // =============================================================
        // SECTION 5: Hostile Inputs & Boundary Assault
        // =============================================================
        const specialInputs = [
            "*", "+", "?", "^", "$", "(", ")", "[", "]", "{", "}", "|", "\\", ".", "/", "-",
            "; DROP TABLE apps; --",
            "$(reboot)",
            "| rm -rf /",
            "\"><script>alert(1)</script>",
            "   \t\n   ",
            "a".repeat(1500),
            "café",
            "中文测试",
            "🚀🔥💻"
        ];

        let specialInputsSafe = true;
        for (let i = 0; i < specialInputs.length; ++i) {
            try {
                const sRes = ActionRegistry.search(specialInputs[i]);
                if (!Array.isArray(sRes)) {
                    specialInputsSafe = false;
                    break;
                }
            } catch (err) {
                console.error("Exception thrown on input: " + specialInputs[i] + " -> " + err);
                specialInputsSafe = false;
                break;
            }
        }
        record("CH2.HOSTILE.01", "Hostile & extreme queries handled safely without exceptions", specialInputsSafe);

        // Null and undefined query handling
        let nullHandled = false;
        try {
            const nRes = ActionRegistry.search(null);
            nullHandled = Array.isArray(nRes) && nRes.length > 0;
        } catch (e) {
            nullHandled = false;
        }
        record("CH2.HOSTILE.02", "null query handled safely (returns default results)", nullHandled);

        let undefHandled = false;
        try {
            const uRes = ActionRegistry.search(undefined);
            undefHandled = Array.isArray(uRes) && uRes.length > 0;
        } catch (e) {
            undefHandled = false;
        }
        record("CH2.HOSTILE.03", "undefined query handled safely (returns default results)", undefHandled);

        // =============================================================
        // SECTION 6: Sorting Stability & Invariant Verification
        // =============================================================
        const sampleQueries = ["a", "e", "s", "o", "t", "re", "po", "ff", "fi", "sys"];
        let allSortedMonotonically = true;
        let allAlphabeticalWhenTied = true;
        let allHaveExecuteFunction = true;
        let allCappedAt50 = true;

        for (let q = 0; q < sampleQueries.length; ++q) {
            const qStr = sampleQueries[q];
            const results = ActionRegistry.search(qStr);

            if (results.length > 50) {
                allCappedAt50 = false;
            }

            let lastScore = -1;
            let lastCat = "";
            let lastName = "";

            for (let i = 0; i < results.length; ++i) {
                const item = results[i];

                if (typeof item.execute !== "function") {
                    allHaveExecuteFunction = false;
                }

                if (item.category !== lastCat) {
                    lastCat = item.category;
                    lastScore = item.score;
                    lastName = item.name;
                } else {
                    if (item.score < lastScore) {
                        allSortedMonotonically = false;
                    }
                    if (item.score === lastScore) {
                        if (item.name.localeCompare(lastName) < 0) {
                            allAlphabeticalWhenTied = false;
                        }
                    }
                    lastScore = item.score;
                    lastName = item.name;
                }
            }
        }

        record("CH2.INV.01", "Results within categories sorted monotonically ascending by score", allSortedMonotonically);
        record("CH2.INV.02", "Results with tied scores sorted alphabetically via localeCompare", allAlphabeticalWhenTied);
        record("CH2.INV.03", "All returned items possess executable callback/execute function", allHaveExecuteFunction);
        record("CH2.INV.04", "All search results strictly capped at <= 50 items", allCappedAt50);

        // =============================================================
        // SUMMARY & EXIT
        // =============================================================
        console.log("================================================================");
        console.log("CHALLENGER 2 RESULTS: Passed=" + passCount + ", Failed=" + failCount);
        console.log("================================================================");

        if (failCount === 0) {
            console.log("=== PASS: CHALLENGER 2 VERIFICATION SUCCESSFUL ===");
            Qt.quit();
        } else {
            console.error("=== FAIL: CHALLENGER 2 VERIFICATION FAILED ===");
            Qt.quit();
        }
    }

    Timer {
        id: runTimer
        interval: 300
        repeat: true
        running: true
        property int ticks: 0

        onTriggered: {
            ticks++;
            const appCount = (ActionRegistry && ActionRegistry.applications) ? ActionRegistry.applications.length : 0;
            if (appCount > 0 || ticks >= 5) {
                runTimer.running = false;
                root.runAdversarialTests();
            }
        }
    }
}
