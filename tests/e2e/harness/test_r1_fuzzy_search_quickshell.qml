import QtQuick
import Quickshell
import desktop.core

Scope {
    id: root

    property int passCount: 0
    property int failCount: 0

    property var deModel: (typeof DesktopEntries !== "undefined") ? DesktopEntries.applications : null

    Connections {
        target: root.deModel
        function onValuesChanged(): void {
            // Keep model subscription active during background scan
        }
    }

    function record(testId, desc, condition, details) {
        if (condition) {
            passCount++;
            console.log("[PASS] " + testId + ": " + desc + (details ? " (" + details + ")" : ""));
        } else {
            failCount++;
            console.error("[FAIL] " + testId + ": " + desc + (details ? " (" + details + ")" : ""));
        }
    }

    function runAllTests(): void {
        console.log("=== EXECUTING R1 FUZZY SEARCH HEADLESS RUNTIME HARNESS ===");

        // -------------------------------------------------------------
        // SECTION 1: Exact Match (Tier 0)
        // -------------------------------------------------------------
        const t0_1 = ActionRegistry._fuzzyScore("firefox", "firefox", "Firefox");
        record("R1.T0.01", "Exact match yields score 0", t0_1 && t0_1.score === 0, "score=" + (t0_1 ? t0_1.score : "null"));

        const t0_2 = ActionRegistry._fuzzyScore("google chrome", "google chrome", "Google Chrome");
        record("R1.T0.02", "Exact match on multi-word string yields score 0", t0_2 && t0_2.score === 0);

        const t0_3 = ActionRegistry._fuzzyScore("Firefox", "firefox", "Firefox");
        record("R1.T0.03", "Exact match is case-insensitive", t0_3 && t0_3.score === 0);

        // -------------------------------------------------------------
        // SECTION 2: Prefix Match (Tier 1)
        // -------------------------------------------------------------
        const t1_1 = ActionRegistry._fuzzyScore("firefox", "fire", "Firefox");
        record("R1.T1.01", "Prefix match 'fire' in 'firefox' yields score 1", t1_1 && t1_1.score === 1, "score=" + (t1_1 ? t1_1.score : "null"));

        const t1_2 = ActionRegistry._fuzzyScore("google chrome", "google", "Google Chrome");
        record("R1.T1.02", "Prefix match 'google' in 'google chrome' yields score 1", t1_2 && t1_2.score === 1);

        const t1_3 = ActionRegistry._fuzzyScore("firefox", "f", "Firefox");
        record("R1.T1.03", "Single character prefix yields score 1", t1_3 && t1_3.score === 1);

        // -------------------------------------------------------------
        // SECTION 3: Word Boundary Match (Tier 2)
        // -------------------------------------------------------------
        const t2_1 = ActionRegistry._fuzzyScore("google chrome", "chrome", "Google Chrome");
        record("R1.T2.01", "Word boundary match 'chrome' in 'google chrome' yields score 2", t2_1 && t2_1.score === 2, "score=" + (t2_1 ? t2_1.score : "null"));

        const t2_2 = ActionRegistry._fuzzyScore("virtual machine manager", "machine", "Virtual Machine Manager");
        record("R1.T2.02", "Word boundary match 'machine' yields score 2", t2_2 && t2_2.score === 2);

        const t2_3 = ActionRegistry._fuzzyScore("visual-studio-code", "studio", "visual-studio-code");
        record("R1.T2.03", "Hyphenated word boundary yields score 2", t2_3 && t2_3.score === 2);

        // -------------------------------------------------------------
        // SECTION 4: Contiguous Substring Match (Tier 3)
        // -------------------------------------------------------------
        const t3_1 = ActionRegistry._fuzzyScore("firefox", "ref", "Firefox");
        record("R1.T3.01", "Contiguous substring 'ref' in 'firefox' yields score 3", t3_1 && t3_1.score === 3, "score=" + (t3_1 ? t3_1.score : "null"));

        const t3_2 = ActionRegistry._fuzzyScore("google chrome", "oogl", "Google Chrome");
        record("R1.T3.02", "Contiguous substring 'oogl' yields score 3", t3_2 && t3_2.score === 3);

        const t3_3 = ActionRegistry._fuzzyScore("easy effects", "sy", "Easy Effects");
        record("R1.T3.03", "Contiguous substring 'sy' yields score 3", t3_3 && t3_3.score === 3);

        // -------------------------------------------------------------
        // SECTION 5: Acronym / Initials Match (Tier 3.5)
        // -------------------------------------------------------------
        const t35_ff = ActionRegistry._fuzzyScore("firefox", "ff", "Firefox");
        record("R1.T35.01", "Fuzzy score matches 'ff' in 'firefox' as initials (score 3.5)", t35_ff && t35_ff.score === 3.5, "score=" + (t35_ff ? t35_ff.score : "null"));
        record("R1.T35.02", "'ff' in 'firefox' detects start-at-start", t35_ff && t35_ff.startsAtStart === true);
        record("R1.T35.03", "'ff' in 'firefox' detects 2 word boundaries", t35_ff && t35_ff.boundaryMatches === 2, "boundaries=" + (t35_ff ? t35_ff.boundaryMatches : "null"));

        const t35_gc = ActionRegistry._fuzzyScore("google chrome", "gc", "Google Chrome");
        record("R1.T35.04", "Initials match 'gc' for 'Google Chrome' yields score 3.5", t35_gc && t35_gc.score === 3.5);
        record("R1.T35.05", "'gc' detects 2 word boundaries", t35_gc && t35_gc.boundaryMatches === 2);

        const t35_vsc = ActionRegistry._fuzzyScore("visual studio code", "vsc", "Visual Studio Code");
        record("R1.T35.06", "Initials match 'vsc' for 'Visual Studio Code' yields score 3.5", t35_vsc && t35_vsc.score === 3.5);
        record("R1.T35.07", "'vsc' detects 3 word boundaries", t35_vsc && t35_vsc.boundaryMatches === 3);

        const t35_vb = ActionRegistry._fuzzyScore("virtualbox", "vb", "VirtualBox");
        record("R1.T35.08", "CamelCase initials 'vb' in 'VirtualBox' yields score 3.5", t35_vb && t35_vb.score === 3.5);

        // -------------------------------------------------------------
        // SECTION 6: General Fuzzy Subsequence Match (Tier 4.0 - 4.9)
        // -------------------------------------------------------------
        const t4_fx = ActionRegistry._fuzzyScore("firefox", "fx", "Firefox");
        record("R1.T4.01", "General fuzzy 'fx' in 'firefox' scores between 4.0 and 4.9", t4_fx && t4_fx.score >= 4.0 && t4_fx.score <= 4.9, "score=" + (t4_fx ? t4_fx.score : "null"));

        const t4_gch = ActionRegistry._fuzzyScore("google chrome", "gch", "Google Chrome");
        record("R1.T4.02", "General fuzzy 'gch' scores between 4.0 and 4.9", t4_gch && t4_gch.score >= 4.0 && t4_gch.score <= 4.9);

        // Span compactness penalty verification
        const t4_compact = ActionRegistry._fuzzyScore("firefox", "fr", "Firefox");
        const t4_spread = ActionRegistry._fuzzyScore("firefox", "fx", "Firefox");
        record("R1.T4.03", "Compact span ('fr', span 3) ranks better than spread span ('fx', span 7)",
               t4_compact && t4_spread && t4_compact.score <= t4_spread.score,
               "compact=" + (t4_compact ? t4_compact.score : "null") + " vs spread=" + (t4_spread ? t4_spread.score : "null"));

        // -------------------------------------------------------------
        // SECTION 7: Rejection / Negative Tests
        // -------------------------------------------------------------
        const rej_1 = ActionRegistry._fuzzyScore("firefox", "xyz", "Firefox");
        record("R1.REJ.01", "Reject non-subsequence 'xyz' in 'firefox'", rej_1 === null);

        const rej_2 = ActionRegistry._fuzzyScore("firefox", "fff", "Firefox");
        record("R1.REJ.02", "Reject query with excess characters 'fff'", rej_2 === null);

        const rej_3 = ActionRegistry._fuzzyScore("firefox", "fireoxx", "Firefox");
        record("R1.REJ.03", "Reject non-matching suffix 'fireoxx'", rej_3 === null);

        // -------------------------------------------------------------
        // SECTION 8: Edge Cases & Robustness
        // -------------------------------------------------------------
        record("R1.EDGE.01", "Empty target text returns null", ActionRegistry._fuzzyScore("", "ff", "") === null);
        record("R1.EDGE.02", "Empty query returns null", ActionRegistry._fuzzyScore("firefox", "", "Firefox") === null);
        record("R1.EDGE.03", "Whitespace-only query returns null", ActionRegistry._fuzzyScore("firefox", "   ", "Firefox") === null);
        record("R1.EDGE.04", "Null target returns null gracefully", ActionRegistry._fuzzyScore(null, "ff", null) === null);
        record("R1.EDGE.05", "Null query returns null gracefully", ActionRegistry._fuzzyScore("firefox", null, "Firefox") === null);
        record("R1.EDGE.06", "Query longer than target returns null", ActionRegistry._fuzzyScore("ff", "firefox", "ff") === null);

        // Special characters without RegExp crash
        const sp_1 = ActionRegistry._fuzzyScore("c++ ide", "c++", "C++ IDE");
        record("R1.EDGE.07", "Query with '+' characters does not crash and matches", sp_1 && sp_1.score === 1);

        const sp_2 = ActionRegistry._fuzzyScore("app[beta]", "[beta]", "app[beta]");
        record("R1.EDGE.08", "Query with bracket characters matches", sp_2 && sp_2.score === 3);

        // -------------------------------------------------------------
        // SECTION 9: ActionRegistry.search() Verification
        // -------------------------------------------------------------
        // Empty query returns applications and actions with score 10
        const emptyResults = ActionRegistry.search("");
        record("R1.SEARCH.01", "Empty query returns array of results", emptyResults && Array.isArray(emptyResults) && emptyResults.length > 0, "count=" + (emptyResults ? emptyResults.length : 0));
        let emptyAllScore10 = true;
        for (let i = 0; i < emptyResults.length; ++i) {
            if (emptyResults[i].score !== 10) {
                emptyAllScore10 = false;
                break;
            }
        }
        record("R1.SEARCH.02", "Empty query items all have score 10", emptyAllScore10);

        // Searching 'ff'
        const resultsFf = ActionRegistry.search("ff");
        record("R1.SEARCH.03", "search('ff') returns results", resultsFf && resultsFf.length > 0, "count=" + (resultsFf ? resultsFf.length : 0));

        let foundFfMatch = false;
        let ffHasFirefox = false;
        for (let i = 0; i < resultsFf.length; ++i) {
            const item = resultsFf[i];
            if (item.name === "Firefox") {
                ffHasFirefox = true;
                record("R1.SEARCH.04", "search('ff') correctly finds Firefox with score 3.5", item.score === 3.5, "score=" + item.score);
            }
            if (item.name && item.name.toLowerCase().includes("ff") || (item.score >= 0 && item.score <= 6)) {
                foundFfMatch = true;
            }
        }
        record("R1.SEARCH.05", "search('ff') returns valid scored items", foundFfMatch);

        // If Firefox is installed on system, assert it was found
        const hasFirefoxInApps = ActionRegistry.applications.some(function (a) { return a.name === "Firefox"; });
        if (hasFirefoxInApps) {
            record("R1.SEARCH.06", "Firefox discovered in system entries and matched by 'ff'", ffHasFirefox);
        } else {
            console.log("[INFO] Firefox not in DesktopEntries; algorithm verification confirmed via direct _fuzzyScore");
        }

        // Score sorting invariant: scores must be monotonically non-decreasing within category
        let sortedProperly = true;
        let lastScore = -1;
        let lastCategory = "";
        for (let i = 0; i < resultsFf.length; ++i) {
            const item = resultsFf[i];
            if (item.category !== lastCategory) {
                lastCategory = item.category;
                lastScore = item.score;
            } else {
                if (item.score < lastScore) {
                    sortedProperly = false;
                    break;
                }
                lastScore = item.score;
            }
        }
        record("R1.SEARCH.07", "search('ff') results are sorted by score ascending", sortedProperly);

        // Actions matching
        const cpuResults = ActionRegistry.search("cpu");
        let foundCpu = false;
        for (let i = 0; i < cpuResults.length; ++i) {
            if (cpuResults[i].id === "action-toggle-cpu-hex") {
                foundCpu = true;
                break;
            }
        }
        record("R1.SEARCH.08", "search('cpu') maintains telemetry action match", foundCpu);

        // Actions fuzzy initials: 'po' for 'Power Off'
        const poResults = ActionRegistry.search("po");
        let foundPowerOff = false;
        for (let i = 0; i < poResults.length; ++i) {
            if (poResults[i].id === "action-poweroff") {
                foundPowerOff = true;
                break;
            }
        }
        record("R1.SEARCH.09", "search('po') matches Power Off action via initials", foundPowerOff);

        // Actions fuzzy initials: 'rb' for 'Reboot System'
        const rbResults = ActionRegistry.search("rb");
        let foundReboot = false;
        for (let i = 0; i < rbResults.length; ++i) {
            if (rbResults[i].id === "action-reboot") {
                foundReboot = true;
                break;
            }
        }
        record("R1.SEARCH.10", "search('rb') matches Reboot System action via initials", foundReboot);

        // Max results capped at 50
        const allRes = ActionRegistry.search("e");
        record("R1.SEARCH.11", "Search results are capped at 50", allRes && allRes.length <= 50, "count=" + (allRes ? allRes.length : 0));

        // -------------------------------------------------------------
        // SUMMARY & EXIT
        // -------------------------------------------------------------
        console.log("================================================================");
        console.log("TEST RESULTS: Passed=" + passCount + ", Failed=" + failCount);
        console.log("================================================================");

        if (failCount === 0) {
            console.log("=== PASS: R1 FUZZY SEARCH RUNTIME HARNESS SUCCESSFUL ===");
            if (typeof Quickshell !== "undefined" && typeof Quickshell.exit === "function") {
                Quickshell.exit(0);
            } else {
                Qt.quit();
            }
        } else {
            console.error("=== FAIL: R1 FUZZY SEARCH RUNTIME HARNESS FAILED ===");
            if (typeof Quickshell !== "undefined" && typeof Quickshell.exit === "function") {
                Quickshell.exit(1);
            } else {
                console.error("ASSERTION_FAILED: " + failCount + " tests failed");
                Qt.quit();
            }
        }
    }

    Timer {
        id: testTimer
        interval: 200
        repeat: true
        running: true
        property int ticks: 0

        onTriggered: {
            ticks++;
            const appCount = (ActionRegistry && ActionRegistry.applications) ? ActionRegistry.applications.length : 0;
            // Run tests once applications are populated or after ~1000ms
            if (appCount > 0 || ticks >= 5) {
                testTimer.running = false;
                root.runAllTests();
            }
        }
    }
}
