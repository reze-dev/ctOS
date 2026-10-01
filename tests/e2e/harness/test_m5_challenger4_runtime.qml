pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import desktop.core
import desktop.services
import desktop.surfaces
import desktop.surfaces.components

Scope {
    id: harnessRoot

    property int passCount: 0
    property int failCount: 0
    property var failureList: []

    function record(checkId, desc, condition, details) {
        if (condition) {
            passCount++;
            console.log("[PASS] " + checkId + ": " + desc + (details ? " (" + details + ")" : ""));
        } else {
            failCount++;
            failureList.push(checkId + ": " + desc + (details ? " (" + details + ")" : ""));
            console.error("[FAIL] " + checkId + ": " + desc + (details ? " (" + details + ")" : ""));
        }
    }

    // =========================================================================
    // Surfaces & Host Windows Under Test
    // =========================================================================
    readonly property var mockScreen1: ({ name: "eDP-1", model: "Internal Display" })
    readonly property var mockScreen2: ({ name: "DP-1", model: "External 4K Monitor" })

    // Primary Top Bar Host
    AmbientBar {
        id: testBar
        screen: harnessRoot.mockScreen1
    }

    // Secondary Monitor Floating Window with LivingNotch (simulating multi-monitor bar delegate)
    FloatingWindow {
        id: monitor2Window
        visible: false
        width: 1024
        height: 60

        LivingNotch {
            id: notchScreen2
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            monitorName: "DP-1"
        }
    }

    // Floating Window hosting CommandCenter for overlay & session tests
    FloatingWindow {
        id: ccWindow
        visible: false
        width: 400
        height: 700

        CommandCenter {
            id: cmdCenter
            anchors.fill: parent
        }
    }

    // Reference to livingNotch inside testBar
    readonly property var livingNotchItem: {
        if (!testBar || !testBar.contentItem) return null;
        for (let i = 0; i < testBar.contentItem.children.length; i++) {
            const child = testBar.contentItem.children[i];
            if (child && child.hasOwnProperty("compactWidth") && child.hasOwnProperty("hoverWidth")) {
                return child;
            }
        }
        return null;
    }

    // Tracking Session Signals
    property string lastSessionTriggered: ""
    property string lastSessionFinished: ""
    property int lastSessionExitCode: -1
    property int sessionTriggerCount: 0
    property int sessionFinishCount: 0

    Connections {
        target: SessionService
        function onSessionActionTriggered(action: string): void {
            harnessRoot.lastSessionTriggered = action;
            harnessRoot.sessionTriggerCount++;
        }
        function onSessionActionFinished(action: string, exitCode: int): void {
            harnessRoot.lastSessionFinished = action;
            harnessRoot.lastSessionExitCode = exitCode;
            harnessRoot.sessionFinishCount++;
        }
    }

    // Step Sequencer
    property int currentStep: 0
    property int maskFlushCount: 0
    property int savedFlushCount: 0

    Connections {
        target: testBar
        function onToggleMaskChanged(): void {
            harnessRoot.maskFlushCount++;
        }
    }

    Timer {
        id: stepTimer
        interval: 20
        running: true
        repeat: false
        onTriggered: runStep()
    }

    function schedule(delayMs, nextStep) {
        currentStep = nextStep;
        stepTimer.interval = delayMs;
        stepTimer.restart();
    }

    function runStep() {
        const notch = livingNotchItem;

        switch (currentStep) {
        case 0:
            console.log("================================================================");
            console.log("=== EMPIRICAL CHALLENGER 4: FULL LIFECYCLE & CONCURRENCY HARNESS");
            console.log("================================================================");

            // -----------------------------------------------------------------
            // PHASE 1: Session Actions & Dry-Run Stress Verification
            // -----------------------------------------------------------------
            record("CHAL4.SESS.01", "SessionService detects CTOS_SESSION_DRY_RUN",
                SessionService.dryRun === true,
                "dryRun=" + SessionService.dryRun);

            record("CHAL4.SESS.02", "SessionService is initially idle (isBusy=false)",
                SessionService.isBusy === false && SessionService.isLocking === false &&
                SessionService.isLoggingOut === false && SessionService.isRebooting === false &&
                SessionService.isPoweringOff === false,
                "isBusy=" + SessionService.isBusy);

            // Test SessionService.lock() in dry-run
            harnessRoot.lastSessionTriggered = "";
            harnessRoot.lastSessionFinished = "";
            harnessRoot.lastSessionExitCode = -1;
            SessionService.lock();

            record("CHAL4.SESS.03", "SessionService.lock() emitted triggered & finished in dry-run",
                harnessRoot.lastSessionTriggered === "lock" && harnessRoot.lastSessionFinished === "lock" && harnessRoot.lastSessionExitCode === 0,
                "triggered=" + harnessRoot.lastSessionTriggered + ", finished=" + harnessRoot.lastSessionFinished + ", exitCode=" + harnessRoot.lastSessionExitCode);

            record("CHAL4.SESS.04", "SessionService is not busy after dry-run lock",
                SessionService.isBusy === false && SessionService.isLocking === false,
                "isBusy=" + SessionService.isBusy);

            // Test SessionService.logout() in dry-run
            harnessRoot.lastSessionTriggered = "";
            harnessRoot.lastSessionFinished = "";
            harnessRoot.lastSessionExitCode = -1;
            SessionService.logout();

            record("CHAL4.SESS.05", "SessionService.logout() emitted triggered & finished in dry-run",
                harnessRoot.lastSessionTriggered === "logout" && harnessRoot.lastSessionFinished === "logout" && harnessRoot.lastSessionExitCode === 0,
                "triggered=" + harnessRoot.lastSessionTriggered + ", finished=" + harnessRoot.lastSessionFinished);

            record("CHAL4.SESS.06", "SessionService is not busy after dry-run logout",
                SessionService.isBusy === false && SessionService.isLoggingOut === false,
                "isBusy=" + SessionService.isBusy);

            // Test SessionService.reboot() in dry-run
            harnessRoot.lastSessionTriggered = "";
            harnessRoot.lastSessionFinished = "";
            harnessRoot.lastSessionExitCode = -1;
            SessionService.reboot();

            record("CHAL4.SESS.07", "SessionService.reboot() emitted triggered & finished in dry-run",
                harnessRoot.lastSessionTriggered === "reboot" && harnessRoot.lastSessionFinished === "reboot" && harnessRoot.lastSessionExitCode === 0,
                "triggered=" + harnessRoot.lastSessionTriggered + ", finished=" + harnessRoot.lastSessionFinished);

            record("CHAL4.SESS.08", "SessionService is not busy after dry-run reboot",
                SessionService.isBusy === false && SessionService.isRebooting === false,
                "isBusy=" + SessionService.isBusy);

            // Test SessionService.poweroff() in dry-run
            harnessRoot.lastSessionTriggered = "";
            harnessRoot.lastSessionFinished = "";
            harnessRoot.lastSessionExitCode = -1;
            SessionService.poweroff();

            record("CHAL4.SESS.09", "SessionService.poweroff() emitted triggered & finished in dry-run",
                harnessRoot.lastSessionTriggered === "poweroff" && harnessRoot.lastSessionFinished === "poweroff" && harnessRoot.lastSessionExitCode === 0,
                "triggered=" + harnessRoot.lastSessionTriggered + ", finished=" + harnessRoot.lastSessionFinished);

            record("CHAL4.SESS.10", "SessionService is not busy after dry-run poweroff",
                SessionService.isBusy === false && SessionService.isPoweringOff === false,
                "isBusy=" + SessionService.isBusy);

            // Test malicious payload injection
            var preTrig = harnessRoot.sessionTriggerCount;
            SessionService.executeAction("rm -rf /; poweroff");
            SessionService.executeAction("");
            SessionService.executeAction("suspend; reboot");
            record("CHAL4.SESS.11", "Malicious or unknown actions rejected without triggering",
                harnessRoot.sessionTriggerCount === preTrig,
                "triggerCount=" + harnessRoot.sessionTriggerCount);

            // Proceed to Step 1: CommandCenter confirmation prompt mechanics
            schedule(20, 1);
            break;

        case 1:
            // CommandCenter confirmation mechanics
            cmdCenter.triggerConfirmation("logout");
            record("CHAL4.SESS.12", "CommandCenter triggerConfirmation('logout') sets isConfirming",
                cmdCenter.isConfirming === true && cmdCenter.confirmationAction === "logout",
                "isConfirming=" + cmdCenter.isConfirming + ", action=" + cmdCenter.confirmationAction);

            cmdCenter.cancelConfirmation();
            record("CHAL4.SESS.13", "CommandCenter cancelConfirmation() cancels cleanly",
                cmdCenter.isConfirming === false && cmdCenter.confirmationAction === "",
                "isConfirming=" + cmdCenter.isConfirming + ", action=" + cmdCenter.confirmationAction);

            // Trigger reboot confirmation then execute
            harnessRoot.lastSessionTriggered = "";
            harnessRoot.lastSessionFinished = "";
            cmdCenter.triggerConfirmation("reboot");
            record("CHAL4.SESS.14", "CommandCenter confirmation pending for 'reboot'",
                cmdCenter.isConfirming === true && cmdCenter.confirmationAction === "reboot",
                "action=" + cmdCenter.confirmationAction);

            cmdCenter.executeConfirmation();
            record("CHAL4.SESS.15", "CommandCenter executeConfirmation() routes to dry-run reboot",
                harnessRoot.lastSessionTriggered === "reboot" && harnessRoot.lastSessionFinished === "reboot" &&
                cmdCenter.isConfirming === false && cmdCenter.confirmationAction === "",
                "triggered=" + harnessRoot.lastSessionTriggered + ", finished=" + harnessRoot.lastSessionFinished);

            // Trigger poweroff confirmation then execute
            harnessRoot.lastSessionTriggered = "";
            harnessRoot.lastSessionFinished = "";
            cmdCenter.triggerConfirmation("poweroff");
            cmdCenter.executeConfirmation();
            record("CHAL4.SESS.16", "CommandCenter executeConfirmation() routes to dry-run poweroff",
                harnessRoot.lastSessionTriggered === "poweroff" && harnessRoot.lastSessionFinished === "poweroff" &&
                cmdCenter.isConfirming === false && cmdCenter.confirmationAction === "",
                "triggered=" + harnessRoot.lastSessionTriggered + ", finished=" + harnessRoot.lastSessionFinished);

            // SystemRail routing via OverlayController
            OverlayController.openSystemRailWithAction("logout");
            record("CHAL4.SESS.17", "openSystemRailWithAction('logout') routes to CommandCenter confirmation",
                OverlayController.activeSurface === OverlayController.Surface.CommandCenter &&
                cmdCenter.isConfirming === true && cmdCenter.confirmationAction === "logout",
                "activeSurface=" + OverlayController.activeSurface + ", action=" + cmdCenter.confirmationAction);

            cmdCenter.cancelConfirmation();
            OverlayController.close();

            OverlayController.openSystemRailWithAction("reboot");
            record("CHAL4.SESS.18", "openSystemRailWithAction('reboot') routes to CommandCenter confirmation",
                OverlayController.activeSurface === OverlayController.Surface.CommandCenter &&
                cmdCenter.isConfirming === true && cmdCenter.confirmationAction === "reboot",
                "action=" + cmdCenter.confirmationAction);

            cmdCenter.cancelConfirmation();
            OverlayController.close();

            OverlayController.openSystemRailWithAction("poweroff");
            record("CHAL4.SESS.19", "openSystemRailWithAction('poweroff') routes to CommandCenter confirmation",
                OverlayController.activeSurface === OverlayController.Surface.CommandCenter &&
                cmdCenter.isConfirming === true && cmdCenter.confirmationAction === "poweroff",
                "action=" + cmdCenter.confirmationAction);

            cmdCenter.cancelConfirmation();
            OverlayController.close();

            // 50-cycle rapid dry-run session trigger stress
            for (var s = 0; s < 50; s++) {
                var acts = ["lock", "logout", "reboot", "poweroff"];
                var a = acts[s % 4];
                SessionService.executeAction(a);
            }
            record("CHAL4.SESS.20", "50-cycle rapid dry-run session stress maintains isBusy=false",
                SessionService.isBusy === false,
                "isBusy=" + SessionService.isBusy);

            schedule(30, 2);
            break;

        case 2:
            // -----------------------------------------------------------------
            // PHASE 2: Full Desktop Journey Lifecycle (Cold Boot to Clearance)
            // -----------------------------------------------------------------
            record("CHAL4.LIFE.01", "Journey Stage 1: LivingNotch discovered in AmbientBar",
                notch !== null,
                "notch=" + notch);

            record("CHAL4.LIFE.02", "Journey Stage 1: Cold boot compact notch dimensions",
                notch && notch.compactWidth >= 200 && notch.compactWidth <= 280 && notch.compactHeight === 30,
                "compactWidth=" + (notch ? notch.compactWidth : 0) + ", compactHeight=" + (notch ? notch.compactHeight : 0));

            record("CHAL4.LIFE.03", "Journey Stage 1: Initial state is compact",
                notch && notch.notchState === "compact",
                "notchState=" + (notch ? notch.notchState : ""));

            record("CHAL4.LIFE.04", "Journey Stage 1: Initial opacity is 1.0",
                notch && notch.opacity === 1.0,
                "opacity=" + (notch ? notch.opacity : 0));

            // Stage 2: Hover expansion
            if (notch) notch._isHovered = true;

            record("CHAL4.LIFE.05", "Journey Stage 2: Hover changes notchState to 'hover'",
                notch && notch.notchState === "hover",
                "notchState=" + (notch ? notch.notchState : ""));

            record("CHAL4.LIFE.06", "Journey Stage 2: Target dimensions reflect 2-row hover (380x60)",
                notch && notch.targetWidth === 380 && notch.targetHeight === 60,
                "targetWidth=" + (notch ? notch.targetWidth : 0) + ", targetHeight=" + (notch ? notch.targetHeight : 0));

            schedule(60, 3);
            break;

        case 3:
            // Stage 2 verify animation progress
            record("CHAL4.LIFE.07", "Journey Stage 2: Animated width expanded past compact width",
                notch && notch.currentWidth > notch.compactWidth,
                "currentWidth=" + (notch ? notch.currentWidth : 0));

            record("CHAL4.LIFE.08", "Journey Stage 2: Animated height expanded past compact height",
                notch && notch.currentHeight > notch.compactHeight,
                "currentHeight=" + (notch ? notch.currentHeight : 0));

            // Stage 3: Audio volume adjustment during hover
            var initialVol = AudioService.volume;
            AudioService.stepVolume(0.05);
            var volAfterStep = AudioService.volume;
            record("CHAL4.LIFE.09", "Journey Stage 3: stepVolume(0.05) steps volume upwards within [0,1]",
                volAfterStep >= initialVol && volAfterStep <= 1.0,
                "initialVol=" + initialVol + ", afterStep=" + volAfterStep);

            AudioService.stepVolume(-0.05);
            var volAfterDown = AudioService.volume;
            record("CHAL4.LIFE.10", "Journey Stage 3: stepVolume(-0.05) steps volume downwards within [0,1]",
                volAfterDown <= volAfterStep && volAfterDown >= 0.0,
                "afterDown=" + volAfterDown);

            // Stage 4: Calendar morph
            if (notch) {
                notch._isHovered = false;
                notch.calendarOpen = true;
            }

            record("CHAL4.LIFE.11", "Journey Stage 4: calendarOpen triggers 'calendar' notchState",
                notch && notch.notchState === "calendar",
                "notchState=" + (notch ? notch.notchState : ""));

            record("CHAL4.LIFE.12", "Journey Stage 4: Target dimensions reflect calendar (360x250)",
                notch && notch.targetWidth === 360 && notch.targetHeight === 250,
                "targetWidth=" + (notch ? notch.targetWidth : 0) + ", targetHeight=" + (notch ? notch.targetHeight : 0));

            schedule(60, 4);
            break;

        case 4:
            record("CHAL4.LIFE.13", "Journey Stage 4: Notch animated height grows downwards into calendar",
                notch && notch.currentHeight > notch.compactHeight,
                "currentHeight=" + (notch ? notch.currentHeight : 0));

            // Stage 5: Overlay summon and opacity handoff
            OverlayController.openCommandCenter();

            record("CHAL4.LIFE.14", "Journey Stage 5: Opening CommandCenter dismisses calendar",
                notch && notch.calendarOpen === false && notch._isCalendarOpen === false,
                "calendarOpen=" + (notch ? notch.calendarOpen : false));

            record("CHAL4.LIFE.15", "Journey Stage 5: OverlayController activeSurface is CommandCenter",
                OverlayController.activeSurface === OverlayController.Surface.CommandCenter,
                "activeSurface=" + OverlayController.activeSurface);

            record("CHAL4.LIFE.16", "Journey Stage 5: isCommandCenterOpen reactively true",
                notch && notch.isCommandCenterOpen === true,
                "isCommandCenterOpen=" + (notch ? notch.isCommandCenterOpen : false));

            // Wait 250ms for opacity fade animation
            schedule(250, 5);
            break;

        case 5:
            record("CHAL4.LIFE.17", "Journey Stage 5: Notch opacity yields to 0.0 under CommandCenter",
                notch && notch.opacity < 0.05,
                "opacity=" + (notch ? notch.opacity : 1));

            // Stage 6: Close overlay, re-open calendar, then simulate outside backdrop click
            OverlayController.close();
            record("CHAL4.LIFE.18", "Journey Stage 6: OverlayController closed",
                OverlayController.activeSurface === OverlayController.Surface.None,
                "activeSurface=" + OverlayController.activeSurface);

            // Re-open calendar
            if (notch) notch.calendarOpen = true;
            record("CHAL4.LIFE.19", "Journey Stage 6: Calendar re-opened",
                notch && notch.calendarOpen === true,
                "calendarOpen=" + (notch ? notch.calendarOpen : false));

            // Simulate outside backdrop click via testBar.closeCalendar()
            testBar.closeCalendar();
            record("CHAL4.LIFE.20", "Journey Stage 6: testBar.closeCalendar() collapses LivingNotch calendar",
                notch && notch.calendarOpen === false && notch._isCalendarOpen === false,
                "calendarOpen=" + (notch ? notch.calendarOpen : true));

            // Stage 7: Fullscreen clearance contracts
            record("CHAL4.LIFE.21", "Journey Stage 7: AmbientBar exclusiveZone is strictly 0",
                testBar.exclusiveZone === 0,
                "exclusiveZone=" + testBar.exclusiveZone);

            record("CHAL4.LIFE.22", "Journey Stage 7: AmbientBar exclusionMode is ExclusionMode.Ignore",
                testBar.exclusionMode === ExclusionMode.Ignore,
                "exclusionMode=" + testBar.exclusionMode);

            schedule(40, 6);
            break;

        case 6:
            // -----------------------------------------------------------------
            // PHASE 3: Multi-Monitor & Concurrency Stress
            // -----------------------------------------------------------------
            // Screen 1 and Screen 2 independent monitor bounds
            record("CHAL4.CONC.01", "Multi-Monitor: Screen 1 LivingNotch initialized",
                notch && notch.monitorName === "eDP-1" && notch.notchState === "compact",
                "mon1=" + (notch ? notch.monitorName : "") + ", state=" + (notch ? notch.notchState : ""));

            record("CHAL4.CONC.02", "Multi-Monitor: Screen 2 LivingNotch initialized",
                notchScreen2.monitorName === "DP-1" && notchScreen2.notchState === "compact",
                "mon2=" + notchScreen2.monitorName + ", state=" + notchScreen2.notchState);

            // Rapid notification injection burst (20 notifications)
            var notifErrors = 0;
            for (var n = 0; n < 20; n++) {
                if (notch) notch.showNotification("App-" + n, "Notification burst payload " + n, n % 3);
                notchScreen2.showNotification("App-" + n, "Notification burst payload " + n, n % 3);

                if ((notch && notch.notchState !== "notification") || notchScreen2.notchState !== "notification") {
                    notifErrors++;
                }
            }

            record("CHAL4.CONC.03", "Concurrency: 20-burst notification injection handled across monitors",
                notifErrors === 0 && notchScreen2.isExpanded === true,
                "notifErrors=" + notifErrors + ", expanded2=" + notchScreen2.isExpanded);

            // Concurrently toggle overlays rapidly while notifications are active
            var concErrors = 0;
            for (var c = 0; c < 60; c++) {
                var pick = c % 4;
                if (pick === 0) {
                    OverlayController.openCommandDeck();
                } else if (pick === 1) {
                    OverlayController.openCommandCenter();
                } else if (pick === 2) {
                    OverlayController.openRadialSettings();
                } else {
                    OverlayController.close();
                }

                // Invariants:
                // 1. activeSurface must always be within valid range [0..4]
                if (OverlayController.activeSurface < 0 || OverlayController.activeSurface > 4) {
                    concErrors++;
                }
                // 2. Mutual exclusivity: if CommandCenter is open, isCommandCenterOpen must match
                var expectedCc = (OverlayController.activeSurface === OverlayController.Surface.CommandCenter);
                if (notch && notch.isCommandCenterOpen !== expectedCc) {
                    concErrors++;
                }
                if (notchScreen2.isCommandCenterOpen !== expectedCc) {
                    concErrors++;
                }
            }

            record("CHAL4.CONC.04", "Concurrency: 60-iteration rapid overlay chatter maintains exclusivity",
                concErrors === 0,
                "concErrors=" + concErrors);

            // Reset and settle
            OverlayController.close();
            if (notch) {
                notch._notificationActive = false;
                notch.isExpanded = false;
            }
            notchScreen2._notificationActive = false;
            notchScreen2.isExpanded = false;

            schedule(100, 7);
            break;

        case 7:
            // Settle state verification
            record("CHAL4.CONC.05", "Concurrency Settle: activeSurface returned to None",
                OverlayController.activeSurface === OverlayController.Surface.None,
                "activeSurface=" + OverlayController.activeSurface);

            record("CHAL4.CONC.06", "Concurrency Settle: Both monitors settled back to compact",
                notch && notch.notchState === "compact" && notchScreen2.notchState === "compact",
                "state1=" + (notch ? notch.notchState : "") + ", state2=" + notchScreen2.notchState);

            // -----------------------------------------------------------------
            // PHASE 4: Double-Buffered Wayland Input Mask Bounding
            // -----------------------------------------------------------------
            record("CHAL4.MASK.01", "Wayland Mask: testBar.mask is instantiated",
                testBar.mask !== null && testBar.mask !== undefined,
                "mask=" + testBar.mask);

            var preToggle = testBar.toggleMask;
            testBar.flushWaylandMask();
            var postToggle = testBar.toggleMask;

            record("CHAL4.MASK.02", "Wayland Mask: flushWaylandMask() double-buffering flips toggleMask",
                preToggle !== postToggle,
                "preToggle=" + preToggle + ", postToggle=" + postToggle);

            // Verify mask component objects maskA and maskB exist
            record("CHAL4.MASK.03", "Wayland Mask: maskA and maskB objects exist on AmbientBar",
                testBar.maskA !== null && testBar.maskB !== null,
                "maskA=" + testBar.maskA + ", maskB=" + testBar.maskB);

            record("CHAL4.MASK.04", "Wayland Mask: maskA and maskB are distinct references",
                testBar.maskA !== testBar.maskB,
                "distinct=" + (testBar.maskA !== testBar.maskB));

            // Under compact state: verify notch compact width is bounded
            record("CHAL4.MASK.05", "Wayland Mask: LivingNotch compact width is 220px (bounded within screen)",
                notch && notch.compactWidth === 220,
                "notchCompactWidth=" + (notch ? notch.compactWidth : 0));

            // Test flush counter on dimension change
            harnessRoot.savedFlushCount = harnessRoot.maskFlushCount;
            if (notch) notch._isHovered = true;
            schedule(60, 8);
            break;

        case 8:
            var postFlush = harnessRoot.maskFlushCount;
            record("CHAL4.MASK.06", "Wayland Mask: Dimension change triggers flushWaylandMask toggles",
                postFlush > harnessRoot.savedFlushCount,
                "flushes=" + (postFlush - harnessRoot.savedFlushCount));

            // Return to compact
            if (notch) notch._isHovered = false;

            console.log("================================================================");
            console.log("=== HARNESS RESULTS: Passed=" + passCount + ", Failed=" + failCount);
            if (failCount === 0) {
                console.log("=== PASS: M5 CHALLENGER 4 EMPIRICAL HARNESS SUCCESSFUL ===");
            } else {
                console.error("=== FAIL: M5 CHALLENGER 4 EMPIRICAL HARNESS ENCOUNTERED FAILURES ===");
            }
            console.log("================================================================");

            Qt.quit();
            break;
        }
    }
}
