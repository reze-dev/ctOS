pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import desktop.core
import desktop.services
import desktop.surfaces
import desktop.surfaces.components

FloatingWindow {
    id: testWindow
    visible: true
    implicitWidth: 960
    implicitHeight: 720

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

    // =========================================================================
    // Components Under Test
    // =========================================================================
    Item {
        id: container
        anchors.fill: parent

        LivingNotch {
            id: livingNotch
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: 4
            monitorName: "test-screen"
        }

        AmbientBar {
            id: ambientBar
            visible: false
            width: 800
        }

        CommandCenter {
            id: commandCenter
            visible: false
            anchors.centerIn: parent
        }
    }

    // Tracking session service signals
    property string lastSessionTriggered: ""
    property string lastSessionFinished: ""
    property int lastSessionExitCode: -1

    Connections {
        target: SessionService
        function onSessionActionTriggered(action: string): void {
            testWindow.lastSessionTriggered = action;
        }
        function onSessionActionFinished(action: string, exitCode: int): void {
            testWindow.lastSessionFinished = action;
            testWindow.lastSessionExitCode = exitCode;
        }
    }

    // Step Sequencer
    property int currentStep: 0

    Timer {
        id: stepTimer
        interval: 20
        running: true
        repeat: false
        onTriggered: runStep()
    }

    function schedule(delayMs, stepNum) {
        currentStep = stepNum;
        stepTimer.interval = delayMs;
        stepTimer.restart();
    }

    function runStep() {
        switch (currentStep) {
        case 0:
            console.log("================================================================");
            console.log("=== CHALLENGER 2: EMPIRICAL ADVERSARIAL STRESS HARNESS =========");
            console.log("================================================================");

            // Phase 1: Baseline Architecture & Initial Invariants
            assertCondition("CHAL2.BASE.01", "LivingNotch initial compact pill dimensions",
                livingNotch.compactWidth >= 200 && livingNotch.compactWidth <= 280 && livingNotch.compactHeight === 30,
                "compactWidth=" + livingNotch.compactWidth + ", compactHeight=" + livingNotch.compactHeight);

            assertCondition("CHAL2.BASE.02", "LivingNotch initial state is compact or media",
                livingNotch.notchState === "compact" || livingNotch.notchState === "media",
                "notchState=" + livingNotch.notchState);

            assertCondition("CHAL2.BASE.03", "LivingNotch initial opacity is 1.0",
                livingNotch.opacity === 1.0,
                "opacity=" + livingNotch.opacity);

            assertCondition("CHAL2.BASE.04", "Calendar is initially closed",
                livingNotch.calendarOpen === false && livingNotch._isCalendarOpen === false,
                "calendarOpen=" + livingNotch.calendarOpen);

            assertCondition("CHAL2.BASE.05", "OverlayController initial surface is None",
                OverlayController.activeSurface === OverlayController.Surface.None,
                "activeSurface=" + OverlayController.activeSurface);

            // Schedule Phase 2: Downward Calendar Morph
            schedule(30, 1);
            break;

        case 1:
            // Phase 2: Morphing Calendar Downward Expansion
            livingNotch.toggleCalendar();

            assertCondition("CHAL2.CAL.01", "toggleCalendar opens calendar",
                livingNotch.calendarOpen === true && livingNotch._isCalendarOpen === true,
                "calendarOpen=" + livingNotch.calendarOpen);

            assertCondition("CHAL2.CAL.02", "notchState switches to calendar",
                livingNotch.notchState === "calendar",
                "notchState=" + livingNotch.notchState);

            assertCondition("CHAL2.CAL.03", "Target dimensions reflect calendar specification (360x250)",
                livingNotch.targetWidth === 360 && livingNotch.targetHeight === 250,
                "targetWidth=" + livingNotch.targetWidth + ", targetHeight=" + livingNotch.targetHeight);

            // Wait a tick for spring animation to commence
            schedule(50, 2);
            break;

        case 2:
            assertCondition("CHAL2.CAL.04", "Height animates downwards past compact height",
                livingNotch.currentHeight > livingNotch.compactHeight,
                "currentHeight=" + livingNotch.currentHeight);

            // Phase 3: Calendar Dismissal on CommandDeck summon
            OverlayController.openCommandDeck();

            assertCondition("CHAL2.DISMISS.01", "Opening CommandDeck dismisses calendarOpen",
                livingNotch.calendarOpen === false && livingNotch._isCalendarOpen === false,
                "calendarOpen=" + livingNotch.calendarOpen);

            assertCondition("CHAL2.DISMISS.02", "notchState drops out of calendar upon CommandDeck summon",
                livingNotch.notchState !== "calendar",
                "notchState=" + livingNotch.notchState);

            assertCondition("CHAL2.DISMISS.03", "OverlayController activeSurface is CommandDeck",
                OverlayController.activeSurface === OverlayController.Surface.CommandDeck,
                "activeSurface=" + OverlayController.activeSurface);

            // Opacity should remain 1.0 because CommandDeck is not CommandCenter
            assertCondition("CHAL2.DISMISS.04", "Notch opacity remains 1.0 when CommandDeck is open",
                livingNotch.opacity === 1.0,
                "opacity=" + livingNotch.opacity);

            OverlayController.close();
            schedule(50, 3);
            break;

        case 3:
            // Phase 4: Calendar Dismissal on RadialSettings summon
            livingNotch.toggleCalendar();
            assertCondition("CHAL2.RADIAL.01", "Calendar re-opened",
                livingNotch.calendarOpen === true,
                "calendarOpen=" + livingNotch.calendarOpen);

            OverlayController.openRadialSettings();

            assertCondition("CHAL2.RADIAL.02", "Opening RadialSettings dismisses calendar",
                livingNotch.calendarOpen === false && livingNotch._isCalendarOpen === false,
                "calendarOpen=" + livingNotch.calendarOpen);

            assertCondition("CHAL2.RADIAL.03", "OverlayController activeSurface is RadialSettings",
                OverlayController.activeSurface === OverlayController.Surface.RadialSettings,
                "activeSurface=" + OverlayController.activeSurface);

            OverlayController.close();
            schedule(50, 4);
            break;

        case 4:
            // Phase 5: Opacity Handoff & Calendar Dismissal on CommandCenter Summon
            livingNotch.toggleCalendar();
            assertCondition("CHAL2.CMDCTR.01", "Calendar opened prior to CommandCenter summon",
                livingNotch.calendarOpen === true,
                "calendarOpen=" + livingNotch.calendarOpen);

            OverlayController.openCommandCenter();

            assertCondition("CHAL2.CMDCTR.02", "OverlayController activeSurface is CommandCenter",
                OverlayController.activeSurface === OverlayController.Surface.CommandCenter,
                "activeSurface=" + OverlayController.activeSurface);

            assertCondition("CHAL2.CMDCTR.03", "isCommandCenterOpen reactively becomes true",
                livingNotch.isCommandCenterOpen === true,
                "isCommandCenterOpen=" + livingNotch.isCommandCenterOpen);

            assertCondition("CHAL2.CMDCTR.04", "Opening CommandCenter immediately dismisses calendar",
                livingNotch.calendarOpen === false,
                "calendarOpen=" + livingNotch.calendarOpen);

            // Wait 300ms for opacity to fade to 0.0
            schedule(300, 5);
            break;

        case 5:
            assertCondition("CHAL2.OPAC.01", "Notch opacity faded to 0.0 under active CommandCenter",
                livingNotch.opacity < 0.05,
                "opacity=" + livingNotch.opacity);

            // Direct Surface Preemption: Switch directly from CommandCenter to CommandDeck
            OverlayController.openCommandDeck();

            assertCondition("CHAL2.PREEMPT.01", "activeSurface transitioned directly to CommandDeck",
                OverlayController.activeSurface === OverlayController.Surface.CommandDeck,
                "activeSurface=" + OverlayController.activeSurface);

            assertCondition("CHAL2.PREEMPT.02", "isCommandCenterOpen immediately dropped to false",
                livingNotch.isCommandCenterOpen === false,
                "isCommandCenterOpen=" + livingNotch.isCommandCenterOpen);

            // Wait 300ms for opacity to restore back to 1.0
            schedule(300, 6);
            break;

        case 6:
            assertCondition("CHAL2.OPAC.02", "Opacity restored to 1.0 when CommandDeck preempted CommandCenter",
                livingNotch.opacity > 0.95,
                "opacity=" + livingNotch.opacity);

            OverlayController.close();
            schedule(50, 7);
            break;

        case 7:
            // Phase 6: Session Lifecycle & Confirmation Integration
            // Test openSystemRailWithAction
            OverlayController.openSystemRailWithAction("reboot");

            assertCondition("CHAL2.SESS.01", "openSystemRailWithAction routes to CommandCenter",
                OverlayController.activeSurface === OverlayController.Surface.CommandCenter,
                "activeSurface=" + OverlayController.activeSurface);

            assertCondition("CHAL2.SESS.02", "Notch isCommandCenterOpen is true during session confirmation",
                livingNotch.isCommandCenterOpen === true,
                "isCommandCenterOpen=" + livingNotch.isCommandCenterOpen);

            // CommandCenter should have set confirmationAction to "reboot"
            assertCondition("CHAL2.SESS.03", "CommandCenter confirmationAction received 'reboot'",
                commandCenter.confirmationAction === "reboot",
                "confirmationAction=" + commandCenter.confirmationAction);

            assertCondition("CHAL2.SESS.04", "CommandCenter isConfirming is true",
                commandCenter.isConfirming === true,
                "isConfirming=" + commandCenter.isConfirming);

            // Cancel confirmation
            commandCenter.cancelConfirmation();
            assertCondition("CHAL2.SESS.05", "cancelConfirmation resets confirmationAction",
                commandCenter.confirmationAction === "" && commandCenter.isConfirming === false,
                "confirmationAction=" + commandCenter.confirmationAction);

            OverlayController.close();
            schedule(50, 8);
            break;

        case 8:
            // Test SessionService dry-run execution
            testWindow.lastSessionTriggered = "";
            testWindow.lastSessionFinished = "";
            testWindow.lastSessionExitCode = -1;

            SessionService.lock();

            assertCondition("CHAL2.SESS.06", "SessionService.lock() emitted sessionActionTriggered('lock')",
                testWindow.lastSessionTriggered === "lock",
                "lastSessionTriggered=" + testWindow.lastSessionTriggered);

            assertCondition("CHAL2.SESS.07", "SessionService.lock() emitted sessionActionFinished in dry-run",
                testWindow.lastSessionFinished === "lock" && testWindow.lastSessionExitCode === 0,
                "lastSessionFinished=" + testWindow.lastSessionFinished + ", exitCode=" + testWindow.lastSessionExitCode);

            // Test SessionService reboot trigger
            testWindow.lastSessionTriggered = "";
            testWindow.lastSessionFinished = "";
            testWindow.lastSessionExitCode = -1;

            SessionService.reboot();

            assertCondition("CHAL2.SESS.08", "SessionService.reboot() emitted sessionActionTriggered('reboot')",
                testWindow.lastSessionTriggered === "reboot",
                "lastSessionTriggered=" + testWindow.lastSessionTriggered);

            assertCondition("CHAL2.SESS.09", "SessionService.reboot() emitted sessionActionFinished in dry-run",
                testWindow.lastSessionFinished === "reboot" && testWindow.lastSessionExitCode === 0,
                "lastSessionFinished=" + testWindow.lastSessionFinished + ", exitCode=" + testWindow.lastSessionExitCode);

            schedule(50, 9);
            break;

        case 9:
            // Phase 7: Full-Screen Window Clearance & Wayland Input Mask Contracts
            assertCondition("CHAL2.CLEAR.01", "AmbientBar exclusiveZone is strictly 0 (floating overlay)",
                ambientBar.exclusiveZone === 0,
                "exclusiveZone=" + ambientBar.exclusiveZone);

            assertCondition("CHAL2.CLEAR.02", "AmbientBar exclusionMode is ExclusionMode.Ignore",
                ambientBar.exclusionMode === ExclusionMode.Ignore,
                "exclusionMode=" + ambientBar.exclusionMode);

            assertCondition("CHAL2.CLEAR.03", "AmbientBar provides closeCalendar() dispatch method",
                typeof ambientBar.closeCalendar === "function",
                "closeCalendar exists");

            var initialToggle = ambientBar.toggleMask;
            ambientBar.flushWaylandMask();
            var toggled = ambientBar.toggleMask;

            assertCondition("CHAL2.CLEAR.04", "flushWaylandMask double-buffering flips toggleMask",
                initialToggle !== toggled,
                "initialToggle=" + initialToggle + ", toggled=" + toggled);

            schedule(50, 10);
            break;

        case 10:
            // Phase 8: Adversarial Rapid Interleaved Jitter & Fuzzing (100 rapid cycles)
            var jitterErrors = 0;
            for (var i = 0; i < 100; i++) {
                var actionType = i % 5;
                if (actionType === 0) {
                    livingNotch.toggleCalendar();
                } else if (actionType === 1) {
                    OverlayController.openCommandCenter();
                } else if (actionType === 2) {
                    OverlayController.openCommandDeck();
                } else if (actionType === 3) {
                    OverlayController.openRadialSettings();
                } else {
                    OverlayController.close();
                }

                // Invariant checks during rapid chatter:
                // 1. Overlay surface must always be in [0..4]
                if (OverlayController.activeSurface < 0 || OverlayController.activeSurface > 4) {
                    jitterErrors++;
                }

                // 2. Mutual exclusivity: When CommandCenter is open, calendar MUST NOT be open
                if (OverlayController.activeSurface === OverlayController.Surface.CommandCenter && livingNotch.calendarOpen) {
                    jitterErrors++;
                }

                // 3. When CommandDeck is open, isCommandCenterOpen MUST be false
                if (OverlayController.activeSurface === OverlayController.Surface.CommandDeck && livingNotch.isCommandCenterOpen) {
                    jitterErrors++;
                }
            }

            assertCondition("CHAL2.STRESS.01", "100-cycle interleaved jitter maintains exclusivity invariants",
                jitterErrors === 0,
                "jitterErrors=" + jitterErrors);

            // Reset and settle
            OverlayController.close();
            livingNotch.closeCalendar();
            schedule(350, 11);
            break;

        case 11:
            // Phase 9: Settle State Invariant Audit
            assertCondition("CHAL2.SETTLE.01", "Settled activeSurface is None",
                OverlayController.activeSurface === OverlayController.Surface.None,
                "activeSurface=" + OverlayController.activeSurface);

            assertCondition("CHAL2.SETTLE.02", "Settled calendarOpen is false",
                livingNotch.calendarOpen === false && livingNotch._isCalendarOpen === false,
                "calendarOpen=" + livingNotch.calendarOpen);

            assertCondition("CHAL2.SETTLE.03", "Settled isCommandCenterOpen is false",
                livingNotch.isCommandCenterOpen === false,
                "isCommandCenterOpen=" + livingNotch.isCommandCenterOpen);

            assertCondition("CHAL2.SETTLE.04", "Settled opacity is 1.0",
                livingNotch.opacity === 1.0,
                "opacity=" + livingNotch.opacity);

            assertCondition("CHAL2.SETTLE.05", "Settled notchState returns to compact or media",
                livingNotch.notchState === "compact" || livingNotch.notchState === "media",
                "notchState=" + livingNotch.notchState);

            // Final wrap-up
            console.log("================================================================");
            console.log("CHALLENGER 2 RESULTS: Passed=" + passCount + ", Failed=" + failCount);
            if (failCount === 0) {
                console.log("=== PASS: CHALLENGER 2 EMPIRICAL HARNESS SUCCESSFUL ===");
            } else {
                console.error("=== ASSERTION_FAILED: " + failCount + " tests failed ===");
            }
            console.log("================================================================");

            Qt.quit();
            break;
        }
    }
}
