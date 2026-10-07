pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import desktop.core
import desktop.surfaces
import desktop.surfaces.components

FloatingWindow {
    id: testWindow
    visible: true
    implicitWidth: 900
    implicitHeight: 700

    property var results: []
    property int passCount: 0
    property int failCount: 0

    function assertCondition(id, name, condition, details) {
        if (condition) {
            passCount++;
            console.log("[PASS] " + id + ": " + name + " (" + details + ")");
            results.push({ id: id, name: name, passed: true, details: details });
        } else {
            failCount++;
            console.error("[FAIL] " + id + ": " + name + " (" + details + ")");
            results.push({ id: id, name: name, passed: false, details: details });
        }
    }

    Item {
        id: testContainer
        anchors.fill: parent

        LivingNotch {
            id: notch
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: 10
            monitorName: "test-screen"
        }

        AmbientBar {
            id: bar
            visible: false
            implicitWidth: 800
        }
    }

    property int currentStep: 0

    Timer {
        id: stepTimer
        interval: 30
        running: true
        repeat: false
        onTriggered: runNextStep()
    }

    function schedule(delayMs, stepNum) {
        currentStep = stepNum;
        stepTimer.interval = delayMs;
        stepTimer.restart();
    }

    function runNextStep() {
        switch (currentStep) {
        case 0:
            console.log("================================================================");
            console.log("=== EMPIRICAL CHALLENGER: M4 RACE CONDITION & EXCLUSIVITY ======");
            console.log("================================================================");

            // Phase 1: Baseline State Integrity
            assertCondition("CHAL.M4.BASE.01", "LivingNotch initial state is compact or media",
                notch.notchState === "compact" || notch.notchState === "media",
                "notchState=" + notch.notchState);

            assertCondition("CHAL.M4.BASE.02", "LivingNotch initial opacity is 1.0",
                notch.opacity === 1.0,
                "opacity=" + notch.opacity);

            assertCondition("CHAL.M4.BASE.03", "OverlayController initial activeSurface is None",
                OverlayController.activeSurface === OverlayController.Surface.None,
                "activeSurface=" + OverlayController.activeSurface);

            assertCondition("CHAL.M4.BASE.04", "Calendar is initially closed",
                notch.calendarOpen === false && notch._isCalendarOpen === false,
                "calendarOpen=" + notch.calendarOpen);

            // Schedule Phase 2: Open Calendar
            schedule(20, 1);
            break;

        case 1:
            // Phase 2: Open Calendar
            notch.toggleCalendar();
            assertCondition("CHAL.M4.CAL.01", "toggleCalendar sets calendarOpen to true",
                notch.calendarOpen === true && notch._isCalendarOpen === true,
                "calendarOpen=" + notch.calendarOpen);

            assertCondition("CHAL.M4.CAL.02", "notchState switches to calendar",
                notch.notchState === "calendar",
                "notchState=" + notch.notchState);

            // Wait a brief tick to allow geometry animation to start
            schedule(40, 2);
            break;

        case 2:
            // Mid-animation check: height should be growing towards 250
            assertCondition("CHAL.M4.CAL.03", "Height animates upwards during calendar state",
                notch.currentHeight >= notch.compactHeight,
                "currentHeight=" + notch.currentHeight);

            // Phase 3: Open CommandCenter while Calendar is open
            OverlayController.openCommandCenter();

            assertCondition("CHAL.M4.OVR.01", "OverlayController activeSurface is CommandCenter",
                OverlayController.activeSurface === OverlayController.Surface.CommandCenter,
                "activeSurface=" + OverlayController.activeSurface);

            assertCondition("CHAL.M4.OVR.02", "isCommandCenterOpen reactively becomes true",
                notch.isCommandCenterOpen === true,
                "isCommandCenterOpen=" + notch.isCommandCenterOpen);

            assertCondition("CHAL.M4.OVR.03", "Opening CommandCenter immediately dismisses calendarOpen",
                notch.calendarOpen === false && notch._isCalendarOpen === false,
                "calendarOpen=" + notch.calendarOpen);

            assertCondition("CHAL.M4.OVR.04", "notchState drops out of calendar immediately",
                notch.notchState !== "calendar",
                "notchState=" + notch.notchState);

            // Schedule Phase 4: Wait for opacity animation to complete (durationSlow = 250ms)
            schedule(300, 3);
            break;

        case 3:
            // Phase 4: Verify opacity reached 0.0
            assertCondition("CHAL.M4.OPAC.01", "Opacity reaches 0.0 after CommandCenter open animation",
                notch.opacity < 0.05,
                "opacity=" + notch.opacity);

            // Race Condition Test: Trigger toggleCalendar() while CommandCenter is open
            notch.toggleCalendar();

            // When toggleCalendar is called while CommandCenter is open, LivingNotch closes CommandCenter
            assertCondition("CHAL.M4.RACE.01", "toggleCalendar while CommandCenter open closes CommandCenter",
                OverlayController.activeSurface === OverlayController.Surface.None,
                "activeSurface=" + OverlayController.activeSurface);

            assertCondition("CHAL.M4.RACE.02", "isCommandCenterOpen returns to false",
                notch.isCommandCenterOpen === false,
                "isCommandCenterOpen=" + notch.isCommandCenterOpen);

            assertCondition("CHAL.M4.RACE.03", "Calendar successfully opened",
                notch.calendarOpen === true && notch.notchState === "calendar",
                "calendarOpen=" + notch.calendarOpen + ", state=" + notch.notchState);

            // Wait 300ms for opacity to restore back towards 1.0
            schedule(300, 4);
            break;

        case 4:
            assertCondition("CHAL.M4.OPAC.02", "Opacity restored back to 1.0 after CommandCenter close",
                notch.opacity > 0.95,
                "opacity=" + notch.opacity);

            // Phase 5: Preemption by CommandDeck while CommandCenter is open
            OverlayController.openCommandCenter();
            schedule(50, 5);
            break;

        case 5:
            // Mid-animation preemption: Open CommandDeck immediately while CommandCenter was active
            OverlayController.openCommandDeck();

            assertCondition("CHAL.M4.PREEMPT.01", "Overlay exclusivity: activeSurface switches to CommandDeck",
                OverlayController.activeSurface === OverlayController.Surface.CommandDeck,
                "activeSurface=" + OverlayController.activeSurface);

            assertCondition("CHAL.M4.PREEMPT.02", "isCommandCenterOpen drops to false",
                notch.isCommandCenterOpen === false,
                "isCommandCenterOpen=" + notch.isCommandCenterOpen);

            // Wait 300ms to verify opacity does NOT stay at 0.0
            schedule(300, 6);
            break;

        case 6:
            assertCondition("CHAL.M4.PREEMPT.03", "Opacity returns to 1.0 when CommandDeck preempts CommandCenter",
                notch.opacity > 0.95,
                "opacity=" + notch.opacity);

            // Close CommandDeck
            OverlayController.close();
            assertCondition("CHAL.M4.CLOSE.01", "OverlayController close sets activeSurface to None",
                OverlayController.activeSurface === OverlayController.Surface.None,
                "activeSurface=" + OverlayController.activeSurface);

            // Phase 6: Rapid Jitter / Chatter Stress
            // Perform 60 rapid switches between overlays and calendar
            var errorCount = 0;
            for (var i = 0; i < 60; i++) {
                if (i % 4 === 0) {
                    OverlayController.openCommandCenter();
                } else if (i % 4 === 1) {
                    OverlayController.openCommandDeck();
                } else if (i % 4 === 2) {
                    notch.toggleCalendar();
                } else {
                    OverlayController.close();
                }

                // Verify mutual exclusivity invariant during every iteration
                if (OverlayController.activeSurface < 0 || OverlayController.activeSurface > 4) {
                    errorCount++;
                }
                if (OverlayController.activeSurface === OverlayController.Surface.CommandCenter && notch.calendarOpen) {
                    errorCount++;
                }
            }

            assertCondition("CHAL.M4.STRESS.01", "60-cycle rapid jitter maintains overlay exclusivity invariants",
                errorCount === 0,
                "jitterErrors=" + errorCount);

            // Reset and settle
            OverlayController.close();
            notch.closeCalendar();
            schedule(350, 7);
            break;

        case 7:
            // Settle verification after stress
            assertCondition("CHAL.M4.SETTLE.01", "After stress, activeSurface is cleanly None",
                OverlayController.activeSurface === OverlayController.Surface.None,
                "activeSurface=" + OverlayController.activeSurface);

            assertCondition("CHAL.M4.SETTLE.02", "After stress, calendarOpen is false",
                notch.calendarOpen === false && notch._isCalendarOpen === false,
                "calendarOpen=" + notch.calendarOpen);

            assertCondition("CHAL.M4.SETTLE.03", "After stress, opacity settles at 1.0",
                notch.opacity === 1.0,
                "opacity=" + notch.opacity);

            // Phase 7: AmbientBar Bidirectional Wiring & Mask Verification
            assertCondition("CHAL.M4.BAR.01", "AmbientBar exposes closeCalendar() method",
                typeof bar.closeCalendar === "function",
                "closeCalendar exists on AmbientBar");

            bar.closeCalendar();
            assertCondition("CHAL.M4.BAR.02", "bar.closeCalendar() executes cleanly without exception",
                true,
                "bar.closeCalendar() invoked");

            // Phase 8: Escape Key & Outside-Click Scrim Contracts
            OverlayController.openCommandCenter();
            var handledEsc = OverlayController.handleEscape();
            assertCondition("CHAL.M4.ESC.01", "OverlayController handleEscape() dismisses active overlay",
                handledEsc === true && OverlayController.activeSurface === OverlayController.Surface.None,
                "activeSurface=" + OverlayController.activeSurface);

            OverlayController.openRadialSettings();
            var handledBackdrop = OverlayController.handleBackdropClick();
            assertCondition("CHAL.M4.BACKDROP.01", "OverlayController handleBackdropClick() dismisses active overlay",
                handledBackdrop === true && OverlayController.activeSurface === OverlayController.Surface.None,
                "activeSurface=" + OverlayController.activeSurface);

            // Final wrap-up
            console.log("================================================================");
            console.log("RESULTS: Passed=" + passCount + ", Failed=" + failCount);
            if (failCount === 0) {
                console.log("=== PASS: EMPIRICAL CHALLENGER VERIFICATION SUCCESSFUL ===");
            } else {
                console.error("=== ASSERTION_FAILED: " + failCount + " tests failed ===");
            }
            console.log("================================================================");

            Qt.quit();
            break;
        }
    }
}
