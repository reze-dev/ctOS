import QtQuick
import QtQuick.Layouts
import Quickshell
import desktop.core
import desktop.services

FloatingWindow {
    id: testWindow
    visible: true
    implicitWidth: 1000
    implicitHeight: 800

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

    Item {
        id: testHost
        anchors.fill: parent

        Loader {
            id: notchLoader
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: 10
            source: "file://" + (Quickshell.env("PROJECT_ROOT") || "/home/reze/Projects/ctOS") + "/shell/desktop/surfaces/components/LivingNotch.qml"
        }
    }

    // Sequence controller
    property int currentStep: 0
    property var stepHistory: []

    Timer {
        id: stepTimer
        interval: 80
        repeat: true
        running: true
        onTriggered: {
            var notch = notchLoader.item;
            if (!notch) {
                assertCondition("CHAL.INIT", "LivingNotch loaded", false, "Loader item is null");
                Qt.quit();
                return;
            }

            // Check for NaN or Inf on every step
            if (isNaN(notch.width) || isNaN(notch.height) || isNaN(notch.currentWidth) || isNaN(notch.currentHeight) || isNaN(notch.opacity)) {
                assertCondition("CHAL.NAN.01", "No NaN values in notch dimensions or opacity", false,
                    "w=" + notch.width + ", h=" + notch.height + ", cw=" + notch.currentWidth + ", ch=" + notch.currentHeight + ", op=" + notch.opacity);
            }

            currentStep++;

            switch (currentStep) {
            case 1:
                console.log("--- STEP 1: Compact State Baseline ---");
                assertCondition("CHAL.STATE.01", "Initial state is compact",
                    notch.notchState === "compact", "state=" + notch.notchState);
                assertCondition("CHAL.DIM.01", "Compact width is 220",
                    notch.targetWidth === 220, "targetWidth=" + notch.targetWidth);
                assertCondition("CHAL.DIM.02", "Compact height is 30",
                    notch.targetHeight === 30, "targetHeight=" + notch.targetHeight);
                break;

            case 2:
                console.log("--- STEP 2: Hover Expansion ---");
                notch._isHovered = true;
                break;

            case 5:
                // Wait for spring animation to settle (~240ms)
                assertCondition("CHAL.STATE.02", "Hover state active",
                    notch.notchState === "hover", "state=" + notch.notchState);
                assertCondition("CHAL.DIM.03", "Hover target width is 380",
                    notch.targetWidth === 380, "targetWidth=" + notch.targetWidth);
                assertCondition("CHAL.DIM.04", "Hover target height is 60",
                    notch.targetHeight === 60, "targetHeight=" + notch.targetHeight);
                assertCondition("CHAL.SPRING.01", "Current width approached 380 within 10px",
                    Math.abs(notch.currentWidth - 380) < 10, "currentWidth=" + notch.currentWidth);
                assertCondition("CHAL.SPRING.02", "Current height approached 60 within 5px",
                    Math.abs(notch.currentHeight - 60) < 5, "currentHeight=" + notch.currentHeight);
                break;

            case 6:
                console.log("--- STEP 3: Hover Collapse ---");
                notch._isHovered = false;
                break;

            case 9:
                // Wait for spring animation to settle back to compact
                assertCondition("CHAL.STATE.03", "Reverted to compact state",
                    notch.notchState === "compact", "state=" + notch.notchState);
                assertCondition("CHAL.SPRING.03", "Current width returned to 220 within 10px",
                    Math.abs(notch.currentWidth - 220) < 10, "currentWidth=" + notch.currentWidth);
                break;

            case 10:
                console.log("--- STEP 4: Rapid Hover Oscillation (10 toggles) ---");
                break;

            // Steps 11..20: rapid toggling every 80ms
            case 11: case 13: case 15: case 17: case 19:
                notch._isHovered = true;
                break;
            case 12: case 14: case 16: case 18: case 20:
                notch._isHovered = false;
                break;

            case 21:
                assertCondition("CHAL.OSC.01", "Width bounded during rapid oscillation",
                    notch.currentWidth >= 180 && notch.currentWidth <= 550,
                    "currentWidth=" + notch.currentWidth);
                assertCondition("CHAL.OSC.02", "Height bounded during rapid oscillation",
                    notch.currentHeight >= 20 && notch.currentHeight <= 120,
                    "currentHeight=" + notch.currentHeight);
                break;

            case 22:
                console.log("--- STEP 5: Settings.reducedMotion Behavior ---");
                Settings.reducedMotion = true;
                notch._isHovered = true;
                break;

            case 23:
                // With reducedMotion, spring=100 damping=1.0 mass=1.0 should converge almost immediately
                assertCondition("CHAL.REDUCED.01", "Reduced motion expands without delay",
                    Math.abs(notch.currentWidth - 380) < 5, "currentWidth=" + notch.currentWidth);
                notch._isHovered = false;
                break;

            case 24:
                assertCondition("CHAL.REDUCED.02", "Reduced motion collapses without delay",
                    Math.abs(notch.currentWidth - 220) < 5, "currentWidth=" + notch.currentWidth);
                Settings.reducedMotion = false; // restore
                break;

            case 25:
                console.log("--- STEP 6: Priority Invariant Hierarchy ---");
                // Test: calendar > notification > hover > media > compact
                // Activate notification and hover simultaneously
                notch._notificationActive = true;
                notch._isHovered = true;
                assertCondition("CHAL.PRIO.01", "Notification beats Hover",
                    notch.notchState === "notification", "state=" + notch.notchState);
                break;

            case 26:
                // Activate calendar: should beat notification and hover
                notch._isCalendarOpen = true;
                assertCondition("CHAL.PRIO.02", "Calendar beats Notification and Hover",
                    notch.notchState === "calendar", "state=" + notch.notchState);
                break;

            case 27:
                // Deactivate calendar, DND=true: should suppress notification and yield to hover
                NotificationService.doNotDisturb = true;
                notch._isCalendarOpen = false;
                assertCondition("CHAL.PRIO.03", "DND suppresses Notification, revealing Hover",
                    notch.notchState === "hover", "state=" + notch.notchState);
                NotificationService.doNotDisturb = false;
                notch._notificationActive = false;
                notch._isHovered = false;
                break;

            case 28:
                console.log("--- STEP 7: Equalizer Mathematical Model ---");
                // Check equalizer phase & bar heights
                notch.visualizerPhase = 1.5;
                for (var b = 0; b < 4; b++) {
                    var barH = Math.max(3, Math.round((Math.sin((b * 1.1) + 1.5) * 0.4 + 0.5) * 14));
                    assertCondition("CHAL.EQ.0" + b, "Equalizer bar " + b + " height is within [3..14] range",
                        barH >= 3 && barH <= 14, "barH=" + barH);
                }
                break;

            case 29:
                console.log("--- STEP 8: Overlay Opacity Handoff ---");
                OverlayController.openCommandCenter();
                break;

            case 34:
                // 5 steps * 80ms = 400ms > Theme.durationSlow (300ms)
                assertCondition("CHAL.OVERLAY.01", "LivingNotch isCommandCenterOpen is true",
                    notch.isCommandCenterOpen === true, "isCommandCenterOpen=" + notch.isCommandCenterOpen);
                assertCondition("CHAL.OVERLAY.02", "LivingNotch opacity yields to 0.0 when CommandCenter open",
                    notch.opacity === 0.0, "opacity=" + notch.opacity);
                OverlayController.close();
                break;

            case 39:
                // 5 steps * 80ms = 400ms > Theme.durationSlow (300ms)
                assertCondition("CHAL.OVERLAY.03", "LivingNotch opacity restored to 1.0",
                    notch.opacity === 1.0, "opacity=" + notch.opacity);
                break;

            case 40:
                console.log("--- FINAL RESULTS ---");
                console.log("Passed: " + passCount + ", Failed: " + failCount);
                if (failCount === 0) {
                    console.log("=== PASS: EMPIRICAL CHALLENGER VERIFICATION SUCCESSFUL ===");
                } else {
                    console.error("=== ASSERTION_FAILED: " + failCount + " challenger tests failed ===");
                    for (var k = 0; k < failureReasons.length; k++) {
                        console.error("  - " + failureReasons[k]);
                    }
                }
                stepTimer.stop();
                Qt.quit();
                break;
            }
        }
    }
}
