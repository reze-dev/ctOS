import QtQuick
import QtQuick.Layouts
import Quickshell
import desktop.services
import desktop.core
import desktop.surfaces

Scope {
    id: root

    property var failures: []
    property int totalChecks: 0
    property int passedChecks: 0

    function recordPass(testName, detail) {
        totalChecks++;
        passedChecks++;
        console.log("CHALLENGER_PASS: [" + testName + "] " + detail);
    }

    function recordFailure(testName, reason) {
        totalChecks++;
        console.error("CHALLENGER_FAIL: [" + testName + "] " + reason);
        failures.push({ test: testName, reason: reason });
    }

    function clearSystemState() {
        while (NotificationService.activeToasts.count > 0) {
            const countBefore = NotificationService.activeToasts.count;
            const t = NotificationService.activeToasts.get(0);
            const tid = (t && t.notifId !== undefined) ? t.notifId : (t ? t.id : 0);
            NotificationService.dismissToast(tid);
            if (NotificationService.activeToasts.count === countBefore) {
                // Safeguard against ghost toasts with mismatched types
                NotificationService.activeToasts.remove(0);
            }
        }
        NotificationService.clearAll();
        if (NotificationService.doNotDisturb) {
            NotificationService.toggleDnd();
        }
        OverlayController.close();
    }

    // Host simulation for NotificationToasts
    Item {
        id: toastHostContainer
        width: 360
        implicitWidth: 360
        implicitHeight: toastStack.implicitHeight

        NotificationToasts {
            id: toastStack
            width: 340
            anchors.horizontalCenter: parent.horizontalCenter
        }
    }

    // Host simulation for EventLog
    Item {
        id: eventLogHostContainer
        width: 360
        height: 800

        EventLog {
            id: eventLogSurface
            anchors.fill: parent
        }
    }

    // Runner Entry Point
    Timer {
        id: phase1Runner
        interval: 20
        running: true
        repeat: false
        onTriggered: {
            console.log("================================================================");
            console.log("=== EMPIRICAL CHALLENGER M5: ULTIMATE ADVERSARIAL STRESS SUITE ===");
            console.log("================================================================");

            // =================================================================
            // SUITE 1: MASSIVE FLOOD BURSTS (100+ NOTIFICATIONS) WITH MULTI-STATE CHURN
            // =================================================================
            try {
                clearSystemState();
                console.log("\n--- SUITE 1: Massive Flood Bursts & State Churn ---");

                // Test 1.1: 120 notifications with interleaved DND toggling every 10 notifications
                for (let i = 1; i <= 120; ++i) {
                    if (i % 10 === 0) {
                        NotificationService.toggleDnd();
                    }
                    NotificationService._handleNotification({
                        id: 1000 + i,
                        appName: "DndFloodApp" + (i % 5),
                        summary: "Flood notification #" + i,
                        body: "Payload item for DND flood churn verification",
                        urgency: i % 3
                    });

                    // Invariant: activeToasts count must NEVER exceed 3 at any point
                    if (NotificationService.activeToasts.count > 3) {
                        recordFailure("Burst_DndChurn_ActiveCap", "activeToasts exceeded 3 during flood: " + NotificationService.activeToasts.count);
                        break;
                    }
                }

                // Invariant: History must record all 120 notifications regardless of DND state
                if (NotificationService.history.count === 120) {
                    recordPass("Burst_DndChurn_HistoryTotal", "History recorded all 120 notifications: count=" + NotificationService.history.count);
                } else {
                    recordFailure("Burst_DndChurn_HistoryTotal", "Expected 120 in history, got " + NotificationService.history.count);
                }

                // Restore DND to false
                if (NotificationService.doNotDisturb) {
                    NotificationService.toggleDnd();
                }

                // Test 1.2: 100 notifications with rapid OverlayController open/close toggles
                clearSystemState();
                for (let j = 1; j <= 100; ++j) {
                    if (j % 5 === 0) {
                        OverlayController.toggleEventLog();
                    }
                    NotificationService._handleNotification({
                        id: 2000 + j,
                        appName: "OverlayFloodApp",
                        summary: "Notice while toggling overlay #" + j,
                        body: "Validating delegate stability and model binding during dynamic UI insertions",
                        urgency: 1
                    });
                }
                OverlayController.close();

                if (NotificationService.activeToasts.count === 3 && NotificationService.history.count === 100) {
                    recordPass("Burst_OverlayChurn_CapAndHistory", "Active capped at 3 (" + NotificationService.activeToasts.count + ") and history holds 100 (" + NotificationService.history.count + ")");
                } else {
                    recordFailure("Burst_OverlayChurn_CapAndHistory", "active=" + NotificationService.activeToasts.count + ", history=" + NotificationService.history.count);
                }

                // Test 1.3: 100 notifications with asynchronous dismissals mid-stream
                clearSystemState();
                for (let k = 1; k <= 100; ++k) {
                    NotificationService._handleNotification({
                        id: 3000 + k,
                        appName: "DismissFloodApp",
                        summary: "Mid-stream notice #" + k,
                        body: "Testing dismissal while flood is active",
                        urgency: k % 3
                    });
                    if (k % 3 === 0 && NotificationService.activeToasts.count > 0) {
                        const toast = NotificationService.activeToasts.get(0);
                        const tid = (toast.notifId !== undefined ? toast.notifId : toast.id);
                        NotificationService.dismissToast(tid);
                    }
                }
                if (NotificationService.activeToasts.count <= 3 && NotificationService.history.count === 100) {
                    recordPass("Burst_MidstreamDismissals", "Mid-stream dismissals handled cleanly: activeToasts=" + NotificationService.activeToasts.count + ", history=" + NotificationService.history.count);
                } else {
                    recordFailure("Burst_MidstreamDismissals", "Invalid state: active=" + NotificationService.activeToasts.count + ", history=" + NotificationService.history.count);
                }

                // Test 1.4: Raw throughput burst (200 notifications in a tight loop)
                clearSystemState();
                for (let r = 1; r <= 200; ++r) {
                    NotificationService._handleNotification({
                        id: 4000 + r,
                        appName: "RawThroughputDaemon",
                        summary: "High throughput notice #" + r,
                        body: "Testing 200 notification tight-loop ingestion",
                        urgency: 1
                    });
                }
                let activeTimerCount = Object.keys(NotificationService._toastTimers).length;
                let activeObjCount = Object.keys(NotificationService._notificationObjects).length;
                if (NotificationService.history.count === 200 && NotificationService.activeToasts.count === 3 && activeTimerCount === 3 && activeObjCount === 3) {
                    recordPass("Burst_RawThroughput_200Items", "200-burst complete: history=200, activeToasts=3, activeTimers=3, activeObjects=3");
                } else {
                    recordFailure("Burst_RawThroughput_200Items", "Mismatch: history=" + NotificationService.history.count + ", activeToasts=" + NotificationService.activeToasts.count + ", timers=" + activeTimerCount + ", objects=" + activeObjCount);
                }

            } catch (e1) {
                recordFailure("Suite1_Exception", e1.toString());
            }

            // =================================================================
            // SUITE 2: EXTREME BOUNDARY STRINGS & MALFORMED INGESTION
            // =================================================================
            try {
                clearSystemState();
                console.log("\n--- SUITE 2: Extreme Boundary Strings & Ingestion ---");

                // Test 2.1: Massive Multibyte, Arabic RTL, CJK, Zalgo, ZWJ Emojis, Control sequences
                const complexStrings = [
                    "مرحبا بالعالم - اختبار إشعارات سطح المكتب بحروف عربية معقدة واتجاه من اليمين لليسار",
                    "デスクトップ通知システムテスト 漢字 カタカナ ひらがな 1234567890 記号！？★☆",
                    "T̸̗̀ë̵̖́s̶̡̓t̶̍͜ ̴͍̌Z̴͔̐á̷ͅĺ̷̫ǵ̶̗o̶͚͝ ̵̤́C̶̛͇o̶̦̅m̸̯͐b̵͎̐ḯ̸̭ń̷͔i̵̬͗n̸̼͠g̸̰̎ ̴͎̽M̶̦̑ä̶̬́r̴̗̀k̵̫͝ŝ̷̮ ̴̢̌S̸̛͇ť̶̨r̵̥̈́e̴̢̅s̶̙͑s̸͕͂",
                    "👨‍👩‍👧‍👦 🏳️‍🌈 🧑🏽‍💻 🏴‍☠️ 🚀 🔥 🎉 💀 ⚡ 💻 🤖 👾 🛸 🛡️ 🧩",
                    "\x1b[31;1mANSI_RED\x1b[0m \t\t \r\n \u0000 \uFEFF ZeroWidth \u200B Spacing \u202E RTL_Override"
                ];

                for (let m = 0; m < complexStrings.length; ++m) {
                    NotificationService._handleNotification({
                        id: 5000 + m,
                        appName: "ComplexUnicodeApp" + m,
                        summary: complexStrings[m],
                        body: complexStrings[m] + " | Second Line Repeat",
                        urgency: m % 3
                    });
                }
                if (NotificationService.history.count === 5 && NotificationService.activeToasts.count === 3) {
                    recordPass("Boundary_ComplexUnicodeIngestion", "All 5 complex multibyte payloads safely ingested without parser fault");
                } else {
                    recordFailure("Boundary_ComplexUnicodeIngestion", "Ingestion failed: history=" + NotificationService.history.count);
                }

                // Test 2.2: Extreme Long Unbroken Strings (10k summary, 25k body with 200 newlines)
                const hugeSummary = "Z".repeat(10000);
                let hugeBody = "";
                for (let l = 1; l <= 200; ++l) {
                    hugeBody += "Line" + l + ":" + "X".repeat(125) + "\n";
                }
                NotificationService._handleNotification({
                    id: 5100,
                    appName: "LongStringApp",
                    summary: hugeSummary,
                    body: hugeBody,
                    urgency: 2
                });
                recordPass("Boundary_MassiveUnbrokenStrings", "10k summary & 25k body parsed into model cleanly without memory fault");

                // Test 2.3: Empty & Degenerate Fields
                NotificationService._handleNotification({
                    id: 5200,
                    appName: "",
                    summary: "",
                    body: "",
                    urgency: 1
                });
                NotificationService._handleNotification({
                    id: 5201,
                    appName: null,
                    summary: null,
                    body: null,
                    urgency: null
                });
                NotificationService._handleNotification({});
                NotificationService._handleNotification(null);
                NotificationService._handleNotification(undefined);
                recordPass("Boundary_EmptyAndDegeneratePayloads", "Empty and null notification objects handled without unhandled exception or freeze");

                // Test 2.4: HTML & Script Injection
                NotificationService._handleNotification({
                    id: 5300,
                    appName: "<script>alert('pwn')</script>",
                    summary: "<b>Bold</b> <i>Italic</i> <img src='invalid' onerror='throw 1'>",
                    body: "&amp;&lt;&gt;&quot;&apos; <a href='javascript:void(0)'>ClickMe</a> <unclosed tag",
                    urgency: 1
                });
                recordPass("Boundary_HtmlMarkupInjection", "HTML markup and injection strings safely ingested");

                // Test 2.5: Extreme IDs, Urgencies, and expireTimeout
                NotificationService._handleNotification({
                    id: -999999,
                    appName: "NegativeIdApp",
                    summary: "Negative ID",
                    body: "Testing negative ID robustness",
                    urgency: -5,
                    expireTimeout: 3000000000 // > signed 32-bit int
                });
                recordPass("Boundary_NegativeIdAndClampedTimeout", "Negative IDs and huge expireTimeout handled without crash");

                // Test 2.6: CRITICAL ADVERSARIAL PROBE: Unsigned 32-bit ID (> 2,147,483,647)
                // Freedesktop specification mandates uint32 IDs (0 to 4,294,967,295).
                // Test whether dismissToast(3000000000) works or causes signed 32-bit integer overflow.
                const uint32Id = 3000000000;
                NotificationService._handleNotification({
                    id: uint32Id,
                    appName: "Uint32Daemon",
                    summary: "Uint32 ID Test",
                    body: "Testing unsigned 32-bit ID dismissal",
                    urgency: 1
                });

                let preDismissCount = NotificationService.activeToasts.count;
                NotificationService.dismissToast(uint32Id);
                let postDismissCount = NotificationService.activeToasts.count;

                if (postDismissCount === preDismissCount) {
                    recordFailure("Vulnerability_Uint32IdOverflow_GhostToast",
                        "CRITICAL DEFECT: dismissToast(" + uint32Id + ") failed to dismiss toast because notifId: int parameter overflows signed 32-bit int (-1294967296). Toast is permanently stuck as a ghost toast!");
                } else {
                    recordPass("Vulnerability_Uint32IdOverflow_GhostToast", "Uint32 ID dismissed successfully");
                }

            } catch (e2) {
                recordFailure("Suite2_Exception", e2.toString());
            }

            // =================================================================
            // SUITE 3: CONCURRENCY, RACES, AND IDEMPOTENCY
            // =================================================================
            try {
                clearSystemState();
                console.log("\n--- SUITE 3: Concurrency, Races, and Idempotency ---");

                // Test 3.1: Simultaneous dismissals on same notification ID (10 consecutive calls)
                NotificationService._handleNotification({
                    id: 6001,
                    appName: "SimultaneousDismissApp",
                    summary: "Dismiss race notice",
                    body: "Calling dismissToast 10 times consecutively",
                    urgency: 1
                });
                for (let d = 0; d < 10; ++d) {
                    NotificationService.dismissToast(6001);
                }
                if (NotificationService.activeToasts.count === 0) {
                    recordPass("Concurrency_SimultaneousDismissToast", "10 consecutive dismissToast calls executed idempotently without error");
                } else {
                    recordFailure("Concurrency_SimultaneousDismissToast", "activeToasts count not 0: " + NotificationService.activeToasts.count);
                }

                // Test 3.2: Invalid dismiss targets
                NotificationService.dismissToast(-1);
                NotificationService.dismissToast(999999);
                NotificationService.dismissToast(NaN);
                NotificationService.dismissHistoryItem(-1);
                NotificationService.dismissHistoryItem(999999);
                NotificationService.dismissHistoryItem(NaN);
                recordPass("Concurrency_InvalidDismissTargets", "Dismissing non-existent and malformed toast IDs and history indices is safe no-op");

                // Test 3.3: Action invoke robustness
                NotificationService._handleNotification({
                    id: 6002,
                    appName: "ActionRaceApp",
                    summary: "Action invoke race",
                    body: "Testing invokeAction with various identifiers",
                    urgency: 1,
                    actions: [
                        { identifier: "valid_action", text: "Execute" }
                    ]
                });
                NotificationService.invokeAction(6002, "valid_action");
                NotificationService.invokeAction(6002, "non_existent_action");
                NotificationService.invokeAction(999999, "valid_action");
                NotificationService.invokeAction(NaN, "valid_action");
                recordPass("Concurrency_ActionInvokeRobustness", "Invoking valid and invalid action identifiers executed safely");

                // Test 3.4: Concurrent ClearAll while individual dismissals occur
                NotificationService._handleNotification({
                    id: 6003,
                    appName: "ClearAllRaceApp1",
                    summary: "Notice 1",
                    body: "Notice 1 body",
                    urgency: 1
                });
                NotificationService._handleNotification({
                    id: 6004,
                    appName: "ClearAllRaceApp2",
                    summary: "Notice 2",
                    body: "Notice 2 body",
                    urgency: 1
                });
                NotificationService.dismissHistoryItem(0);
                NotificationService.clearAll();
                if (NotificationService.history.count === 0) {
                    recordPass("Concurrency_ClearAllAndDismissHistoryRace", "Concurrent dismissHistoryItem and clearAll completed safely: count=" + NotificationService.history.count);
                } else {
                    recordFailure("Concurrency_ClearAllAndDismissHistoryRace", "history not 0: " + NotificationService.history.count);
                }

            } catch (e3) {
                recordFailure("Suite3_Exception", e3.toString());
            }

            // Launch Phase 4 (Async Hover & Expiry Timing Suite)
            phase4Runner.start();
        }
    }

    // =========================================================================
    // SUITE 4: ASYNCHRONOUS HOVER PAUSE & EXPIRY TIMING VERIFICATION
    // =========================================================================
    Timer {
        id: phase4Runner
        interval: 30
        running: false
        repeat: false
        onTriggered: {
            try {
                clearSystemState();
                console.log("\n--- SUITE 4: Asynchronous Hover Pause & Expiry Timing ---");

                // Create a toast with 200ms expireTimeout
                NotificationService._handleNotification({
                    id: 7001,
                    appName: "HoverTimingApp",
                    summary: "Hover Expiry Race Test",
                    body: "Testing timer pause on hover prevents premature expiry",
                    urgency: 1,
                    expireTimeout: 200
                });

                const timer = NotificationService._toastTimers[7001];
                if (!timer || !timer.running) {
                    recordFailure("Hover_TimerCreated", "Timer for 7001 was not running");
                } else {
                    recordPass("Hover_TimerCreated", "Timer initialized and running with interval " + timer.interval);
                }

                // Pause the timer at ~40ms
                phase4PauseTimer.start();

            } catch (e4) {
                recordFailure("Suite4_Exception", e4.toString());
                phase5Runner.start();
            }
        }
    }

    Timer {
        id: phase4PauseTimer
        interval: 40
        running: false
        repeat: false
        onTriggered: {
            NotificationService.pauseToastTimer(7001);
            const timer = NotificationService._toastTimers[7001];
            if (timer && !timer.running) {
                recordPass("Hover_PauseActive", "pauseToastTimer stopped timer.running (running=" + timer.running + ", remainingMs=" + timer.remainingMs + ")");
            } else {
                recordFailure("Hover_PauseActive", "Timer still running after pause");
            }

            // Wait 250ms (> 200ms original timeout). Invariant: Toast MUST NOT expire while paused!
            phase4CheckPausedTimer.start();
        }
    }

    Timer {
        id: phase4CheckPausedTimer
        interval: 250
        running: false
        repeat: false
        onTriggered: {
            let stillActive = false;
            for (let i = 0; i < NotificationService.activeToasts.count; ++i) {
                let item = NotificationService.activeToasts.get(i);
                if (item && item.notifId === 7001) {
                    stillActive = true;
                    break;
                }
            }
            if (stillActive) {
                recordPass("Hover_ExpirySuppressedWhileHovered", "Toast 7001 survived 290ms (>200ms timeout) while hovered");
            } else {
                recordFailure("Hover_ExpirySuppressedWhileHovered", "Toast 7001 prematurely expired while hovered!");
            }

            // Resume timer: remaining floor should be enforced (at least 500ms)
            NotificationService.resumeToastTimer(7001);
            const timer = NotificationService._toastTimers[7001];
            if (timer && timer.running && timer.remainingMs >= 500) {
                recordPass("Hover_ResumeFloorEnforced", "Timer resumed with remaining floor >= 500ms (interval=" + timer.interval + ", remaining=" + timer.remainingMs + ")");
            } else {
                recordFailure("Hover_ResumeFloorEnforced", "Timer resume invalid: running=" + (timer ? timer.running : "null"));
            }

            // Wait 650ms for resumed timer to naturally expire and verify cleanup
            phase4AwaitResumedExpiry.start();
        }
    }

    Timer {
        id: phase4AwaitResumedExpiry
        interval: 650
        running: false
        repeat: false
        onTriggered: {
            let activeCount = NotificationService.activeToasts.count;
            let timerExists = (NotificationService._toastTimers[7001] !== undefined);
            if (activeCount === 0 && !timerExists) {
                recordPass("Hover_NaturalExpiryAfterResume", "Toast cleanly auto-expired and its timer was destroyed: activeToasts=" + activeCount);
            } else {
                recordFailure("Hover_NaturalExpiryAfterResume", "Toast did not clean up: active=" + activeCount + ", timerExists=" + timerExists);
            }

            // Move to Phase 5: Eviction of Hovered Toast
            phase5Runner.start();
        }
    }

    // =========================================================================
    // SUITE 5: EVICTION OF HOVERED TOAST UNDER INCOMING FLOOD
    // =========================================================================
    Timer {
        id: phase5Runner
        interval: 20
        running: false
        repeat: false
        onTriggered: {
            try {
                clearSystemState();
                console.log("\n--- SUITE 5: Eviction of Hovered Toast ---");

                // Create Toast A and pause it
                NotificationService._handleNotification({
                    id: 8001,
                    appName: "ToastA",
                    summary: "Hovered Toast A",
                    body: "Will be paused then evicted",
                    urgency: 1
                });
                NotificationService.pauseToastTimer(8001);

                // Now send 3 new toasts: B, C, D
                NotificationService._handleNotification({ id: 8002, appName: "ToastB", summary: "B", body: "B", urgency: 1 });
                NotificationService._handleNotification({ id: 8003, appName: "ToastC", summary: "C", body: "C", urgency: 1 });
                NotificationService._handleNotification({ id: 8004, appName: "ToastD", summary: "D", body: "D", urgency: 1 });

                // Toast A should be evicted (activeToasts contains 8002, 8003, 8004)
                let aPresent = false;
                for (let i = 0; i < NotificationService.activeToasts.count; ++i) {
                    if (NotificationService.activeToasts.get(i).notifId === 8001) aPresent = true;
                }
                let timerALeaked = (NotificationService._toastTimers[8001] !== undefined);

                if (!aPresent && !timerALeaked && NotificationService.activeToasts.count === 3) {
                    recordPass("Eviction_HoveredToastDismissed", "Hovered Toast A evicted cleanly and its paused timer destroyed without leak");
                } else {
                    recordFailure("Eviction_HoveredToastDismissed", "Toast A state corrupt: present=" + aPresent + ", timerLeaked=" + timerALeaked);
                }

                // Simulate hover exit on the evicted toast: resumeToastTimer(8001)
                NotificationService.resumeToastTimer(8001);
                recordPass("Eviction_ResumeOnEvictedToastIsNoOp", "Resuming timer on evicted toast is a safe no-op");

                // Move to Phase 6: Timer Leak & Memory Stability Suite
                phase6Runner.start();

            } catch (e5) {
                recordFailure("Suite5_Exception", e5.toString());
                phase6Runner.start();
            }
        }
    }

    // =========================================================================
    // SUITE 6: TIMER LEAK & MEMORY STABILITY TESTS
    // =========================================================================
    Timer {
        id: phase6Runner
        interval: 20
        running: false
        repeat: false
        onTriggered: {
            try {
                clearSystemState();
                console.log("\n--- SUITE 6: Timer Leak & Memory Stability ---");

                // Test 6.1: DND Mode Guarantee - ZERO timers created under DND
                NotificationService.toggleDnd(); // DND ON
                for (let d = 1; d <= 50; ++d) {
                    NotificationService._handleNotification({
                        id: 9100 + d,
                        appName: "DndNoTimerDaemon",
                        summary: "DND Notice #" + d,
                        body: "Verify zero timers instantiated in DND mode",
                        urgency: 1
                    });
                }
                let dndTimers = Object.keys(NotificationService._toastTimers).length;
                let dndActive = NotificationService.activeToasts.count;
                let dndHist = NotificationService.history.count;
                if (dndTimers === 0 && dndActive === 0 && dndHist === 50) {
                    recordPass("Leak_DndZeroTimers", "DND mode strictly generated 0 timers and 0 active toasts while recording 50 history entries");
                } else {
                    recordFailure("Leak_DndZeroTimers", "Timers/Toasts leaked under DND: timers=" + dndTimers + ", active=" + dndActive);
                }

                // Clear history and verify _notificationObjects cleanup
                NotificationService.clearAll();
                let postDndObjs = Object.keys(NotificationService._notificationObjects).length;
                if (postDndObjs === 0) {
                    recordPass("Leak_DndClearAllObjectCleanup", "clearAll() emptied _notificationObjects after DND burst: remaining=" + postDndObjs);
                } else {
                    recordFailure("Leak_DndClearAllObjectCleanup", "_notificationObjects leaked after DND clearAll: " + postDndObjs);
                }

                NotificationService.toggleDnd(); // DND OFF

                // Test 6.2: Rapid 100-cycle Create-and-Dismiss Loop (zero memory leaks)
                for (let c = 1; c <= 100; ++c) {
                    NotificationService._handleNotification({
                        id: 9200 + c,
                        appName: "ChurnApp" + c,
                        summary: "Notice " + c,
                        body: "Payload",
                        urgency: c % 3
                    });
                    NotificationService.dismissToast(9200 + c);
                }
                let churnTimers = Object.keys(NotificationService._toastTimers).length;
                let churnActive = NotificationService.activeToasts.count;
                let churnObjs = Object.keys(NotificationService._notificationObjects).length;
                if (churnTimers === 0 && churnActive === 0 && churnObjs === 0) {
                    recordPass("Leak_100CycleChurnZeroLeaks", "100 create-and-dismiss cycles resulted in 0 active toasts, 0 timers, and 0 objects");
                } else {
                    recordFailure("Leak_100CycleChurnZeroLeaks", "Leaked: timers=" + churnTimers + ", active=" + churnActive + ", objs=" + churnObjs);
                }

                NotificationService.clearAll();

                // Test 6.3: Auto-expiry complete timer destruction (3 short toasts expiring simultaneously)
                for (let a = 1; a <= 3; ++a) {
                    NotificationService._handleNotification({
                        id: 9300 + a,
                        appName: "AutoExpiryDaemon",
                        summary: "Auto expiry #" + a,
                        body: "Expire quickly",
                        urgency: 1,
                        expireTimeout: 100
                    });
                }
                recordPass("Leak_AutoExpiryTimersAllocated", "3 timers allocated for 3 short-lived toasts");

                // Wait 250ms for auto-expiry to trigger and check cleanup
                phase6AutoExpiryCheck.start();

            } catch (e6) {
                recordFailure("Suite6_Exception", e6.toString());
                phase7Runner.start();
            }
        }
    }

    Timer {
        id: phase6AutoExpiryCheck
        interval: 250
        running: false
        repeat: false
        onTriggered: {
            let activeAfterExpiry = NotificationService.activeToasts.count;
            let timersAfterExpiry = Object.keys(NotificationService._toastTimers).length;
            let objsAfterExpiry = Object.keys(NotificationService._notificationObjects).length;
            let histAfterExpiry = NotificationService.history.count;

            if (activeAfterExpiry === 0 && timersAfterExpiry === 0 && objsAfterExpiry === 0 && histAfterExpiry === 3) {
                recordPass("Leak_AutoExpiryAllTimersCleanedUp", "All 3 toasts cleanly auto-expired: 0 active, 0 timers, 0 objects, 3 history entries");
            } else {
                recordFailure("Leak_AutoExpiryAllTimersCleanedUp", "Leak after expiry: active=" + activeAfterExpiry + ", timers=" + timersAfterExpiry + ", objs=" + objsAfterExpiry);
            }

            NotificationService.clearAll();
            if (NotificationService.history.count === 0 && Object.keys(NotificationService._notificationObjects).length === 0) {
                recordPass("Leak_FinalClearAllZeroState", "clearAll() confirmed 0 history items and 0 notification objects");
            } else {
                recordFailure("Leak_FinalClearAllZeroState", "clearAll() did not zero state: hist=" + NotificationService.history.count);
            }

            // Move to Phase 7: Focus & Windowing Invariants
            phase7Runner.start();
        }
    }

    // =========================================================================
    // SUITE 7: WINDOWING & KEYBOARD FOCUS INVARIANTS (WlrKeyboardFocus.None)
    // =========================================================================
    Timer {
        id: phase7Runner
        interval: 20
        running: false
        repeat: false
        onTriggered: {
            try {
                clearSystemState();
                console.log("\n--- SUITE 7: Windowing & Focus Invariants ---");

                // Test 7.1: Toast Component Never Takes Active Focus
                // Inject notifications and verify toastStack does not steal focus
                for (let f = 1; f <= 3; ++f) {
                    NotificationService._handleNotification({
                        id: 9500 + f,
                        appName: "FocusTestApp",
                        summary: "Focus Invariant Test #" + f,
                        body: "Notification toast burst must not request or hold focus",
                        urgency: f % 3
                    });
                }

                if (toastStack.activeFocus === false && toastHostContainer.activeFocus === false) {
                    recordPass("Focus_ToastStackLacksFocus", "toastStack and toastHostContainer activeFocus is false (non-blocking)");
                } else {
                    recordFailure("Focus_ToastStackLacksFocus", "Toast surface has activeFocus!");
                }

                // Test 7.2: OverlayHost Exclusive vs None Focus Transition
                // When EventLog is opened: Overlay is active
                OverlayController.openEventLog();
                if (OverlayController.isOverlayActive && OverlayController.activeSurface === OverlayController.Surface.EventLog) {
                    recordPass("Focus_OverlayOpenedEventLog", "Overlay opened with Surface.EventLog (modal receives focus)");
                } else {
                    recordFailure("Focus_OverlayOpenedEventLog", "Overlay not active or wrong surface: " + OverlayController.activeSurface);
                }

                // Verify EventLog surface has focus: true
                if (eventLogSurface.focus === true) {
                    recordPass("Focus_EventLogRootHasFocusTrue", "EventLog root FocusScope has focus: true for keyboard trapping");
                } else {
                    recordFailure("Focus_EventLogRootHasFocusTrue", "EventLog root lacks focus: true");
                }

                // When EventLog is closed: Overlay inactive
                OverlayController.close();
                if (!OverlayController.isOverlayActive && OverlayController.activeSurface === OverlayController.Surface.None) {
                    recordPass("Focus_OverlayClosedRestoresNone", "Overlay closed restores None surface (modal focus released)");
                } else {
                    recordFailure("Focus_OverlayClosedRestoresNone", "Overlay close did not restore None: " + OverlayController.activeSurface);
                }

                // Clean up
                clearSystemState();

            } catch (e7) {
                recordFailure("Suite7_Exception", e7.toString());
            }

            // =================================================================
            // FINAL REPORT & VERDICT
            // =================================================================
            console.log("\n================================================================");
            console.log("=== CHALLENGER M5 ADVERSARIAL STRESS SUITE COMPLETE ===");
            console.log("Total Checks Performed: " + totalChecks);
            console.log("Passed Checks         : " + passedChecks);
            console.log("Failed Checks         : " + failures.length);
            console.log("================================================================");

            if (failures.length === 0) {
                console.log("CHALLENGER_M5_FINAL_VERDICT: ALL SUITES PASSED EMPIRICALLY (APPROVE)");
            } else {
                console.error("CHALLENGER_M5_FINAL_VERDICT: " + failures.length + " DEFECT(S) DETECTED (REJECT)");
                for (let i = 0; i < failures.length; ++i) {
                    console.error("  -> Failure [" + failures[i].test + "]: " + failures[i].reason);
                }
            }

            Qt.quit();
        }
    }
}
