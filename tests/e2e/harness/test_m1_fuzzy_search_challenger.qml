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
            console.log("[CHALLENGE-PASS] " + testId + ": " + desc + (details ? " (" + details + ")" : ""));
        } else {
            failCount++;
            console.error("[CHALLENGE-FAIL] " + testId + ": " + desc + (details ? " (" + details + ")" : ""));
        }
    }

    function runAllAdversarialTests(): void {
        console.log("================================================================");
        console.log("=== EXECUTING M1 FUZZY SEARCH EMPIRICAL CHALLENGER SUITE ===");
        console.log("================================================================");

        // =============================================================
        // GROUP 1: Acronyms vs Subsequences vs Substrings
        // =============================================================
        // 1.1 "ff" -> "Firefox": Acronym match at score 3.5
        const sc_ff = ActionRegistry._fuzzyScore("firefox", "ff", "Firefox");
        record("ADV.ACR.01", "'ff' on 'Firefox' scores 3.5 as acronym",
               sc_ff && sc_ff.score === 3.5 && sc_ff.isAcronym === true,
               "score=" + (sc_ff ? sc_ff.score : "null"));

        // 1.2 "gc" -> "Google Chrome": Acronym match at score 3.5
        const sc_gc = ActionRegistry._fuzzyScore("google chrome", "gc", "Google Chrome");
        record("ADV.ACR.02", "'gc' on 'Google Chrome' scores 3.5 as acronym",
               sc_gc && sc_gc.score === 3.5 && sc_gc.isAcronym === true,
               "score=" + (sc_gc ? sc_gc.score : "null"));

        // 1.3 "vsc" -> "Visual Studio Code": Acronym match at score 3.5
        const sc_vsc = ActionRegistry._fuzzyScore("visual studio code", "vsc", "Visual Studio Code");
        record("ADV.ACR.03", "'vsc' on 'Visual Studio Code' scores 3.5 as acronym",
               sc_vsc && sc_vsc.score === 3.5 && sc_vsc.isAcronym === true,
               "score=" + (sc_vsc ? sc_vsc.score : "null"));

        // 1.4 "gimp" -> "GNU Image Manipulation Program": 4-word acronym match at score 3.5
        const sc_gimp = ActionRegistry._fuzzyScore("gnu image manipulation program", "gimp", "GNU Image Manipulation Program");
        record("ADV.ACR.04", "'gimp' on 'GNU Image Manipulation Program' scores 3.5",
               sc_gimp && sc_gimp.score === 3.5 && sc_gimp.isAcronym === true,
               "score=" + (sc_gimp ? sc_gimp.score : "null"));

        // 1.5 Acronym (3.5) vs True Generic Subsequence (4.0-4.9)
        // 'gc' in 'Google Chrome' (acronym, 3.5) vs 'gc' in 'glockenspiel' (subsequence, 4.x)
        const sc_glocken = ActionRegistry._fuzzyScore("glockenspiel", "gc", "glockenspiel");
        record("ADV.ACR.05", "Acronym 'Google Chrome' (3.5) beats true subsequence 'glockenspiel' (4.x)",
               sc_gc && sc_glocken && sc_gc.score < sc_glocken.score && sc_glocken.score >= 4.0,
               "gc=" + (sc_gc ? sc_gc.score : "null") + " vs glockenspiel=" + (sc_glocken ? sc_glocken.score : "null"));

        // 1.6 Contiguous Substring (3.0) vs Acronym (3.5)
        // 'ff' in 'Power Off' (contiguous 'ff', 3.0) vs 'ff' in 'Firefox' (acronym, 3.5)
        const sc_po_ff = ActionRegistry._fuzzyScore("power off", "ff", "Power Off");
        record("ADV.ACR.06", "Contiguous substring in 'Power Off' (3.0) beats acronym 'Firefox' (3.5)",
               sc_po_ff && sc_ff && sc_po_ff.score === 3.0 && sc_po_ff.score < sc_ff.score,
               "poweroff=" + (sc_po_ff ? sc_po_ff.score : "null") + " vs firefox=" + (sc_ff ? sc_ff.score : "null"));

        // 1.7 Contiguous substring 'gc' in 'Logcat' gets score 3.0 (Tier 3)
        const sc_logcat = ActionRegistry._fuzzyScore("logcat", "gc", "Logcat");
        record("ADV.ACR.07", "Contiguous substring 'gc' in 'Logcat' correctly scores 3.0",
               sc_logcat && sc_logcat.score === 3.0,
               "score=" + (sc_logcat ? sc_logcat.score : "null"));

        // 1.8 Compound word roots: 'tb' in 'thunderbird', 'ws' in 'wireshark'
        const sc_tb = ActionRegistry._fuzzyScore("thunderbird", "tb", "Thunderbird");
        record("ADV.ACR.08", "'tb' in 'Thunderbird' matches as acronym score 3.5",
               sc_tb && sc_tb.score === 3.5,
               "score=" + (sc_tb ? sc_tb.score : "null"));

        const sc_ws = ActionRegistry._fuzzyScore("wireshark", "ws", "WireShark");
        record("ADV.ACR.09", "'ws' in 'WireShark' matches as acronym score 3.5",
               sc_ws && sc_ws.score === 3.5,
               "score=" + (sc_ws ? sc_ws.score : "null"));

        // =============================================================
        // GROUP 2: Repetitive Characters & Boundary Stress
        // =============================================================
        // 2.1 "aaa" in "banana": Subsequence matching across repetitive characters
        const sc_banana = ActionRegistry._fuzzyScore("banana", "aaa", "banana");
        record("ADV.REP.01", "'aaa' in 'banana' matches as fuzzy subsequence (Tier 4)",
               sc_banana && sc_banana.score >= 4.0 && sc_banana.score <= 4.9,
               "score=" + (sc_banana ? sc_banana.score : "null"));

        // 2.2 "aaaa" in "banana": Only 3 'a's exist, must return null
        const sc_banana_fail = ActionRegistry._fuzzyScore("banana", "aaaa", "banana");
        record("ADV.REP.02", "'aaaa' in 'banana' returns null (excess character rejection)",
               sc_banana_fail === null,
               "result=" + sc_banana_fail);

        // 2.3 "fff" in "firefox": Only 2 'f's exist, must return null
        const sc_fff = ActionRegistry._fuzzyScore("firefox", "fff", "Firefox");
        record("ADV.REP.03", "'fff' in 'firefox' returns null",
               sc_fff === null,
               "result=" + sc_fff);

        // 2.4 "ffff" in "Fast File Finder": 3 'f's exist, 4 requested -> null
        const sc_ffff = ActionRegistry._fuzzyScore("fast file finder", "ffff", "Fast File Finder");
        record("ADV.REP.04", "'ffff' in 'Fast File Finder' returns null",
               sc_ffff === null,
               "result=" + sc_ffff);

        // 2.5 "ooo" in "Google Chrome": 2 'o's in Google + 1 'o' in Chrome = 3 'o's
        const sc_ooo = ActionRegistry._fuzzyScore("google chrome", "ooo", "Google Chrome");
        record("ADV.REP.05", "'ooo' in 'Google Chrome' matches subsequence across words",
               sc_ooo && sc_ooo.score >= 4.0 && sc_ooo.score <= 4.9,
               "score=" + (sc_ooo ? sc_ooo.score : "null"));

        // 2.6 "oooo" in "Google Chrome": Only 3 'o's exist -> must return null
        const sc_oooo = ActionRegistry._fuzzyScore("google chrome", "oooo", "Google Chrome");
        record("ADV.REP.06", "'oooo' in 'Google Chrome' returns null",
               sc_oooo === null,
               "result=" + sc_oooo);

        // 2.7 Repetitive prefix "aaaa" in "aaaaa" -> prefix match Tier 1
        const sc_rep_pfx = ActionRegistry._fuzzyScore("aaaaa", "aaaa", "aaaaa");
        record("ADV.REP.07", "'aaaa' in 'aaaaa' yields prefix score 1",
               sc_rep_pfx && sc_rep_pfx.score === 1,
               "score=" + (sc_rep_pfx ? sc_rep_pfx.score : "null"));

        // 2.8 Identical repetitive string exact match -> score 0
        const sc_rep_exact = ActionRegistry._fuzzyScore("bbbb", "bbbb", "bbbb");
        record("ADV.REP.08", "'bbbb' in 'bbbb' yields exact score 0",
               sc_rep_exact && sc_rep_exact.score === 0,
               "score=" + (sc_rep_exact ? sc_rep_exact.score : "null"));

        // =============================================================
        // GROUP 3: Unicode, Diacritics, CJK, Cyrillic, Emoji
        // =============================================================
        // 3.1 German Umlauts exact match
        const sc_umlaut_exact = ActionRegistry._fuzzyScore("überzug", "überzug", "Überzug");
        record("ADV.UNI.01", "Umlaut exact match 'überzug' yields score 0",
               sc_umlaut_exact && sc_umlaut_exact.score === 0);

        // 3.2 German Umlauts prefix match
        const sc_umlaut_pfx = ActionRegistry._fuzzyScore("überzug", "über", "Überzug");
        record("ADV.UNI.02", "Umlaut prefix match 'über' yields score 1",
               sc_umlaut_pfx && sc_umlaut_pfx.score === 1);

        // 3.3 French Accents exact match
        const sc_accent = ActionRegistry._fuzzyScore("café", "café", "Café");
        record("ADV.UNI.03", "Accented 'café' exact match yields score 0",
               sc_accent && sc_accent.score === 0);

        // 3.4 Cyrillic prefix match
        const sc_cyrillic = ActionRegistry._fuzzyScore("терминал", "терм", "Терминал");
        record("ADV.UNI.04", "Cyrillic prefix match 'терм' in 'терминал' yields score 1",
               sc_cyrillic && sc_cyrillic.score === 1);

        // 3.5 CJK prefix match
        const sc_cjk = ActionRegistry._fuzzyScore("日本語入力", "日本", "日本語入力");
        record("ADV.UNI.05", "CJK prefix match '日本' in '日本語入力' yields score 1",
               sc_cjk && sc_cjk.score === 1);

        // 3.6 Emoji substring match
        const sc_emoji = ActionRegistry._fuzzyScore("terminal 🚀 tool", "🚀", "Terminal 🚀 Tool");
        record("ADV.UNI.06", "Emoji substring '🚀' yields score 2 or 3",
               sc_emoji && (sc_emoji.score === 2 || sc_emoji.score === 3),
               "score=" + (sc_emoji ? sc_emoji.score : "null"));

        // =============================================================
        // GROUP 4: Symbols, Punctuation, Regex Injection Resistance
        // =============================================================
        // 4.1 C++ literal plus symbols
        const sc_cplus = ActionRegistry._fuzzyScore("c++ compiler", "c++", "C++ Compiler");
        record("ADV.SYM.01", "Query 'c++' matches without RegExp quantifier crash",
               sc_cplus && sc_cplus.score === 1);

        // 4.2 C# literal hash symbol
        const sc_csharp = ActionRegistry._fuzzyScore("c# ide", "c#", "C# IDE");
        record("ADV.SYM.02", "Query 'c#' matches without regex crash",
               sc_csharp && sc_csharp.score === 1);

        // 4.3 Regex metacharacters in query: brackets, parens, braces, pipe, star
        const dangerousQueries = [
            ".*", "[a-z]+", "\\d+", "(a|b)", "(?=.*)", "^$", "\\", "[[[", "+++", "{1,3}", "foo|bar", "?!"
        ];
        let allRegexHandledSafely = true;
        for (let i = 0; i < dangerousQueries.length; ++i) {
            try {
                const dq = dangerousQueries[i];
                ActionRegistry._fuzzyScore("regex tester (pro) [v2.0] {core} +extra *all*", dq, "Regex Tester (Pro) [v2.0] {core} +extra *all*");
            } catch (e) {
                allRegexHandledSafely = false;
                console.error("Regex crash on query: " + dangerousQueries[i] + " -> " + e);
            }
        }
        record("ADV.SYM.03", "Dangerous regex strings execute safely with zero exceptions",
               allRegexHandledSafely);

        // 4.4 Hyphenated and dotted identifiers
        const sc_hyphen = ActionRegistry._fuzzyScore("nix-shell-runner", "shell", "nix-shell-runner");
        record("ADV.SYM.04", "Word boundary on hyphenated token 'shell' yields score 2",
               sc_hyphen && sc_hyphen.score === 2);

        const sc_dot = ActionRegistry._fuzzyScore("node.js runtime", "js", "node.js runtime");
        record("ADV.SYM.05", "Word boundary on dot delimiter 'js' yields score 2",
               sc_dot && sc_dot.score === 2);

        // 4.5 Slash and colon boundaries
        const sc_slash = ActionRegistry._fuzzyScore("usr/bin/python", "python", "usr/bin/python");
        record("ADV.SYM.06", "Word boundary on slash delimiter yields score 2",
               sc_slash && sc_slash.score === 2);

        // =============================================================
        // GROUP 5: Whitespace and Case Normalization
        // =============================================================
        // 5.1 Mixed case exact matching
        const sc_case1 = ActionRegistry._fuzzyScore("firefox", "FIREFOX", "Firefox");
        const sc_case2 = ActionRegistry._fuzzyScore("firefox", "fIrEfOx", "Firefox");
        record("ADV.CASE.01", "Case-insensitive exact matching yields score 0 across casings",
               sc_case1 && sc_case1.score === 0 && sc_case2 && sc_case2.score === 0);

        // 5.2 Leading and trailing spaces in query
        const sc_spaces_trim = ActionRegistry._fuzzyScore("firefox", "   ff   ", "Firefox");
        record("ADV.SPACE.01", "Leading/trailing whitespace in query is trimmed gracefully",
               sc_spaces_trim && sc_spaces_trim.score === 3.5);

        // 5.3 Whitespace-only query
        const sc_ws_only = ActionRegistry._fuzzyScore("firefox", "     ", "Firefox");
        record("ADV.SPACE.02", "Whitespace-only query returns null",
               sc_ws_only === null);

        // 5.4 Internal space matching in subsequence
        const sc_internal_sp = ActionRegistry._fuzzyScore("google chrome", "g c", "Google Chrome");
        record("ADV.SPACE.03", "Internal space in 'g c' matches 'google chrome'",
               sc_internal_sp && sc_internal_sp.score >= 4.0 && sc_internal_sp.score <= 4.9);

        // =============================================================
        // GROUP 6: Adversarial Types & Fuzzing (Crash Resistance)
        // =============================================================
        // 6.1 _fuzzyScore handles all non-string inputs safely without throw
        let fuzzyScoreFuzzErrors = 0;
        const badTypes = [
            null, undefined, 0, 12345, -1, NaN, Infinity, -Infinity,
            true, false, {}, [], [1, 2], { a: 1 }, function() {}, Symbol("test")
        ];

        for (let i = 0; i < badTypes.length; ++i) {
            const bad = badTypes[i];
            try {
                const r1 = ActionRegistry._fuzzyScore(bad, "ff", "Firefox");
                if (r1 !== null) fuzzyScoreFuzzErrors++;

                const r2 = ActionRegistry._fuzzyScore("firefox", bad, "Firefox");
                if (r2 !== null) fuzzyScoreFuzzErrors++;

                const r3 = ActionRegistry._fuzzyScore(bad, bad, bad);
                if (r3 !== null) fuzzyScoreFuzzErrors++;
            } catch (e) {
                console.error("Crash in _fuzzyScore with type " + String(bad) + ": " + e);
                fuzzyScoreFuzzErrors++;
            }
        }
        record("ADV.FUZZ.01", "_fuzzyScore safely rejects non-string inputs (null, undef, number, bool, obj)",
               fuzzyScoreFuzzErrors === 0, "errors=" + fuzzyScoreFuzzErrors);

        // 6.2 search() handles null, undefined, empty, and numeric string queries
        const searchSafeQueries = ["", "   ", "123", "0", "true", "null", "undefined"];
        let searchSafeOk = true;
        for (let i = 0; i < searchSafeQueries.length; ++i) {
            try {
                const res = ActionRegistry.search(searchSafeQueries[i]);
                if (!Array.isArray(res)) searchSafeOk = false;
            } catch (e) {
                console.error("Crash in search('" + searchSafeQueries[i] + "'): " + e);
                searchSafeOk = false;
            }
        }
        record("ADV.FUZZ.02", "search() safely handles empty, whitespace, and literal string queries",
               searchSafeOk);

        // 6.3 _isWordBoundary boundary indices test
        let boundaryIndexSafe = true;
        try {
            ActionRegistry._isWordBoundary("test", "Test", -10);
            ActionRegistry._isWordBoundary("test", "Test", 0);
            ActionRegistry._isWordBoundary("test", "Test", 4);
            ActionRegistry._isWordBoundary("test", "Test", 100);
            ActionRegistry._isWordBoundary("", "", 0);
            ActionRegistry._isWordBoundary(null, null, 0);
        } catch (e) {
            boundaryIndexSafe = false;
        }
        record("ADV.FUZZ.03", "_isWordBoundary safely handles out-of-bounds indices and empty strings",
               boundaryIndexSafe);

        // =============================================================
        // GROUP 7: Worst-case String Lengths & DoS / Timing Stress
        // =============================================================
        const longTarget = "a".repeat(5000) + "firefox" + "b".repeat(5000);
        const longQuery = "a".repeat(100) + "ff";

        const startTime = Date.now();
        const sc_perf = ActionRegistry._fuzzyScore(longTarget, longQuery, longTarget);
        const elapsed = Date.now() - startTime;

        record("ADV.PERF.01", "10,000-char target evaluated in < 150ms (linear time guarantee)",
               elapsed < 150 && sc_perf !== null,
               "elapsed=" + elapsed + "ms, score=" + (sc_perf ? sc_perf.score : "null"));

        // Query longer than target rejected immediately
        const startQgtT = Date.now();
        const sc_q_gt_t = ActionRegistry._fuzzyScore("short", "very long query that exceeds target length", "short");
        const elapsedQgtT = Date.now() - startQgtT;
        record("ADV.PERF.02", "Query longer than target returns null in < 5ms",
               elapsedQgtT < 5 && sc_q_gt_t === null,
               "elapsed=" + elapsedQgtT + "ms");

        // Worst-case repetitive mismatch: 2000 'a's vs 1000 'a's + 'z'
        const mismatchTarget = "a".repeat(2000);
        const mismatchQuery = "a".repeat(1000) + "z";
        const startMismatch = Date.now();
        const sc_mismatch = ActionRegistry._fuzzyScore(mismatchTarget, mismatchQuery, mismatchTarget);
        const elapsedMismatch = Date.now() - startMismatch;
        record("ADV.PERF.03", "Repetitive mismatch returns null without catastrophic backtracking in < 50ms",
               elapsedMismatch < 50 && sc_mismatch === null,
               "elapsed=" + elapsedMismatch + "ms");

        // =============================================================
        // GROUP 8: Search() Integration, Contract & Sorting Invariants
        // =============================================================
        // 8.1 search(null) and search(undefined) return full list
        const s_null = ActionRegistry.search(null);
        const s_undef = ActionRegistry.search(undefined);
        record("ADV.SEARCH.01", "search(null) and search(undefined) safely return results array",
               Array.isArray(s_null) && s_null.length > 0 && Array.isArray(s_undef) && s_undef.length > 0);

        // 8.2 Monotonic score ordering across mixed results
        const s_mixed = ActionRegistry.search("t");
        let mixedMonotonic = true;
        let lastAppScore = -1;
        let inActions = false;
        let lastActScore = -1;
        for (let i = 0; i < s_mixed.length; ++i) {
            const item = s_mixed[i];
            if (item.category === "Applications") {
                if (inActions) {
                    // Applications must come BEFORE Actions
                    mixedMonotonic = false;
                    break;
                }
                if (item.score < lastAppScore) {
                    mixedMonotonic = false;
                    break;
                }
                lastAppScore = item.score;
            } else if (item.category === "Actions") {
                inActions = true;
                if (item.score < lastActScore) {
                    mixedMonotonic = false;
                    break;
                }
                lastActScore = item.score;
            }
        }
        record("ADV.SEARCH.02", "search('t') returns Apps sorted by score, then Actions sorted by score",
               mixedMonotonic);

        // 8.3 Alphabetical tie-breaking when scores are equal
        let tieBreakOk = true;
        for (let i = 0; i < s_mixed.length - 1; ++i) {
            const a = s_mixed[i];
            const b = s_mixed[i + 1];
            if (a.category === b.category && a.score === b.score) {
                if (a.name.localeCompare(b.name) > 0) {
                    tieBreakOk = false;
                    break;
                }
            }
        }
        record("ADV.SEARCH.03", "Identical scores tie-break alphabetically by name",
               tieBreakOk);

        // 8.4 Interface contract check: all items have required properties
        // name, icon, category, score, execute
        let contractSatisfied = true;
        for (let i = 0; i < s_mixed.length; ++i) {
            const it = s_mixed[i];
            if (!it.name || typeof it.name !== "string" ||
                !it.category || typeof it.category !== "string" ||
                typeof it.score !== "number" || it.score < 0 ||
                typeof it.execute !== "function") {
                contractSatisfied = false;
                console.error("Contract violation on item: " + JSON.stringify(it.name));
                break;
            }
        }
        record("ADV.SEARCH.04", "Returned items satisfy interface contract (name, category, score, execute)",
               contractSatisfied);

        // 8.5 Verify callback() availability: Applications provide callback(), Actions provide execute()
        let appsHaveCallback = true;
        for (let i = 0; i < s_mixed.length; ++i) {
            const it = s_mixed[i];
            if (it.category === "Applications" && typeof it.callback !== "function") {
                appsHaveCallback = false;
                break;
            }
        }
        record("ADV.SEARCH.05", "Application items strictly define callback() alias",
               appsHaveCallback);

        // =============================================================
        // SUMMARY
        // =============================================================
        console.log("================================================================");
        console.log("CHALLENGER STRESS RESULTS: Passed=" + passCount + ", Failed=" + failCount);
        console.log("================================================================");

        if (failCount === 0) {
            console.log("=== PASS: ALL EMPIRICAL CHALLENGE TESTS SUCCEEDED ===");
            if (typeof Quickshell !== "undefined" && typeof Quickshell.exit === "function") {
                Quickshell.exit(0);
            } else {
                Qt.quit();
            }
        } else {
            console.error("=== FAIL: EMPIRICAL CHALLENGE DETECTED FAILURES ===");
            if (typeof Quickshell !== "undefined" && typeof Quickshell.exit === "function") {
                Quickshell.exit(1);
            } else {
                Qt.quit();
            }
        }
    }

    Timer {
        id: triggerTimer
        interval: 250
        running: true
        repeat: true
        property int ticks: 0

        onTriggered: {
            ticks++;
            const appCount = (ActionRegistry && ActionRegistry.applications) ? ActionRegistry.applications.length : 0;
            if (appCount > 0 || ticks >= 4) {
                triggerTimer.running = false;
                root.runAllAdversarialTests();
            }
        }
    }
}
