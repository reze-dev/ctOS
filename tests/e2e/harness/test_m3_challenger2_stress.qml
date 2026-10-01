pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import desktop.core
import desktop.services
import desktop.surfaces
import desktop.surfaces.components

Scope {
    id: root

    property int passCount: 0
    property int failCount: 0
    property var failureList: []

    function record(id, desc, cond, details) {
        if (cond) {
            passCount++;
            console.log("[PASS] " + id + ": " + desc + (details ? " (" + details + ")" : ""));
        } else {
            failCount++;
            failureList.push(id + ": " + desc + " (" + details + ")");
            console.error("[FAIL] " + id + ": " + desc + (details ? " (" + details + ")" : ""));
        }
    }

    AmbientBar {
        id: bar
        screen: Quickshell.screens[0] || null
    }

    readonly property var notch: (bar.contentItem && bar.contentItem.children.length > 0) ? bar.contentItem.children[0] : null

    property int maskFlushCount: 0
    Connections {
        target: bar
        function onToggleMaskChanged() {
            root.maskFlushCount++;
        }
    }

    Timer {
        id: phase1SyncTests
        interval: 50
        running: true
        repeat: false
        onTriggered: {
            console.log("================================================================");
            console.log("=== EMPIRICAL CHALLENGER 2: M3 STRESS & NOTCH LIFECYCLE HARNESS ==");
            console.log("================================================================");

            try {
                // -------------------------------------------------------------
                // SECTION 1: Baseline AmbientBar & Layer Shell Properties
                // -------------------------------------------------------------
                console.log(">>> SECTION 1: AmbientBar Layer Shell & Host Geometry");
                record("CHAL.M3.BAR.01", "AmbientBar instantiates cleanly", bar !== null, "bar=" + bar);
                record("CHAL.M3.BAR.02", "exclusiveZone is strictly 0 (floating overlay)", bar.exclusiveZone === 0, "exclusiveZone=" + bar.exclusiveZone);
                record("CHAL.M3.BAR.03", "exclusionMode is ExclusionMode.Ignore", bar.exclusionMode === ExclusionMode.Ignore, "mode=" + bar.exclusionMode);
                record("CHAL.M3.BAR.04", "bar.color is transparent", bar.color === "transparent" || bar.color.toString() === "#00000000", "color=" + bar.color);
                record("CHAL.M3.BAR.05", "bar top margin is 3", bar.margins.top === 3, "margins.top=" + bar.margins.top);
                record("CHAL.M3.BAR.06", "LivingNotch instance exists inside bar", notch !== null, "notch=" + notch);
                record("CHAL.M3.BAR.07", "Initial notchState is compact", notch.notchState === "compact", "state=" + notch.notchState);
                record("CHAL.M3.BAR.08", "Initial implicitHeight is Math.max(36, 30+6) = 36", bar.implicitHeight === 36, "implicitHeight=" + bar.implicitHeight);
                record("CHAL.M3.BAR.09", "Wayland mask is non-null", bar.mask !== null, "mask=" + bar.mask);
                record("CHAL.M3.BAR.10", "maskA and maskB pre-allocated instances exist", bar.maskA !== null && bar.maskB !== null, "maskA=" + bar.maskA + " maskB=" + bar.maskB);

                // -------------------------------------------------------------
                // SECTION 2: Double-Buffered Wayland Input Mask Toggling
                // -------------------------------------------------------------
                console.log(">>> SECTION 2: Double-Buffered Wayland Mask Reactive Flushing");
                let initialToggle = bar.toggleMask;
                let initialMaskRef = bar.mask;
                bar.flushWaylandMask();
                record("CHAL.M3.MASK.01", "flushWaylandMask() inverts toggleMask", bar.toggleMask !== initialToggle, "toggleMask=" + bar.toggleMask);
                record("CHAL.M3.MASK.02", "flushWaylandMask() changes mask reference", bar.mask !== initialMaskRef, "mask=" + bar.mask);
                bar.flushWaylandMask();
                record("CHAL.M3.MASK.03", "second flush restores original toggleMask", bar.toggleMask === initialToggle, "toggleMask=" + bar.toggleMask);
                record("CHAL.M3.MASK.04", "second flush restores original mask reference", bar.mask === initialMaskRef, "mask=" + bar.mask);

                // -------------------------------------------------------------
                // SECTION 3: Instant Mode State Transitions (reducedMotion = true)
                // -------------------------------------------------------------
                console.log(">>> SECTION 3: Instant Mode Geometry & Target Bounds (reducedMotion = true)");
                Settings.reducedMotion = true;

                // Hover transition
                notch._isHovered = true;
                record("CHAL.M3.INST.01", "Hover state engaged", notch.notchState === "hover", "state=" + notch.notchState);
                record("CHAL.M3.INST.02", "Hover targetWidth is 380", notch.targetWidth === 380, "targetWidth=" + notch.targetWidth);
                record("CHAL.M3.INST.03", "Hover targetHeight is 60", notch.targetHeight === 60, "targetHeight=" + notch.targetHeight);
                record("CHAL.M3.INST.04", "Hover width snaps to 380 instantly", notch.width === 380, "width=" + notch.width);
                record("CHAL.M3.INST.05", "Hover height snaps to 60 instantly", notch.height === 60, "height=" + notch.height);
                record("CHAL.M3.INST.06", "Hover bar implicitHeight expands to 66", bar.implicitHeight === 66, "implicitHeight=" + bar.implicitHeight);

                notch._isHovered = false;
                record("CHAL.M3.INST.07", "Unhover restores compact state", notch.notchState === "compact", "state=" + notch.notchState);
                record("CHAL.M3.INST.08", "Compact targetWidth is 220", notch.targetWidth === 220, "targetWidth=" + notch.targetWidth);
                record("CHAL.M3.INST.09", "Compact targetHeight is 30", notch.targetHeight === 30, "targetHeight=" + notch.targetHeight);
                record("CHAL.M3.INST.10", "Compact bar implicitHeight restores to 36", bar.implicitHeight === 36, "implicitHeight=" + bar.implicitHeight);

                // Notification transition
                notch.showNotification("SecDaemon", "Intrusion Attempt Blocked", 2);
                record("CHAL.M3.INST.11", "Notification state engaged", notch.notchState === "notification", "state=" + notch.notchState);
                record("CHAL.M3.INST.12", "Notification targetWidth is 320", notch.targetWidth === 320, "targetWidth=" + notch.targetWidth);
                record("CHAL.M3.INST.13", "Notification targetHeight is 30", notch.targetHeight === 30, "targetHeight=" + notch.targetHeight);
                record("CHAL.M3.INST.14", "Notification urgency captured", notch.latestUrgency === 2, "urgency=" + notch.latestUrgency);

                // Calendar morph while notification active
                notch.toggleCalendar();
                record("CHAL.M3.INST.15", "Calendar morph preempts notification", notch.notchState === "calendar", "state=" + notch.notchState);
                record("CHAL.M3.INST.16", "Calendar targetWidth is 360", notch.targetWidth === 360, "targetWidth=" + notch.targetWidth);
                record("CHAL.M3.INST.17", "Calendar targetHeight is 250", notch.targetHeight === 250, "targetHeight=" + notch.targetHeight);
                record("CHAL.M3.INST.18", "Calendar width snaps to 360 instantly", notch.width === 360, "width=" + notch.width);
                record("CHAL.M3.INST.19", "Calendar height snaps to 250 instantly", notch.height === 250, "height=" + notch.height);
                record("CHAL.M3.INST.20", "Calendar bar implicitHeight expands to 256", bar.implicitHeight === 256, "implicitHeight=" + bar.implicitHeight);

                // Close calendar while notification active
                notch.closeCalendar();
                record("CHAL.M3.INST.21", "Closing calendar restores notification state", notch.notchState === "notification", "state=" + notch.notchState);

                // Dismiss notification
                notch.isExpanded = false;
                record("CHAL.M3.INST.22", "Dismissing notification restores compact", notch.notchState === "compact", "state=" + notch.notchState);
                record("CHAL.M3.INST.23", "Bar implicitHeight returns to 36", bar.implicitHeight === 36, "implicitHeight=" + bar.implicitHeight);

                // -------------------------------------------------------------
                // SECTION 4: High-Velocity Rapid State Switching Burst (200 cycles)
                // -------------------------------------------------------------
                console.log(">>> SECTION 4: High-Velocity Rapid State Switching Burst (200 cycles)");
                let burstErrors = 0;
                let validStates = ["compact", "hover", "media", "notification", "calendar"];

                for (let i = 0; i < 200; i++) {
                    // Step 1: Hover
                    notch._isHovered = true;
                    if (notch.notchState !== "hover" && notch.notchState !== "calendar") burstErrors++;

                    // Step 2: Incoming notification
                    notch.showNotification("BurstApp", "Message " + i, i % 3);
                    if (notch.notchState !== "notification" && notch.notchState !== "calendar") burstErrors++;

                    // Step 3: Open calendar
                    notch.toggleCalendar();
                    if (notch.notchState !== "calendar") burstErrors++;

                    // Check bounds invariants
                    if (notch.targetWidth < 200 || notch.targetWidth > 400) burstErrors++;
                    if (notch.targetHeight < 30 || notch.targetHeight > 260) burstErrors++;
                    if (bar.implicitHeight < 36 || bar.implicitHeight > 260) burstErrors++;

                    // Step 4: Close calendar
                    notch.closeCalendar();

                    // Step 5: Dismiss notification
                    notch.isExpanded = false;
                    notch._isHovered = false;

                    if (validStates.indexOf(notch.notchState) === -1) burstErrors++;
                }

                record("CHAL.M3.BURST.01", "200 rapid state transitions maintain strict invariants with zero errors", burstErrors === 0, "errors=" + burstErrors);
                record("CHAL.M3.BURST.02", "Post-burst notch settles in valid state", validStates.indexOf(notch.notchState) !== -1, "state=" + notch.notchState);
                record("CHAL.M3.BURST.03", "Post-burst implicitHeight is 36", bar.implicitHeight === 36, "implicitHeight=" + bar.implicitHeight);

                // -------------------------------------------------------------
                // SECTION 5: Overlay Preemption and Opacity Handoff
                // -------------------------------------------------------------
                console.log(">>> SECTION 5: Overlay Preemption & Opacity Handoff");

                // Calendar dismissed on CommandDeck open
                notch.toggleCalendar();
                record("CHAL.M3.OVR.01", "Calendar open before CommandDeck trigger", notch.calendarOpen === true, "calendarOpen=" + notch.calendarOpen);
                OverlayController.openCommandDeck();
                record("CHAL.M3.OVR.02", "Opening CommandDeck dismisses calendar", notch.calendarOpen === false, "calendarOpen=" + notch.calendarOpen);
                OverlayController.close();

                // Calendar dismissed on CommandCenter open & Opacity handoff
                notch.toggleCalendar();
                record("CHAL.M3.OVR.03", "Calendar open before CommandCenter trigger", notch.calendarOpen === true, "calendarOpen=" + notch.calendarOpen);
                OverlayController.openCommandCenter();
                record("CHAL.M3.OVR.04", "Opening CommandCenter dismisses calendar", notch.calendarOpen === false, "calendarOpen=" + notch.calendarOpen);
                record("CHAL.M3.OVR.05", "isCommandCenterOpen evaluates to true", notch.isCommandCenterOpen === true, "isOpen=" + notch.isCommandCenterOpen);
                record("CHAL.M3.OVR.06", "Notch opacity snaps to 0.0 in reducedMotion mode", notch.opacity === 0.0, "opacity=" + notch.opacity);

                OverlayController.close();
                record("CHAL.M3.OVR.07", "Closing CommandCenter restores opacity to 1.0", notch.opacity === 1.0, "opacity=" + notch.opacity);
                record("CHAL.M3.OVR.08", "isCommandCenterOpen resets to false", notch.isCommandCenterOpen === false, "isOpen=" + notch.isCommandCenterOpen);

                // -------------------------------------------------------------
                // SECTION 6: DND and Notification Edge Cases
                // -------------------------------------------------------------
                console.log(">>> SECTION 6: DND and Notification Preemption Edge Cases");
                NotificationService.doNotDisturb = true;
                notch.showNotification("SuppressedApp", "Should not expand", 1);
                record("CHAL.M3.DND.01", "DND active suppresses notification state expansion", notch.notchState !== "notification", "state=" + notch.notchState);

                NotificationService.doNotDisturb = false;
                notch.showNotification("UrgentApp", "Critical breach", 2);
                record("CHAL.M3.DND.02", "DND inactive allows notification expansion", notch.notchState === "notification", "state=" + notch.notchState);

                NotificationService.doNotDisturb = true;
                record("CHAL.M3.DND.03", "Enabling DND mid-flight collapses active notification", notch.notchState !== "notification", "state=" + notch.notchState);
                NotificationService.doNotDisturb = false;

                // -------------------------------------------------------------
                // SECTION 7: Audio Volume Boundary Clamping
                // -------------------------------------------------------------
                console.log(">>> SECTION 7: Audio Volume Boundary Clamping");
                for (let v = 0; v < 40; v++) {
                    AudioService.stepVolume(-0.05);
                }
                record("CHAL.M3.VOL.01", "Repeated negative wheel steps clamp at exactly 0.0 without underflow", AudioService.volume === 0.0, "volume=" + AudioService.volume);

                for (let v = 0; v < 40; v++) {
                    AudioService.stepVolume(0.05);
                }
                record("CHAL.M3.VOL.02", "Repeated positive wheel steps clamp at exactly 1.0 without overflow", AudioService.volume === 1.0, "volume=" + AudioService.volume);

                if (!AudioService.muted) {
                    AudioService.toggleMute();
                }
                record("CHAL.M3.VOL.03", "Audio muted successfully", AudioService.muted === true, "muted=" + AudioService.muted);
                AudioService.stepVolume(0.05);
                record("CHAL.M3.VOL.04", "Positive wheel step un-mutes muted sink", AudioService.muted === false, "muted=" + AudioService.muted);
                AudioService.setVolume(0.5);

                // -------------------------------------------------------------
                // SECTION 8: Multi-Screen & Workspace Resilience
                // -------------------------------------------------------------
                console.log(">>> SECTION 8: Multi-Screen & Workspace Resilience");
                record("CHAL.M3.SCR.01", "Bar monitorName resolves safely without null exception", typeof notch.monitorName === "string", "monitorName=" + notch.monitorName);
                record("CHAL.M3.SCR.02", "workspaceList contains at least 5 workspace descriptors", notch.workspaceList && notch.workspaceList.length >= 5, "count=" + (notch.workspaceList ? notch.workspaceList.length : 0));

                // -------------------------------------------------------------
                // Trigger Phase 2: Live Spring Physics & Animated Mask Updates
                // -------------------------------------------------------------
                console.log(">>> TRIGGERING PHASE 2: Live Spring Physics & Double-Buffered Mask Tracking");
                Settings.reducedMotion = false;
                root.maskFlushCount = 0;
                notch._isHovered = true;
                phase2HoverTimer.start();

            } catch (err) {
                console.error("UNHANDLED EXCEPTION IN PHASE 1: " + err);
                root.failCount++;
                Qt.quit();
            }
        }
    }

    // Step 2a: Wait for hover spring animation to settle
    Timer {
        id: phase2HoverTimer
        interval: 750
        running: false
        repeat: false
        onTriggered: {
            console.log(">>> PHASE 2a: Hover Spring Settling & Mask Updates");
            record("CHAL.M3.SPRG.01", "Hover spring settles to 60px height", Math.abs(notch.height - 60) < 1.0, "height=" + notch.height);
            record("CHAL.M3.SPRG.02", "Hover spring settles to 380px width", Math.abs(notch.width - 380) < 1.0, "width=" + notch.width);
            record("CHAL.M3.SPRG.03", "Bar implicitHeight smoothly expanded to 66px", Math.abs(bar.implicitHeight - 66) < 1.0, "implicitHeight=" + bar.implicitHeight);
            record("CHAL.M3.SPRG.04", "Double-buffered Wayland mask flushed continuously during animation", root.maskFlushCount > 5, "flushCount=" + root.maskFlushCount);

            // Now trigger calendar morph
            root.maskFlushCount = 0;
            notch.toggleCalendar();
            phase2CalTimer.start();
        }
    }

    // Step 2b: Wait for calendar morph spring animation to settle
    Timer {
        id: phase2CalTimer
        interval: 850
        running: false
        repeat: false
        onTriggered: {
            console.log(">>> PHASE 2b: Calendar Morph Spring Settling & Layer Surface Expansion");
            record("CHAL.M3.SPRG.05", "Calendar morph settles to 250px height", Math.abs(notch.height - 250) < 1.0, "height=" + notch.height);
            record("CHAL.M3.SPRG.06", "Calendar morph settles to 360px width", Math.abs(notch.width - 360) < 1.0, "width=" + notch.width);
            record("CHAL.M3.SPRG.07", "Bar implicitHeight expands to accommodate calendar (256px)", Math.abs(bar.implicitHeight - 256) < 1.0, "implicitHeight=" + bar.implicitHeight);
            record("CHAL.M3.SPRG.08", "Wayland mask flushes continuously during calendar morph", root.maskFlushCount > 5, "flushCount=" + root.maskFlushCount);

            // Now test animated opacity handoff to CommandCenter
            OverlayController.openCommandCenter();
            phase2OpacityTimer.start();
        }
    }

    // Step 2c: Wait for CommandCenter opacity animation to settle
    Timer {
        id: phase2OpacityTimer
        interval: 450
        running: false
        repeat: false
        onTriggered: {
            console.log(">>> PHASE 2c: CommandCenter Animated Opacity Handoff");
            record("CHAL.M3.OPAC.01", "Calendar was dismissed on CommandCenter open", notch.calendarOpen === false, "calendarOpen=" + notch.calendarOpen);
            record("CHAL.M3.OPAC.02", "Notch opacity smoothly animates to 0.0", Math.abs(notch.opacity - 0.0) < 0.05, "opacity=" + notch.opacity);

            OverlayController.close();
            notch._isHovered = false;
            phase2RestoreTimer.start();
        }
    }

    // Step 2d: Wait for return to compact
    Timer {
        id: phase2RestoreTimer
        interval: 750
        running: false
        repeat: false
        onTriggered: {
            console.log(">>> PHASE 2d: Return to Baseline Compact State");
            record("CHAL.M3.OPAC.03", "Notch opacity restores to 1.0", Math.abs(notch.opacity - 1.0) < 0.05, "opacity=" + notch.opacity);
            record("CHAL.M3.REST.01", "Notch returns to compact height (30px)", Math.abs(notch.height - 30) < 1.0, "height=" + notch.height);
            record("CHAL.M3.REST.02", "Notch returns to compact width (220px)", Math.abs(notch.width - 220) < 1.0, "width=" + notch.width);
            record("CHAL.M3.REST.03", "Bar implicitHeight returns to 36px", Math.abs(bar.implicitHeight - 36) < 1.0, "implicitHeight=" + bar.implicitHeight);

            console.log("================================================================");
            console.log("CHALLENGER 2 FINAL RESULTS: Passed=" + root.passCount + ", Failed=" + root.failCount);
            if (root.failCount === 0) {
                console.log("=== PASS: ALL EMPIRICAL CHALLENGES AND STRESS SUITES PASSED ===");
            } else {
                console.error("=== FAIL: CHALLENGES FAILED: " + root.failureList.join("; ") + " ===");
            }
            console.log("================================================================");

            Qt.quit();
        }
    }
}
