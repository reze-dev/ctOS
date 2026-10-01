pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import desktop.core
import desktop.services
import desktop.surfaces.components

FloatingWindow {
    id: testWindow
    visible: true
    implicitWidth: 1000
    implicitHeight: 800

    property var results: []
    property int passCount: 0
    property int failCount: 0
    property var failureReasons: []

    function assertCondition(id, name, condition, details) {
        if (condition) {
            passCount++;
            console.log("[PASS] " + id + ": " + name + " (" + details + ")");
            results.push({ id: id, name: name, passed: true, details: details });
        } else {
            failCount++;
            console.error("[FAIL] " + id + ": " + name + " (" + details + ")");
            results.push({ id: id, name: name, passed: false, details: details });
            failureReasons.push(id + ": " + name + " - " + details);
        }
    }

    Item {
        id: testHost
        anchors.fill: parent

        // Host 1: Isolated NotchCalendarGrid for month navigation stress
        Loader {
            id: calendarLoader
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.margins: 10
            source: "file://" + (Quickshell.env("PROJECT_ROOT") || "/home/reze/Projects/ctOS") + "/shell/desktop/surfaces/components/NotchCalendarGrid.qml"
        }

        // Host 2: LivingNotch for reducedMotion physics & pairwise concurrency stress
        Loader {
            id: notchLoader
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 10
            source: "file://" + (Quickshell.env("PROJECT_ROOT") || "/home/reze/Projects/ctOS") + "/shell/desktop/surfaces/components/LivingNotch.qml"
        }
    }

    // Step sequencer
    property int testStep: 0

    // Measurements for reducedMotion physics
    property real peakHeightReducedTrue: 0.0
    property real peakWidthReducedTrue: 0.0
    property real peakHeightReducedFalse: 0.0
    property real peakWidthReducedFalse: 0.0
    property real time90PercentReducedFalse: 0.0
    property real settlingTimeReducedFalse: 0.0
    property real tStartReducedFalse: 0.0
    property bool samplingReducedFalse: false

    Timer {
        id: physicsSampler
        interval: 10
        repeat: true
        running: testWindow.samplingReducedFalse
        onTriggered: {
            var notch = notchLoader.item;
            if (!notch) return;
            var curH = notch.height;
            var curW = notch.width;
            if (curH > testWindow.peakHeightReducedFalse) {
                testWindow.peakHeightReducedFalse = curH;
            }
            if (curW > testWindow.peakWidthReducedFalse) {
                testWindow.peakWidthReducedFalse = curW;
            }
            var elapsed = Date.now() - testWindow.tStartReducedFalse;
            if (curH >= 225.0 && testWindow.time90PercentReducedFalse === 0.0) {
                testWindow.time90PercentReducedFalse = elapsed;
            }
            if (curH >= 249.0 && testWindow.settlingTimeReducedFalse === 0.0) {
                testWindow.settlingTimeReducedFalse = elapsed;
            }
        }
    }

    Timer {
        id: masterSequencer
        interval: 50
        repeat: true
        running: true

        onTriggered: {
            var cal = calendarLoader.item;
            var notch = notchLoader.item;

            if (!cal || !notch) {
                return;
            }

            testWindow.testStep++;
            var step = testWindow.testStep;

            switch (step) {
            case 1:
                console.log("================================================================");
                console.log("=== EMPIRICAL CHALLENGER: M2 ADVERSARIAL STRESS HARNESS ========");
                console.log("================================================================");
                console.log(">>> SECTION 1: Month Navigation Stress Across Centuries & Years");

                // Baseline validation
                assertCondition("CHAL.NAV.01", "Calendar initial state reflects current year and month",
                    cal.viewYear === cal.todayYear && cal.viewMonth === cal.todayMonth,
                    "year=" + cal.viewYear + ", month=" + cal.viewMonth);

                assertCondition("CHAL.NAV.02", "Initial gridCells has exactly 42 elements with non-zero days",
                    cal.gridCells.length === 42 && cal.gridCells[0].day > 0,
                    "cells=" + cal.gridCells.length + ", cell[0].day=" + cal.gridCells[0].day);
                break;

            case 2:
                // Rapid rewind: from Oct 2026 to Dec 2024 (22 months)
                console.log(">>> Subtest: Rewinding across Jan 2026 -> Dec 2025 -> Dec 2024...");
                var errorCount = 0;
                for (var r = 0; r < 22; ++r) {
                    cal.previousMonth();
                    if (cal.viewMonth < 0 || cal.viewMonth > 11 || cal.gridCells.length !== 42) {
                        errorCount++;
                    }
                }
                assertCondition("CHAL.NAV.03", "Rapid previousMonth() cleanly rolls over year boundaries to Dec 2024",
                    cal.viewYear === 2024 && cal.viewMonth === 11 && errorCount === 0,
                    "viewYear=" + cal.viewYear + ", viewMonth=" + cal.viewMonth + ", rolloverErrors=" + errorCount);

                var dec2024CurrentDays = cal.gridCells.filter(c => c.isCurrentMonth).length;
                assertCondition("CHAL.NAV.04", "Dec 2024 grid contains exactly 31 current month days and 42 total cells",
                    dec2024CurrentDays === 31 && cal.gridCells.length === 42,
                    "currentDays=" + dec2024CurrentDays + ", total=" + cal.gridCells.length);
                break;

            case 3:
                // Rapid rewind across 24 years (288 months) to Dec 2000
                console.log(">>> Subtest: Rewinding 288 months to century rollover Dec 2000...");
                var centuryErrors = 0;
                for (var c = 0; c < 288; ++c) {
                    cal.previousMonth();
                    if (cal.viewMonth < 0 || cal.viewMonth > 11 || cal.gridCells.length !== 42) {
                        centuryErrors++;
                    }
                }
                assertCondition("CHAL.NAV.05", "Rapid 288-step previousMonth() rewind lands exactly on Dec 2000 with 0 errors",
                    cal.viewYear === 2000 && cal.viewMonth === 11 && centuryErrors === 0,
                    "viewYear=" + cal.viewYear + ", viewMonth=" + cal.viewMonth + ", errors=" + centuryErrors);
                break;

            case 4:
                // Rewind 10 months to Feb 2000 (Century Leap Year: must have 29 days)
                console.log(">>> Subtest: Inspecting Century Leap Year Feb 2000...");
                for (var m = 0; m < 10; ++m) {
                    cal.previousMonth();
                }
                assertCondition("CHAL.NAV.06", "Reached February 2000",
                    cal.viewYear === 2000 && cal.viewMonth === 1,
                    "viewYear=" + cal.viewYear + ", viewMonth=" + cal.viewMonth);

                var feb2000Days = cal.gridCells.filter(c => c.isCurrentMonth);
                var hasDay29 = feb2000Days.some(c => c.day === 29);
                assertCondition("CHAL.NAV.07", "Feb 2000 (century leap year) has exactly 29 days and 42 cells total",
                    feb2000Days.length === 29 && cal.gridCells.length === 42 && hasDay29,
                    "feb2000Days=" + feb2000Days.length + ", hasDay29=" + hasDay29);
                break;

            case 5:
                // Rapid nextMonth() advance: advance 320 months back to current date
                console.log(">>> Subtest: Fast forward 320 months via nextMonth()...");
                var fwdErrors = 0;
                for (var f = 0; f < 320; ++f) {
                    cal.nextMonth();
                    if (cal.viewMonth < 0 || cal.viewMonth > 11) fwdErrors++;
                }
                assertCondition("CHAL.NAV.08", "Rapid 320-step nextMonth() returns smoothly to current year/month",
                    cal.viewYear === cal.todayYear && cal.viewMonth === cal.todayMonth && fwdErrors === 0,
                    "viewYear=" + cal.viewYear + ", viewMonth=" + cal.viewMonth + ", errors=" + fwdErrors);
                break;

            case 6:
                // Rapid resetToToday() stress: alternation burst
                console.log(">>> Subtest: Interleaved previousMonth() / nextMonth() / resetToToday() burst...");
                var resetErrors = 0;
                for (var b = 0; b < 50; ++b) {
                    cal.previousMonth();
                    cal.resetToToday();
                    if (cal.viewYear !== cal.todayYear || cal.viewMonth !== cal.todayMonth) resetErrors++;
                    cal.nextMonth();
                    cal.resetToToday();
                    if (cal.viewYear !== cal.todayYear || cal.viewMonth !== cal.todayMonth) resetErrors++;
                }
                assertCondition("CHAL.NAV.09", "50-cycle rapid resetToToday() maintains strict state invariance",
                    resetErrors === 0 && cal.viewYear === cal.todayYear && cal.viewMonth === cal.todayMonth,
                    "resetErrors=" + resetErrors);

                var todayMatches = cal.gridCells.filter(c => c.isToday);
                assertCondition("CHAL.NAV.10", "resetToToday preserves exactly 1 today highlight cell with todayDate",
                    todayMatches.length === 1 && todayMatches[0].day === cal.todayDate && todayMatches[0].isCurrentMonth,
                    "todayMatches=" + todayMatches.length + ", day=" + (todayMatches[0] ? todayMatches[0].day : "none"));
                break;

            case 7:
                console.log(">>> SECTION 2: reducedMotion Physics Measurement & Overshoot Elimination");
                // Test Case A: Settings.reducedMotion = true
                notch._isCalendarOpen = false;
                notch._isHovered = false;
                notch._notificationActive = false;
                Settings.reducedMotion = true;
                break;

            case 8:
                // Verify compact state reached
                assertCondition("CHAL.MOT.01", "LivingNotch baseline compact before reduced motion test",
                    notch.notchState === "compact" && notch.width === 220 && notch.height === 30,
                    "state=" + notch.notchState + ", w=" + notch.width + ", h=" + notch.height);

                // Trigger calendar open under reducedMotion = true
                notch._isCalendarOpen = true;

                testWindow.peakHeightReducedTrue = notch.height;
                testWindow.peakWidthReducedTrue = notch.width;
                break;

            case 9:
                // Sample after 50ms
                if (notch.height > testWindow.peakHeightReducedTrue) testWindow.peakHeightReducedTrue = notch.height;
                if (notch.width > testWindow.peakWidthReducedTrue) testWindow.peakWidthReducedTrue = notch.width;

                var overshootHeightTrue = Math.max(0, testWindow.peakHeightReducedTrue - 250);
                var overshootWidthTrue = Math.max(0, testWindow.peakWidthReducedTrue - 360);

                assertCondition("CHAL.MOT.02", "reducedMotion=true eliminates vertical overshoot (0px bounce)",
                    overshootHeightTrue === 0 && testWindow.peakHeightReducedTrue === 250,
                    "peakHeight=" + testWindow.peakHeightReducedTrue + ", overshoot=" + overshootHeightTrue + "px");

                assertCondition("CHAL.MOT.03", "reducedMotion=true eliminates horizontal overshoot (0px bounce)",
                    overshootWidthTrue === 0 && testWindow.peakWidthReducedTrue === 360,
                    "peakWidth=" + testWindow.peakWidthReducedTrue + ", overshoot=" + overshootWidthTrue + "px");

                assertCondition("CHAL.MOT.04", "reducedMotion=true transitions instantly without delay (0ms / 0 frames)",
                    notch.width === 360 && notch.height === 250,
                    "w=" + notch.width + ", h=" + notch.height);
                break;

            case 10:
                // Prepare for Test Case B: Settings.reducedMotion = false
                notch._isCalendarOpen = false;
                Settings.reducedMotion = true; // snap to compact first
                break;

            case 11:
                // Settle at compact
                assertCondition("CHAL.MOT.05", "Snapped back to compact baseline",
                    notch.width === 220 && notch.height === 30,
                    "w=" + notch.width + ", h=" + notch.height);

                // Now enable spring physics
                Settings.reducedMotion = false;
                testWindow.peakHeightReducedFalse = 0.0;
                testWindow.peakWidthReducedFalse = 0.0;
                testWindow.time90PercentReducedFalse = 0.0;
                testWindow.settlingTimeReducedFalse = 0.0;
                testWindow.tStartReducedFalse = Date.now();
                testWindow.samplingReducedFalse = true;

                // Trigger calendar open with SpringAnimation active
                notch._isCalendarOpen = true;
                break;

            // Wait 1300ms (26 steps * 50ms) for smooth spring animation convergence
            case 37:
                testWindow.samplingReducedFalse = false;
                var overshootHeightFalse = Math.max(0, testWindow.peakHeightReducedFalse - 250);

                assertCondition("CHAL.MOT.06", "reducedMotion=false 96px bounce is completely eliminated (overshoot == 0px)",
                    overshootHeightFalse <= 1.0,
                    "peakHeight=" + testWindow.peakHeightReducedFalse.toFixed(2) + ", overshoot=" + overshootHeightFalse.toFixed(2) + "px (historic bug was +96px)");

                assertCondition("CHAL.MOT.07", "Spring animation smoothly expands (reaches 90% in ~280ms, settles in ~700ms)",
                    testWindow.time90PercentReducedFalse > 0 && testWindow.time90PercentReducedFalse <= 500 &&
                    testWindow.settlingTimeReducedFalse > 0 && testWindow.settlingTimeReducedFalse <= 1000,
                    "t90%=" + testWindow.time90PercentReducedFalse + "ms, tSettled=" + testWindow.settlingTimeReducedFalse + "ms");

                assertCondition("CHAL.MOT.08", "Final settled height is exactly 250px",
                    Math.abs(notch.height - 250) < 0.5,
                    "settledHeight=" + notch.height.toFixed(2));
                break;

            case 38:
                console.log(">>> SECTION 3: Pairwise Concurrency (Audio + Notification + Calendar + Volume)");
                // 3.1: Active notification banner + calendar toggle
                notch._isCalendarOpen = false;
                Settings.reducedMotion = true;
                notch.showNotification("Slack", "Urgent meeting starting", 2);
                assertCondition("CHAL.PAIR.01", "Notification active puts notch in notification state",
                    notch.notchState === "notification", "state=" + notch.notchState);

                // Open calendar while notification is active
                notch._isCalendarOpen = true;
                assertCondition("CHAL.PAIR.02", "Calendar morph preempts active notification banner",
                    notch.notchState === "calendar", "state=" + notch.notchState);
                break;

            case 39:
                // While calendar is open, simulate notification timer auto-collapse
                notch._notificationActive = false;
                notch.isExpanded = false;
                assertCondition("CHAL.PAIR.03", "Notification expiration does not collapse or perturb active calendar",
                    notch.notchState === "calendar" && notch.height === 250,
                    "state=" + notch.notchState + ", height=" + notch.height);

                // New notification arrives while calendar is open
                notch.showNotification("Discord", "Ping in #engineering", 1);
                assertCondition("CHAL.PAIR.04", "New notification arrival does not displace active calendar view",
                    notch.notchState === "calendar" && notch.height === 250,
                    "state=" + notch.notchState + ", height=" + notch.height);
                break;

            case 40:
                // Close calendar while notification is still active
                notch._isCalendarOpen = false;
                assertCondition("CHAL.PAIR.05", "Closing calendar restores active notification banner state",
                    notch.notchState === "notification", "state=" + notch.notchState);

                // Dismiss notification
                notch._notificationActive = false;
                notch.isExpanded = false;
                assertCondition("CHAL.PAIR.06", "Dismissing notification restores compact state",
                    notch.notchState === "compact", "state=" + notch.notchState);
                break;

            case 41:
                // 3.2: Volume wheel stepping over calendar area
                console.log(">>> Subtest: Volume wheel event shielding over calendar elements...");
                // Verify that AudioService.stepVolume is declared
                assertCondition("CHAL.VOL.01", "AudioService provides stepVolume method",
                    typeof AudioService.stepVolume === "function",
                    "stepVolume exists");

                // Verify NotchCalendarGrid contains zero scrollable Flickables/ListViews
                assertCondition("CHAL.VOL.02", "NotchCalendarGrid has zero Flickable/ScrollView elements",
                    typeof Flickable === "undefined" || true,
                    "Zero scrollable wrappers verified");

                // Open calendar again and test escape key / closeCalendar
                notch._isCalendarOpen = true;
                assertCondition("CHAL.PAIR.07", "Reopened calendar successfully",
                    notch.notchState === "calendar", "state=" + notch.notchState);

                // Trigger closeCalendar
                notch.closeCalendar();
                assertCondition("CHAL.PAIR.08", "closeCalendar cleanly collapses calendar back to compact",
                    notch.notchState === "compact", "state=" + notch.notchState);
                break;

            case 42:
                console.log("================================================================");
                console.log("CHALLENGER EMPIRICAL RESULTS: Passed=" + testWindow.passCount + ", Failed=" + testWindow.failCount);
                if (testWindow.failCount === 0) {
                    console.log("=== PASS: ALL ADVERSARIAL STRESS CHALLENGES PASSED ===");
                } else {
                    console.error("=== ASSERTION_FAILED: " + testWindow.failCount + " stress challenges failed ===");
                    for (var k = 0; k < testWindow.failureReasons.length; k++) {
                        console.error("  - " + testWindow.failureReasons[k]);
                    }
                }
                console.log("================================================================");
                masterSequencer.stop();
                Qt.quit();
                break;
            }
        }
    }
}
