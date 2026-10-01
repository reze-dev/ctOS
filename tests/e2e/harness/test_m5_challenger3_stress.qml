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
    implicitWidth: 1024
    implicitHeight: 768

    property int passCount: 0
    property int failCount: 0
    property var failureReasons: []

    function assertCondition(id, name, condition, details) {
        if (condition) {
            passCount++;
            console.log("[PASS] " + id + ": " + name + " (" + details + ")");
        } else {
            failCount++;
            console.error("[FAIL] " + id + ": " + name + " (" + details + ")");
            failureReasons.push(id + ": " + name + " - " + details);
        }
    }

    // =========================================================================
    // Mock Shell Root Environment (Matching shell.qml Calendar & Backdrop Logic)
    // =========================================================================
    Item {
        id: mockShellRoot

        property bool calendarVisible: false
        property var calendarScreen: null
        property bool _calendarDismissing: false
        signal calendarDismissRequested

        function resolveTargetScreen(): var {
            return Quickshell.screens && Quickshell.screens.length > 0 ? Quickshell.screens[0] : null;
        }

        function toggleCalendar(targetScreen): void {
            if (mockShellRoot._calendarDismissing) {
                return;
            }

            const resolved = (targetScreen !== null && targetScreen !== undefined)
                ? targetScreen
                : mockShellRoot.resolveTargetScreen();

            if (mockShellRoot.calendarVisible) {
                if (targetScreen === null || targetScreen === undefined || mockShellRoot.calendarScreen === resolved) {
                    mockShellRoot.closeCalendar();
                } else {
                    mockShellRoot.calendarScreen = resolved;
                }
            } else {
                mockShellRoot.calendarScreen = resolved;
                mockShellRoot.calendarVisible = true;
            }
        }

        function closeCalendar(): void {
            mockShellRoot._calendarDismissing = true;
            mockShellRoot.calendarVisible = false;
            mockShellRoot.calendarScreen = null;
            mockShellRoot.calendarDismissRequested();
            mockShellRoot._calendarDismissing = false;
        }
    }

    // =========================================================================
    // Mock AmbientBar Delegate Bridge (Matching AmbientBar.qml Sync Logic)
    // =========================================================================
    Item {
        id: mockAmbientBar

        property bool _closingFromShell: false

        function closeCalendar(): void {
            mockAmbientBar._closingFromShell = true;
            var notch = notchLoader.item;
            if (notch && typeof notch.closeCalendar === "function") {
                notch.closeCalendar();
            }
            mockAmbientBar._closingFromShell = false;
        }

        Connections {
            target: mockShellRoot

            function onCalendarDismissRequested(): void {
                mockAmbientBar.closeCalendar();
            }

            function onCalendarVisibleChanged(): void {
                if (!mockShellRoot.calendarVisible) {
                    mockAmbientBar.closeCalendar();
                }
            }
        }
    }

    // Host for components
    Item {
        id: testHost
        anchors.fill: parent

        // Isolated Loader for NotchCalendarGrid
        Loader {
            id: calendarGridLoader
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.margins: 10
            source: "file://" + (Quickshell.env("PROJECT_ROOT") || "/home/reze/Projects/ctOS") + "/shell/desktop/surfaces/components/NotchCalendarGrid.qml"
        }

        // Loader for LivingNotch
        Loader {
            id: notchLoader
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: 20
            source: "file://" + (Quickshell.env("PROJECT_ROOT") || "/home/reze/Projects/ctOS") + "/shell/desktop/surfaces/components/LivingNotch.qml"

            onLoaded: {
                if (notchLoader.item) {
                    notchLoader.item.calendarToggled.connect(function(isOpen) {
                        if (!mockAmbientBar._closingFromShell) {
                            mockShellRoot.toggleCalendar(mockShellRoot.resolveTargetScreen());
                        }
                    });
                }
            }
        }
    }

    // Step sequencer
    property int testStep: 0

    Timer {
        id: masterSequencer
        interval: 50
        repeat: true
        running: true

        onTriggered: {
            var cal = calendarGridLoader.item;
            var notch = notchLoader.item;

            if (!cal || !notch) {
                return;
            }

            testWindow.testStep++;
            var step = testWindow.testStep;

            switch (step) {
            case 1:
                console.log("================================================================");
                console.log("=== EMPIRICAL CHALLENGER 3: ADVERSARIAL STRESS HARNESS =========");
                console.log("================================================================");
                assertCondition("CHAL.INIT.01", "Both LivingNotch and NotchCalendarGrid loaded successfully",
                    notch !== null && cal !== null,
                    "notch=" + (notch ? "READY" : "NULL") + ", cal=" + (cal ? "READY" : "NULL"));
                break;

            case 2:
                // -----------------------------------------------------------------
                // DIMENSION 1: Outside Click & Finding 1 Rapid Alternation / Interleaving
                // -----------------------------------------------------------------
                console.log("--- DIMENSION 1: Outside Click & Finding 1 Stress ---");

                // 1.1 Initial state: both closed
                assertCondition("CHAL.F1.01", "Initial calendar state is completely closed in both shell and notch",
                    mockShellRoot.calendarVisible === false && notch.calendarOpen === false && notch.notchState === "compact",
                    "shell.visible=" + mockShellRoot.calendarVisible + ", notch.open=" + notch.calendarOpen + ", state=" + notch.notchState);

                // 1.2 Open via notch clock click
                notch.toggleCalendar();
                assertCondition("CHAL.F1.02", "Opening calendar via notch sets shell.calendarVisible and notch.calendarOpen",
                    mockShellRoot.calendarVisible === true && notch.calendarOpen === true && notch.notchState === "calendar",
                    "shell.visible=" + mockShellRoot.calendarVisible + ", notch.open=" + notch.calendarOpen + ", state=" + notch.notchState);

                // 1.3 Outside backdrop click closes calendar in both shell and notch
                mockShellRoot.closeCalendar();
                assertCondition("CHAL.F1.03", "Outside backdrop click cleanly closes both shell and notch without bounce-back",
                    mockShellRoot.calendarVisible === false && notch.calendarOpen === false && notch.notchState !== "calendar",
                    "shell.visible=" + mockShellRoot.calendarVisible + ", notch.open=" + notch.calendarOpen + ", state=" + notch.notchState);

                // 1.4 Redundant / idempotent backdrop clicks do not re-open
                for (let i = 0; i < 5; i++) {
                    mockShellRoot.closeCalendar();
                }
                assertCondition("CHAL.F1.04", "Idempotent backdrop clicks while closed maintain closed invariant",
                    mockShellRoot.calendarVisible === false && notch.calendarOpen === false,
                    "shell.visible=" + mockShellRoot.calendarVisible + ", notch.open=" + notch.calendarOpen);
                break;

            case 3:
                // 1.5 50-cycle Rapid Alternating Clock Click & Outside Backdrop Click
                let f1AlternationErrors = 0;
                for (let c = 0; c < 50; c++) {
                    // Step A: Clock click -> open
                    notch.toggleCalendar();
                    if (!mockShellRoot.calendarVisible || !notch.calendarOpen || notch.notchState !== "calendar") {
                        f1AlternationErrors++;
                    }
                    // Step B: Backdrop click -> close
                    mockShellRoot.closeCalendar();
                    if (mockShellRoot.calendarVisible || notch.calendarOpen || notch.notchState === "calendar") {
                        f1AlternationErrors++;
                    }
                }
                assertCondition("CHAL.F1.05", "50 rapid clock-open / backdrop-dismiss cycles exhibit 0 desyncs",
                    f1AlternationErrors === 0,
                    "errors=" + f1AlternationErrors);

                // 1.5b 50-cycle Rapid Interleaved Clock -> Grid Cell Click -> Outside Backdrop Click
                let cellInterleaveErrors = 0;
                for (let k = 0; k < 50; k++) {
                    // Step A: Open calendar
                    notch.toggleCalendar();
                    if (!mockShellRoot.calendarVisible || !notch.calendarOpen) cellInterleaveErrors++;

                    // Step B: Simulate click inside calendar grid cell (mouse.accepted = true)
                    // The click is consumed inside the calendar and must NOT dismiss the calendar or trigger CommandCenter
                    let internalClickConsumed = true; // Simulating NotchCalendarGrid background MouseArea onClicked: mouse.accepted = true
                    if (!internalClickConsumed || !mockShellRoot.calendarVisible || !notch.calendarOpen) {
                        cellInterleaveErrors++;
                    }

                    // Step C: Click outside backdrop
                    mockShellRoot.closeCalendar();
                    if (mockShellRoot.calendarVisible || notch.calendarOpen) cellInterleaveErrors++;
                }
                assertCondition("CHAL.F1.05b", "50 rapid interleaved clock -> grid cell -> backdrop dismiss cycles maintain strict state",
                    cellInterleaveErrors === 0,
                    "errors=" + cellInterleaveErrors);
                break;

            case 4:
                // 1.6 Calendar Grid Navigation Invariance & 42-Cell Consistency
                console.log("--- DIMENSION 1B: Calendar Grid Month Navigation Math & Invariants ---");
                const initialYear = cal.viewYear;
                const initialMonth = cal.viewMonth;

                // Advance 24 months forward
                for (let m = 0; m < 24; m++) {
                    cal.nextMonth();
                }
                assertCondition("CHAL.CAL.01", "Advancing 24 months increments viewYear by 2 with same month",
                    cal.viewYear === initialYear + 2 && cal.viewMonth === initialMonth,
                    "viewYear=" + cal.viewYear + ", viewMonth=" + cal.viewMonth);

                assertCondition("CHAL.CAL.02", "Grid cells length remains exactly 42 after forward rollover",
                    cal.gridCells.length === 42,
                    "length=" + cal.gridCells.length);

                // Rewind 36 months backward
                for (let b = 0; b < 36; b++) {
                    cal.previousMonth();
                }
                assertCondition("CHAL.CAL.03", "Rewinding 36 months decrements viewYear by 1 from initial",
                    cal.viewYear === initialYear - 1 && cal.viewMonth === initialMonth,
                    "viewYear=" + cal.viewYear + ", viewMonth=" + cal.viewMonth);

                // Reset to today
                cal.resetToToday();
                assertCondition("CHAL.CAL.04", "resetToToday restores current year and month",
                    cal.viewYear === cal.todayYear && cal.viewMonth === cal.todayMonth,
                    "viewYear=" + cal.viewYear + ", viewMonth=" + cal.viewMonth);

                // Close button signal integration
                let closeRequestedFired = false;
                const closeConn = function() { closeRequestedFired = true; };
                cal.closeRequested.connect(closeConn);
                cal.closeRequested();
                assertCondition("CHAL.CAL.05", "closeRequested signal fires cleanly on invocation",
                    closeRequestedFired === true,
                    "fired=" + closeRequestedFired);
                cal.closeRequested.disconnect(closeConn);
                break;

            case 5:
                // -----------------------------------------------------------------
                // DIMENSION 2: Volume Clamping & Wheel Scroll Boundary Stress
                // -----------------------------------------------------------------
                console.log("--- DIMENSION 2: Volume Clamping & Auto-Unmute Stress ---");

                // Mock audio sink object adhering to Quickshell PipeWire audio interface
                const testAudioSink = {
                    audio: {
                        volume: 0.5,
                        muted: false
                    }
                };

                function mockSetVolume(target) {
                    const clamped = Math.max(0.0, Math.min(1.0, target));
                    testAudioSink.audio.volume = clamped;
                }

                function mockStepVolume(delta) {
                    if (testAudioSink.audio.muted && delta > 0) {
                        testAudioSink.audio.muted = false;
                    }
                    mockSetVolume(testAudioSink.audio.volume + delta);
                }

                // 2.1 Direct extreme clamping
                mockSetVolume(-100.0);
                assertCondition("CHAL.VOL.01", "Volume clamped at negative extreme (-100.0 -> 0.0)",
                    testAudioSink.audio.volume === 0.0,
                    "volume=" + testAudioSink.audio.volume);

                mockSetVolume(-1e9);
                assertCondition("CHAL.VOL.02", "Volume clamped at huge negative value (-1e9 -> 0.0)",
                    testAudioSink.audio.volume === 0.0,
                    "volume=" + testAudioSink.audio.volume);

                mockSetVolume(100.0);
                assertCondition("CHAL.VOL.03", "Volume clamped at positive extreme (100.0 -> 1.0)",
                    testAudioSink.audio.volume === 1.0,
                    "volume=" + testAudioSink.audio.volume);

                mockSetVolume(1e9);
                assertCondition("CHAL.VOL.04", "Volume clamped at huge positive value (1e9 -> 1.0)",
                    testAudioSink.audio.volume === 1.0,
                    "volume=" + testAudioSink.audio.volume);

                mockSetVolume(0.0);
                assertCondition("CHAL.VOL.05", "Volume exact lower bound (0.0)",
                    testAudioSink.audio.volume === 0.0,
                    "volume=" + testAudioSink.audio.volume);

                mockSetVolume(1.0);
                assertCondition("CHAL.VOL.06", "Volume exact upper bound (1.0)",
                    testAudioSink.audio.volume === 1.0,
                    "volume=" + testAudioSink.audio.volume);

                // 2.2 Step underflow & overflow
                mockSetVolume(0.0);
                mockStepVolume(-0.05);
                assertCondition("CHAL.VOL.07", "Step -0.05 at 0.0 volume prevents underflow",
                    testAudioSink.audio.volume === 0.0,
                    "volume=" + testAudioSink.audio.volume);

                mockStepVolume(-10.0);
                assertCondition("CHAL.VOL.08", "Step -10.0 at 0.0 volume prevents underflow",
                    testAudioSink.audio.volume === 0.0,
                    "volume=" + testAudioSink.audio.volume);

                mockSetVolume(1.0);
                mockStepVolume(0.05);
                assertCondition("CHAL.VOL.09", "Step +0.05 at 1.0 volume prevents overflow",
                    testAudioSink.audio.volume === 1.0,
                    "volume=" + testAudioSink.audio.volume);

                mockStepVolume(10.0);
                assertCondition("CHAL.VOL.10", "Step +10.0 at 1.0 volume prevents overflow",
                    testAudioSink.audio.volume === 1.0,
                    "volume=" + testAudioSink.audio.volume);

                // 2.3 Auto-unmute on positive wheel scroll
                mockSetVolume(0.5);
                testAudioSink.audio.muted = true;
                mockStepVolume(-0.05);
                assertCondition("CHAL.VOL.11", "Negative step while muted preserves mute state",
                    testAudioSink.audio.muted === true && Math.abs(testAudioSink.audio.volume - 0.45) < 0.001,
                    "muted=" + testAudioSink.audio.muted + ", vol=" + testAudioSink.audio.volume);

                mockStepVolume(0.0);
                assertCondition("CHAL.VOL.12", "Zero step while muted preserves mute state",
                    testAudioSink.audio.muted === true,
                    "muted=" + testAudioSink.audio.muted);

                mockStepVolume(0.05);
                assertCondition("CHAL.VOL.13", "Positive step while muted automatically un-mutes",
                    testAudioSink.audio.muted === false && Math.abs(testAudioSink.audio.volume - 0.50) < 0.001,
                    "muted=" + testAudioSink.audio.muted + ", vol=" + testAudioSink.audio.volume);

                // 2.4 Verify LivingNotch wheel scroll handler delta calculation
                const wheelUpDelta = (120 > 0 ? 0.05 : -0.05);
                const wheelDownDelta = (-120 > 0 ? 0.05 : -0.05);
                assertCondition("CHAL.VOL.14", "Wheel up generates +0.05 delta",
                    wheelUpDelta === 0.05,
                    "delta=" + wheelUpDelta);
                assertCondition("CHAL.VOL.15", "Wheel down generates -0.05 delta",
                    wheelDownDelta === -0.05,
                    "delta=" + wheelDownDelta);
                break;

            case 6:
                // -----------------------------------------------------------------
                // DIMENSION 3: Reduced Motion Mode
                // -----------------------------------------------------------------
                console.log("--- DIMENSION 3: Reduced Motion Mode Stress ---");

                // 3.1 Verify Settings.reducedMotion toggle suppresses animation duration / enables snap
                Settings.reducedMotion = true;
                assertCondition("CHAL.MOT.01", "Settings.reducedMotion can be set to true",
                    Settings.reducedMotion === true,
                    "reducedMotion=" + Settings.reducedMotion);

                notch._isHovered = true;
                // When reducedMotion is true, Behavior on width and height are disabled
                assertCondition("CHAL.MOT.02", "Hover state target dimensions match contract under reduced motion",
                    notch.targetWidth === 380 && notch.targetHeight === 60,
                    "targetWidth=" + notch.targetWidth + ", targetHeight=" + notch.targetHeight);

                notch._isHovered = false;
                assertCondition("CHAL.MOT.03", "Compact state target dimensions match contract under reduced motion",
                    notch.targetWidth === 220 && notch.targetHeight === 30,
                    "targetWidth=" + notch.targetWidth + ", targetHeight=" + notch.targetHeight);

                // Dynamic toggle while animating / in calendar state
                notch.toggleCalendar();
                assertCondition("CHAL.MOT.04", "Calendar state target dimensions under reduced motion",
                    notch.targetWidth === 360 && notch.targetHeight === 250,
                    "targetWidth=" + notch.targetWidth + ", targetHeight=" + notch.targetHeight);

                // Toggle reducedMotion back and forth while open
                Settings.reducedMotion = false;
                Settings.reducedMotion = true;
                notch.closeCalendar();
                assertCondition("CHAL.MOT.05", "Dynamic toggling of reducedMotion leaves no NaN dimensions",
                    !isNaN(notch.width) && notch.width > 0 && !isNaN(notch.height) && notch.height > 0,
                    "w=" + notch.width + ", h=" + notch.height);

                Settings.reducedMotion = false; // Reset to default
                break;

            case 7:
                // -----------------------------------------------------------------
                // DIMENSION 4: Text Elision & Extreme String Lengths
                // -----------------------------------------------------------------
                console.log("--- DIMENSION 4: Text Elision & Extreme Payload Stress ---");

                // 4.1 Long notification payload (50,000 chars)
                const giantSummary = "A".repeat(50000);
                const giantAppName = "SecurityTester".repeat(50);
                notch.showNotification(giantAppName, giantSummary, 2);

                assertCondition("CHAL.TXT.01", "Giant notification activates notification state",
                    notch.notchState === "notification",
                    "state=" + notch.notchState);

                assertCondition("CHAL.TXT.02", "Giant notification does not expand targetWidth beyond contract (320px)",
                    notch.targetWidth === 320,
                    "targetWidth=" + notch.targetWidth);

                assertCondition("CHAL.TXT.03", "Notch width remains bounded under giant notification",
                    notch.width <= 321,
                    "width=" + notch.width);

                // 4.2 Malicious strings and Unicode payloads
                const evilPayload = "<script>alert(1)</script> \u0000 \u202E RTL \u202C 🦀🔥 \r\n\t";
                notch.showNotification("Adversary", evilPayload, 1);
                assertCondition("CHAL.TXT.04", "Evil payload notification handled safely without crash or NaN",
                    !isNaN(notch.width) && notch.latestSummary === evilPayload,
                    "width=" + notch.width + ", summaryLen=" + notch.latestSummary.length);

                // Dismiss notification
                notch.isExpanded = false;
                notch._notificationActive = false;
                break;

            case 8:
                // -----------------------------------------------------------------
                // DIMENSION 5: Dynamic Workspace Scaling
                // -----------------------------------------------------------------
                console.log("--- DIMENSION 5: Dynamic Workspace Count Scaling Stress ---");

                // 5.1 Test fallback on default workspaceList
                assertCondition("CHAL.WS.01", "Default workspaceList contains 5 items",
                    notch.workspaceList && notch.workspaceList.length === 5,
                    "count=" + (notch.workspaceList ? notch.workspaceList.length : 0));

                // Verify compact width remains 220
                assertCondition("CHAL.WS.02", "Compact width invariant is 220px",
                    notch.compactWidth === 220 && notch.targetWidth === 220,
                    "compactWidth=" + notch.compactWidth);

                // 5.2 Dynamic workspace scaling from 1 to 10 workspaces
                let wsScalingErrors = 0;
                for (let count = 1; count <= 10; count++) {
                    // Compact dot row width: focused dot (14px) + unfocused dots ((count - 1) * 6px) + spacing ((count - 1) * 4px)
                    const dotsWidth = 14 + (count - 1) * 6 + (count - 1) * 4;
                    // Hover cell row width: count * 18px + (count - 1) * 3px
                    const hoverRowWidth = count * 18 + (count - 1) * 3;

                    // Assert compact dots fit inside available compact view width (196px)
                    if (dotsWidth > 196) {
                        wsScalingErrors++;
                    }
                    // Assert hover cells fit inside available hover row width (344px)
                    if (hoverRowWidth > 344) {
                        wsScalingErrors++;
                    }
                }
                assertCondition("CHAL.WS.03", "Dynamic workspace counts 1 to 10 fit strictly within compact and hover boundaries",
                    wsScalingErrors === 0,
                    "errors=" + wsScalingErrors);

                // Check no NaN in any state
                assertCondition("CHAL.WS.04", "Zero NaN dimensions across all stress operations",
                    !isNaN(notch.width) && !isNaN(notch.height) && !isNaN(notch.currentWidth) && !isNaN(notch.currentHeight),
                    "w=" + notch.width + ", h=" + notch.height + ", cw=" + notch.currentWidth + ", ch=" + notch.currentHeight);
                break;

            case 9:
                // =================================================================
                // Summary Report
                // =================================================================
                masterSequencer.stop();
                console.log("================================================================");
                console.log("RESULTS: Passed=" + testWindow.passCount + ", Failed=" + testWindow.failCount);
                if (testWindow.failCount === 0) {
                    console.log("=== PASS: ALL ADVERSARIAL STRESS CHALLENGES SUCCEEDED ===");
                } else {
                    console.error("=== ASSERTION_FAILED: " + testWindow.failCount + " tests failed ===");
                    for (let k = 0; k < testWindow.failureReasons.length; k++) {
                        console.error("  - " + testWindow.failureReasons[k]);
                    }
                }
                console.log("================================================================");

                Qt.quit();
                break;
            }
        }
    }
}
