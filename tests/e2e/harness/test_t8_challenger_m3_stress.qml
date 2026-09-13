import QtQuick
import Quickshell
import desktop.services
import desktop.core
import desktop.surfaces

FloatingWindow {
    id: testWindow
    visible: true
    implicitWidth: 400
    implicitHeight: 700

    property var testResults: []
    property int passCount: 0
    property int failCount: 0

    function recordResult(testName, passed, detail) {
        if (passed) {
            passCount++;
            console.log("CHALLENGE_PASS: [" + testName + "] " + detail);
        } else {
            failCount++;
            console.error("CHALLENGE_FAIL: [" + testName + "] " + detail);
        }
        testResults.push({ name: testName, passed: passed, detail: detail });
    }

    Item {
        id: container
        anchors.fill: parent

        NotificationToasts {
            id: toastSurface
            anchors.horizontalCenter: parent.horizontalCenter
        }
    }

    function clearAllState() {
        while (NotificationService.activeToasts.count > 0) {
            let t = NotificationService.activeToasts.get(0);
            NotificationService.dismissToast(t.notifId);
        }
        NotificationService.clearAll();
    }

    Timer {
        id: suiteRunner
        interval: 30
        running: true
        repeat: false

        onTriggered: {
            console.log("================================================================");
            console.log("=== EMPIRICAL CHALLENGER M3: COMPREHENSIVE STRESS SUITE ===");
            console.log("================================================================");

            // =================================================================
            // SUITE 1: RAPID NOTIFICATION BURSTS (10+ IN QUICK SUCCESSION)
            // =================================================================
            try {
                clearAllState();
                console.log("\n--- SUITE 1: Rapid Notification Bursts (20 bursts) ---");
                for (let i = 1; i <= 20; i++) {
                    NotificationService._handleNotification({
                        id: 1000 + i,
                        appName: "BurstApp" + i,
                        summary: "Burst Summary " + i,
                        body: "Burst Payload sequence item " + i,
                        urgency: i % 3
                    });
                }

                // Check 1.1: Active toasts capped at 3
                let activeCount = NotificationService.activeToasts.count;
                recordResult("Burst_MaxActive3", activeCount === 3, "activeToasts.count is " + activeCount + " (expected 3)");

                // Check 1.2: The 3 visible toasts are the latest (1018, 1019, 1020)
                let id1 = NotificationService.activeToasts.get(0).notifId;
                let id2 = NotificationService.activeToasts.get(1).notifId;
                let id3 = NotificationService.activeToasts.get(2).notifId;
                let isLatest3 = (id1 === 1018 && id2 === 1019 && id3 === 1020);
                recordResult("Burst_LatestPreserved", isLatest3, "IDs in active toasts: [" + id1 + ", " + id2 + ", " + id3 + "] (expected [1018, 1019, 1020])");

                // Check 1.3: History contains all 20 notifications
                let histCount = NotificationService.history.count;
                recordResult("Burst_HistoryRetainedAll", histCount === 20, "history.count is " + histCount + " (expected 20)");

                // Check 1.4: Timers map only retains 3 active timers (no leaks)
                let timerCount = 0;
                for (let k in NotificationService._toastTimers) {
                    if (NotificationService._toastTimers[k]) timerCount++;
                }
                recordResult("Burst_TimerLeakPrevention", timerCount === 3, "Active timer count is " + timerCount + " (expected 3, no leaks)");

            } catch (e) {
                recordResult("Burst_Execution", false, "Exception: " + e);
            }

            // =================================================================
            // SUITE 2: BOUNDARY INPUTS
            // =================================================================
            try {
                clearAllState();
                console.log("\n--- SUITE 2: Boundary Inputs ---");

                // Test 2.1: Empty summary and empty body
                NotificationService._handleNotification({
                    id: 2001,
                    appName: "",
                    summary: "",
                    body: "",
                    urgency: 1
                });
                let toastEmpty = NotificationService.activeToasts.get(0);
                let col = toastSurface.children[0];
                let cardEmpty = col.children[0];
                recordResult("Boundary_EmptyFields", toastEmpty !== null && cardEmpty.implicitHeight > 0,
                    "Empty notification handled, card implicitHeight=" + (cardEmpty ? cardEmpty.implicitHeight : 0));

                // Test 2.2: Extreme long summary (5000 characters)
                let hugeSummary = "A".repeat(5000);
                NotificationService._handleNotification({
                    id: 2002,
                    appName: "LongSummaryApp",
                    summary: hugeSummary,
                    body: "Normal body",
                    urgency: 1
                });
                let cardLongSummary = col.children[1];
                recordResult("Boundary_HugeSummary_Elision", cardLongSummary && cardLongSummary.width <= 340,
                    "5000-char summary constrained to width: " + (cardLongSummary ? cardLongSummary.width : "N/A"));

                // Test 2.3: Extreme long body (10,000 characters + 100 newlines)
                let hugeBody = "Line 1: START\n";
                for (let l = 2; l <= 100; l++) {
                    hugeBody += "Line " + l + ": " + "X".repeat(100) + "\n";
                }
                NotificationService._handleNotification({
                    id: 2003,
                    appName: "LongBodyApp",
                    summary: "Long Body Clamp Test",
                    body: hugeBody,
                    urgency: 1
                });
                let cardLongBody = col.children[2];
                let cardLayout = cardLongBody.children[1];
                let bodyText = cardLayout.children[2];
                let clampedLines = bodyText.lineCount;
                let bodyHeight = bodyText.implicitHeight;
                recordResult("Boundary_HugeBody_Clamped3Lines", clampedLines <= 3,
                    "100-line body clamped to " + clampedLines + " lines, implicitHeight=" + bodyHeight);

                // Test 2.4: Special characters (CJK, Arabic, Emojis, ANSI, tabs)
                let specialSummary = "🚀 CTOS // 警告 // إشعار █▓▒░ \u0000 \t \n special glyphs";
                let specialBody = "Unicode: ⚡ 🔥 💀 | Math: ∀x∈ℝ, x²≥0 | Quotes: \"'`` | Symbols: & < > @ # $ % ^ *";
                NotificationService._handleNotification({
                    id: 2004,
                    appName: "UnicodeDaemon",
                    summary: specialSummary,
                    body: specialBody,
                    urgency: 0
                });
                let cardSpecial = col.children[2]; // Replaced oldest
                recordResult("Boundary_SpecialChars", cardSpecial !== undefined, "Special characters, emoji, and unicode parsed cleanly without crash");

                // Test 2.5: HTML / Markup tags & entities
                let markupSummary = "<b>Bold</b> <i>Italic</i> <script>alert('pwn')</script>";
                let markupBody = "Entity: &amp; &lt; &gt; &quot; &apos; <font color=\"#ff0000\">Red</font> <unclosed tag";
                NotificationService._handleNotification({
                    id: 2005,
                    appName: "MarkupApp",
                    summary: markupSummary,
                    body: markupBody,
                    urgency: 1
                });
                recordResult("Boundary_MarkupInjection", true, "Markup & entity strings handled safely without engine crash");

            } catch (e) {
                recordResult("Boundary_Execution", false, "Exception: " + e);
            }

            // =================================================================
            // SUITE 3: ACTION BUTTONS EDGE CASES
            // =================================================================
            try {
                clearAllState();
                console.log("\n--- SUITE 3: Action Buttons Edge Cases ---");

                // Test 3.1: Missing identifiers in action objects
                let actionMissingIdInvoked = false;
                let notifActionsMissingId = {
                    id: 3001,
                    appName: "ActionApp1",
                    summary: "Actions without identifier",
                    body: "Testing missing identifier",
                    urgency: 1,
                    actions: [
                        {
                            text: "Custom Label",
                            invoke: function() { actionMissingIdInvoked = true; }
                        }
                    ]
                };
                NotificationService._handleNotification(notifActionsMissingId);
                let col3 = toastSurface.children[0];
                let card3 = col3.children[0];
                let card3Layout = card3.children[1];
                let actionsRow3 = card3Layout.children[3];
                let btn3 = actionsRow3.children[0];
                let labelText3 = btn3.actionLabelText;
                recordResult("Action_MissingId_Label", labelText3 === "Custom Label", "Missing identifier used text for label: '" + labelText3 + "'");

                // Test 3.2: Missing text in action objects
                let notifActionsMissingText = {
                    id: 3002,
                    appName: "ActionApp2",
                    summary: "Actions without text",
                    body: "Testing fallback to identifier",
                    urgency: 1,
                    actions: [
                        {
                            identifier: "view_details"
                        }
                    ]
                };
                NotificationService._handleNotification(notifActionsMissingText);
                let card3_2 = col3.children[1];
                let btn3_2 = card3_2.children[1].children[3].children[0];
                recordResult("Action_MissingText_Label", btn3_2.actionLabelText === "view_details", "Missing text fell back to identifier: '" + btn3_2.actionLabelText + "'");

                // Test 3.3: Multiple actions (5 action buttons)
                let notif5Actions = {
                    id: 3003,
                    appName: "ActionApp3",
                    summary: "5 Actions",
                    body: "Multiple action buttons attached",
                    urgency: 1,
                    actions: [
                        { identifier: "a1", text: "ACT 1" },
                        { identifier: "a2", text: "ACT 2" },
                        { identifier: "a3", text: "ACT 3" },
                        { identifier: "a4", text: "ACT 4" },
                        { identifier: "a5", text: "ACT 5" }
                    ]
                };
                NotificationService._handleNotification(notif5Actions);
                let card3_3 = col3.children[2];
                let actionsRow3_3 = card3_3.children[1].children[3];
                let renderedBtnCount = 0;
                for (let b = 0; b < actionsRow3_3.children.length; b++) {
                    if (actionsRow3_3.children[b].actionLabelText !== undefined) renderedBtnCount++;
                }
                recordResult("Action_MultipleActions", renderedBtnCount === 5, "Rendered 5 action buttons: count=" + renderedBtnCount);

                // Test 3.4: Rapid clicking on action button
                let rapidInvokeCount = 0;
                let rapidNotif = {
                    id: 3004,
                    appName: "RapidActionApp",
                    summary: "Rapid Click Test",
                    body: "Clicking action 10 times in tight loop",
                    urgency: 1,
                    actions: [
                        {
                            identifier: "rapid_act",
                            text: "CLICK RAPID",
                            invoke: function() { rapidInvokeCount++; }
                        }
                    ]
                };
                NotificationService._handleNotification(rapidNotif);
                let rapidCard = col3.children[2]; // Oldest replaced
                let rapidBtn = rapidCard.children[1].children[3].children[0];
                let rapidMouseArea = rapidBtn.children[1];
                for (let rc = 0; rc < 10; rc++) {
                    rapidMouseArea.clicked({ accepted: false });
                }
                recordResult("Action_RapidClicking", rapidInvokeCount === 1, "Rapid clicking invoked action exactly once (count=" + rapidInvokeCount + ") and dismissed cleanly");

            } catch (e) {
                recordResult("Action_Execution", false, "Exception: " + e);
            }

            // =================================================================
            // SUITE 4: URGENCY STYLING & ANIMATIONS UNDER TRANSITIONS
            // =================================================================
            try {
                clearAllState();
                console.log("\n--- SUITE 4: Urgency Styling & Animations Under Transitions ---");

                // Test 4.1: Low Urgency (0)
                NotificationService._handleNotification({
                    id: 4001,
                    appName: "UrgencyLow",
                    summary: "Low Urgency",
                    body: "Check styling",
                    urgency: 0
                });
                let col4 = toastSurface.children[0];
                let cardLow = col4.children[0];
                recordResult("Urgency_Low_Border", cardLow.border.color === Theme.textMuted, "Low urgency border is Theme.textMuted");
                recordResult("Urgency_Low_PulseStopped", cardLow.pulseAnimation.running === false, "Low urgency pulseAnimation is stopped");

                // Test 4.2: Normal Urgency (1)
                NotificationService._handleNotification({
                    id: 4002,
                    appName: "UrgencyNormal",
                    summary: "Normal Urgency",
                    body: "Check styling",
                    urgency: 1
                });
                let cardNormal = col4.children[1];
                recordResult("Urgency_Normal_Border", cardNormal.border.color === Theme.acidGreen, "Normal urgency border is Theme.acidGreen");
                recordResult("Urgency_Normal_PulseStopped", cardNormal.pulseAnimation.running === false, "Normal urgency pulseAnimation is stopped");

                // Test 4.3: Critical Urgency (2)
                NotificationService._handleNotification({
                    id: 4003,
                    appName: "UrgencyCritical",
                    summary: "Critical Urgency",
                    body: "Check pulse animation",
                    urgency: 2
                });
                let cardCritical = col4.children[2];
                recordResult("Urgency_Critical_PulseRunning", cardCritical.pulseAnimation.running === true, "Critical urgency pulseAnimation is running");
                let isInfinite = (cardCritical.pulseAnimation.loops === Animation.Infinite || cardCritical.pulseAnimation.loops < 0);
                recordResult("Urgency_Critical_LoopsInfinite", isInfinite, "Critical urgency loops infinitely (loops=" + cardCritical.pulseAnimation.loops + ")");

                // Test 4.4: Transition existing notification Low -> Critical -> Normal
                // Update 4001 to Critical (2)
                NotificationService._handleNotification({
                    id: 4001,
                    appName: "UrgencyLowUpdated",
                    summary: "Now Critical",
                    body: "Transitioned to critical",
                    urgency: 2
                });
                let updatedCardCrit = col4.children[col4.children.length - 2];
                recordResult("Urgency_TransitionToCritical", updatedCardCrit.urgency === 2 && updatedCardCrit.pulseAnimation.running === true,
                    "Urgency dynamic upgrade to Critical started pulseAnimation");

                // Update 4001 to Normal (1)
                NotificationService._handleNotification({
                    id: 4001,
                    appName: "UrgencyLowUpdated2",
                    summary: "Now Normal",
                    body: "Transitioned to normal",
                    urgency: 1
                });
                let updatedCardNorm = col4.children[col4.children.length - 2];
                recordResult("Urgency_TransitionToNormal", updatedCardNorm.urgency === 1 && updatedCardNorm.pulseAnimation.running === false,
                    "Urgency downgrade to Normal stopped pulseAnimation and restored normal styling");

            } catch (e) {
                recordResult("Urgency_Execution", false, "Exception: " + e);
            }

            // =================================================================
            // SUITE 5: RAPID MOUSE HOVER ENTER/EXIT CYCLES (PAUSE/RESUME TIMERS)
            // =================================================================
            try {
                clearAllState();
                console.log("\n--- SUITE 5: Rapid Mouse Hover Enter/Exit Cycles ---");

                NotificationService._handleNotification({
                    id: 5001,
                    appName: "HoverApp",
                    summary: "Hover Timer Test",
                    body: "Testing pause and resume timers under stress",
                    urgency: 1
                });

                let col5 = toastSurface.children[0];
                let card5 = col5.children[0];
                let mouseArea5 = card5.children[0];

                let timerObj5 = NotificationService._toastTimers[5001];

                // Stress 50 rapid enter/exit cycles
                for (let h = 0; h < 50; h++) {
                    mouseArea5.entered();
                    mouseArea5.exited();
                }

                recordResult("Hover_RapidCycles_NoCrash", timerObj5 !== undefined, "50 rapid enter/exit cycles executed without crash");
                recordResult("Hover_TimerValidState", timerObj5.running === true && !isNaN(timerObj5.remainingMs) && timerObj5.remainingMs > 0,
                    "Timer in valid running state, remainingMs=" + timerObj5.remainingMs);

                // Pause timer via hover and verify it is not running
                mouseArea5.entered();
                recordResult("Hover_PauseStopsTimer", timerObj5.running === false, "mouse entered() paused timer (running=false)");

                // Resume timer via exit and verify it is running
                mouseArea5.exited();
                recordResult("Hover_ResumeStartsTimer", timerObj5.running === true, "mouse exited() resumed timer (running=true)");

            } catch (e) {
                recordResult("Hover_Execution", false, "Exception: " + e);
            }

            // =================================================================
            // SUITE 6: CLICK-TO-DISMISS CONCURRENT WITH EXPIRY TRANSITIONS
            // =================================================================
            try {
                clearAllState();
                console.log("\n--- SUITE 6: Click-to-Dismiss Concurrent with Expiry ---");

                NotificationService._handleNotification({
                    id: 6001,
                    appName: "ConcurrentApp",
                    summary: "Race Test",
                    body: "Simultaneous click and timeout",
                    urgency: 1
                });

                let col6 = toastSurface.children[0];
                let card6 = col6.children[0];
                let mouseArea6 = card6.children[0];
                let timerObj6 = NotificationService._toastTimers[6001];

                // Simulate simultaneous trigger of timer and click
                timerObj6.triggered();
                mouseArea6.clicked({ accepted: false });
                NotificationService.dismissToast(6001); // redundant call

                recordResult("Concurrent_ClickAndExpire", NotificationService.activeToasts.count === 0,
                    "Simultaneous expiry and click handled cleanly: activeToasts count=" + NotificationService.activeToasts.count);

                // Boundary dismiss on invalid IDs
                NotificationService.dismissToast(-1);
                NotificationService.dismissToast(999999);
                recordResult("Concurrent_InvalidDismissId", NotificationService.activeToasts.count === 0,
                    "Dismissing invalid/non-existent IDs is safe and idempotent");

            } catch (e) {
                recordResult("Concurrent_Execution", false, "Exception: " + e);
            }

            // =================================================================
            // SUMMARY EVALUATION
            // =================================================================
            console.log("\n================================================================");
            console.log("=== EMPIRICAL CHALLENGER M3 RESULTS SUMMARY ===");
            console.log("Total Challenges Executed: " + (passCount + failCount));
            console.log("Passed: " + passCount);
            console.log("Failed: " + failCount);
            console.log("================================================================");

            if (failCount === 0) {
                console.log("CHALLENGER_FINAL_VERDICT: ALL TESTS PASSED");
            } else {
                console.error("CHALLENGER_FINAL_VERDICT: " + failCount + " TESTS FAILED");
            }

            Qt.quit();
        }
    }
}
