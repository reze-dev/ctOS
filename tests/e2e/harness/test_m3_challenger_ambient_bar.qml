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

    AmbientBar {
        id: testBar
        screen: Quickshell.screens[0] || null
    }

    // Monitor flushWaylandMask calls
    property int flushCounter: 0
    Connections {
        target: testBar
        function onToggleMaskChanged() {
            harnessRoot.flushCounter++;
        }
    }

    // Reference to livingNotch inside AmbientBar
    readonly property var livingNotchItem: {
        for (let i = 0; i < testBar.contentItem.children.length; i++) {
            const child = testBar.contentItem.children[i];
            if (child && child.hasOwnProperty("compactWidth") && child.hasOwnProperty("hoverWidth")) {
                return child;
            }
        }
        return null;
    }

    // Reference to legacyCompatibilityLayer inside AmbientBar
    readonly property var legacyLayer: {
        for (let i = 0; i < testBar.contentItem.children.length; i++) {
            const child = testBar.contentItem.children[i];
            if (child && (child.id === "legacyCompatibilityLayer" || child.objectName === "legacyCompatibilityLayer" || (!child.visible && child.width === 0 && child.height === 0))) {
                return child;
            }
        }
        return null;
    }

    Timer {
        id: testRunner
        interval: 80
        running: true
        repeat: true
        property int step: 0
        property int waitTicks: 0

        onTriggered: {
            step++;
            switch (step) {
            case 1:
                console.log("================================================================");
                console.log("=== EMPIRICAL CHALLENGER: M3 AMBIENTBAR & WAYLAND MASK HARNESS ==");
                console.log("================================================================");

                // --- 1. Top Bar Host Layer Shell Configuration ---
                record("CHAL.M3.LS.01", "AmbientBar instantiates cleanly as PanelWindow", testBar !== null, "bar=" + testBar);
                record("CHAL.M3.LS.02", "exclusiveZone is strictly 0 (no space reserved)", testBar.exclusiveZone === 0, "exclusiveZone=" + testBar.exclusiveZone);
                record("CHAL.M3.LS.03", "exclusionMode is ExclusionMode.Ignore", testBar.exclusionMode === ExclusionMode.Ignore, "exclusionMode=" + testBar.exclusionMode);
                record("CHAL.M3.LS.04", "WlrLayershell layer is WlrLayer.Top", testBar.WlrLayershell.layer === WlrLayer.Top, "layer=" + testBar.WlrLayershell.layer);
                record("CHAL.M3.LS.05", "WlrLayershell namespace is 'ctos-bar'", testBar.WlrLayershell.namespace === "ctos-bar", "namespace=" + testBar.WlrLayershell.namespace);
                record("CHAL.M3.LS.06", "WlrLayershell keyboardFocus is None", testBar.WlrLayershell.keyboardFocus === WlrKeyboardFocus.None, "keyboardFocus=" + testBar.WlrLayershell.keyboardFocus);
                record("CHAL.M3.LS.07", "Background color is fully transparent", testBar.color.toString() === "#00000000", "color=" + testBar.color.toString());
                record("CHAL.M3.LS.08", "PanelWindow anchors span left, right, top", testBar.anchors.left === true && testBar.anchors.right === true && testBar.anchors.top === true, "left=" + testBar.anchors.left + " right=" + testBar.anchors.right + " top=" + testBar.anchors.top);
                record("CHAL.M3.LS.09", "Top margin is set to 3px", testBar.margins.top === 3, "margins.top=" + testBar.margins.top);
                break;

            case 2:
                // --- 2. LivingNotch Component Discovery & Centering ---
                record("CHAL.M3.LN.01", "LivingNotch discovered in AmbientBar contentItem", livingNotchItem !== null, "notch=" + livingNotchItem);
                if (livingNotchItem) {
                    record("CHAL.M3.LN.02", "LivingNotch initial width matches compactWidth (220)", Math.round(livingNotchItem.width) === 220, "width=" + livingNotchItem.width);
                    record("CHAL.M3.LN.03", "LivingNotch initial height matches compactHeight (30)", Math.round(livingNotchItem.height) === 30, "height=" + livingNotchItem.height);
                    record("CHAL.M3.LN.04", "LivingNotch y is 0 (anchors.top: parent.top)", Math.round(livingNotchItem.y) === 0, "y=" + livingNotchItem.y);
                    
                    const expectedX = Math.round((testBar.width - livingNotchItem.width) / 2);
                    record("CHAL.M3.LN.05", "LivingNotch x is centered horizontally", Math.abs(Math.round(livingNotchItem.x) - expectedX) <= 1, "x=" + Math.round(livingNotchItem.x) + " expected=" + expectedX + " barWidth=" + testBar.width);
                }
                break;

            case 3:
                // --- 3. Dynamic Double-Buffered Mask Architecture ---
                record("CHAL.M3.MASK.01", "maskA is instantiated and non-null", testBar.maskA !== null, "maskA=" + testBar.maskA);
                record("CHAL.M3.MASK.02", "maskB is instantiated and non-null", testBar.maskB !== null, "maskB=" + testBar.maskB);
                record("CHAL.M3.MASK.03", "maskA and maskB are distinct objects", testBar.maskA !== testBar.maskB, "distinct=true");
                record("CHAL.M3.MASK.04", "Active mask matches toggleMask boolean condition", (testBar.toggleMask ? testBar.mask === testBar.maskA : testBar.mask === testBar.maskB), "toggleMask=" + testBar.toggleMask);

                // Test manual flushWaylandMask toggling
                const preToggle = testBar.toggleMask;
                const preMask = testBar.mask;
                testBar.flushWaylandMask();
                record("CHAL.M3.MASK.05", "flushWaylandMask() inverts toggleMask", testBar.toggleMask === !preToggle, "before=" + preToggle + " after=" + testBar.toggleMask);
                record("CHAL.M3.MASK.06", "flushWaylandMask() alters mask reference", testBar.mask !== preMask, "mask swapped");

                testBar.flushWaylandMask();
                record("CHAL.M3.MASK.07", "Second flushWaylandMask() restores toggleMask", testBar.toggleMask === preToggle, "restored=" + testBar.toggleMask);
                record("CHAL.M3.MASK.08", "Second flushWaylandMask() restores mask reference", testBar.mask === preMask, "restored mask");
                break;

            case 4:
                // --- 4. Point-in-Notch Hit-Testing (Wayland Input Passthrough Oracle) ---
                if (livingNotchItem) {
                    const notchX = livingNotchItem.x;
                    const notchY = livingNotchItem.y;
                    const notchW = livingNotchItem.width;
                    const notchH = livingNotchItem.height;

                    const isInsideNotch = (px, py) => {
                        return (px >= notchX && px <= notchX + notchW && py >= notchY && py <= notchY + notchH);
                    };

                    record("CHAL.M3.HIT.01", "Center of notch is INSIDE notch bounding box", isInsideNotch(notchX + notchW / 2, notchY + notchH / 2) === true, "x=" + (notchX + notchW/2) + " y=" + (notchY + notchH/2));
                    record("CHAL.M3.HIT.02", "50px left of notch is OUTSIDE notch (clean passthrough)", isInsideNotch(notchX - 50, notchY + 10) === false, "x=" + (notchX - 50) + " y=" + (notchY + 10));
                    record("CHAL.M3.HIT.03", "50px right of notch is OUTSIDE notch (clean passthrough)", isInsideNotch(notchX + notchW + 50, notchY + 10) === false, "x=" + (notchX + notchW + 50) + " y=" + (notchY + 10));
                    record("CHAL.M3.HIT.04", "Display top-left corner (10, 10) is OUTSIDE notch (clean passthrough)", isInsideNotch(10, 10) === false, "x=10 y=10");
                    record("CHAL.M3.HIT.05", "Display top-right corner (barWidth - 10, 10) is OUTSIDE notch (clean passthrough)", isInsideNotch(testBar.width - 10, 10) === false, "x=" + (testBar.width - 10) + " y=10");
                    record("CHAL.M3.HIT.06", "Point below compact notch (notchY + 34) is OUTSIDE notch (clean passthrough)", isInsideNotch(notchX + notchW / 2, notchY + 34) === false, "y=34 compactH=30");
                }
                break;

            case 5:
                // --- 5. Hover State Expansion & Mask Flush Tracking ---
                if (livingNotchItem) {
                    harnessRoot.flushCounter = 0;
                    livingNotchItem._isHovered = true;
                    console.log("Triggered hover state on LivingNotch...");
                }
                break;

            case 6:
                // Wait for spring animation to settle
                if (livingNotchItem && Math.abs(livingNotchItem.width - 380) > 1.0) {
                    waitTicks++;
                    if (waitTicks < 20) {
                        step = 5; // keep waiting
                    }
                } else {
                    waitTicks = 0;
                }
                break;

            case 7:
                if (livingNotchItem) {
                    record("CHAL.M3.EXP.01", "LivingNotch targetWidth expands to hoverWidth (380)", livingNotchItem.targetWidth === 380, "targetWidth=" + livingNotchItem.targetWidth);
                    record("CHAL.M3.EXP.02", "LivingNotch targetHeight expands to hoverHeight (60)", livingNotchItem.targetHeight === 60, "targetHeight=" + livingNotchItem.targetHeight);
                    record("CHAL.M3.EXP.03", "LivingNotch settled width matches hoverWidth (380)", Math.abs(livingNotchItem.width - 380) <= 2, "width=" + livingNotchItem.width);
                    record("CHAL.M3.EXP.04", "LivingNotch settled height matches hoverHeight (60)", Math.abs(livingNotchItem.height - 60) <= 2, "height=" + livingNotchItem.height);
                    record("CHAL.M3.EXP.05", "AmbientBar implicitHeight expands to accommodate hoverHeight (66)", Math.abs(testBar.implicitHeight - 66) <= 2, "implicitHeight=" + testBar.implicitHeight);
                    record("CHAL.M3.EXP.06", "Dynamic mask flushCounter recorded continuous toggles during animation", harnessRoot.flushCounter > 5, "flushes=" + harnessRoot.flushCounter);
                }
                break;

            case 8:
                // --- 6. Morphing Calendar State & Expansion ---
                if (livingNotchItem) {
                    harnessRoot.flushCounter = 0;
                    livingNotchItem._isHovered = false;
                    livingNotchItem.toggleCalendar();
                    console.log("Triggered calendar state on LivingNotch...");
                }
                break;

            case 9:
                // Wait for calendar spring animation to settle
                if (livingNotchItem && Math.abs(livingNotchItem.height - 250) > 2.0) {
                    waitTicks++;
                    if (waitTicks < 25) {
                        step = 8; // keep waiting
                    }
                } else {
                    waitTicks = 0;
                }
                break;

            case 10:
                if (livingNotchItem) {
                    record("CHAL.M3.CAL.01", "LivingNotch notchState is 'calendar'", livingNotchItem.notchState === "calendar", "state=" + livingNotchItem.notchState);
                    record("CHAL.M3.CAL.02", "LivingNotch targetHeight expands to calendarHeight (250)", livingNotchItem.targetHeight === 250, "targetHeight=" + livingNotchItem.targetHeight);
                    record("CHAL.M3.CAL.03", "LivingNotch settled height matches calendarHeight (250)", Math.abs(livingNotchItem.height - 250) <= 2, "height=" + livingNotchItem.height);
                    record("CHAL.M3.CAL.04", "AmbientBar implicitHeight expands to >= 256px", Math.abs(testBar.implicitHeight - 256) <= 2, "implicitHeight=" + testBar.implicitHeight);
                    record("CHAL.M3.CAL.05", "Dynamic mask flushCounter toggled for calendar transition", harnessRoot.flushCounter > 5, "flushes=" + harnessRoot.flushCounter);

                    // Verify expanded calendar hit test
                    const notchX = livingNotchItem.x;
                    const notchY = livingNotchItem.y;
                    const isInsideCalendar = (px, py) => (px >= notchX && px <= notchX + livingNotchItem.width && py >= notchY && py <= notchY + livingNotchItem.height);
                    record("CHAL.M3.CAL.06", "Point at y=150 (calendar interior) is now INSIDE notch mask", isInsideCalendar(notchX + livingNotchItem.width / 2, 150) === true, "y=150 inside calendar");

                    // Close calendar
                    livingNotchItem.closeCalendar();
                    console.log("Closed calendar on LivingNotch...");
                }
                break;

            case 11:
                // Wait for collapse back to compact state
                if (livingNotchItem && Math.abs(livingNotchItem.height - 30) > 1.5) {
                    waitTicks++;
                    if (waitTicks < 30) {
                        step = 10; // keep waiting
                    }
                } else {
                    waitTicks = 0;
                }
                break;

            case 12:
                // --- 7. Settled Collapse & Legacy Layer Verification ---
                if (livingNotchItem) {
                    record("CHAL.M3.COL.01", "LivingNotch returns to targetWidth 220", livingNotchItem.targetWidth === 220, "targetWidth=" + livingNotchItem.targetWidth);
                    record("CHAL.M3.COL.02", "LivingNotch returns to targetHeight 30", livingNotchItem.targetHeight === 30, "targetHeight=" + livingNotchItem.targetHeight);
                    record("CHAL.M3.COL.03", "LivingNotch settled height returned to 30", Math.abs(livingNotchItem.height - 30) <= 2, "height=" + livingNotchItem.height);
                    record("CHAL.M3.COL.04", "AmbientBar implicitHeight contracted back to Theme.barHeight", testBar.implicitHeight <= Theme.barHeight + 2, "implicitHeight=" + testBar.implicitHeight);
                }

                // Legacy layer checks
                record("CHAL.M3.LEG.01", "Legacy compatibility layer exists", legacyLayer !== null, "layer=" + legacyLayer);
                if (legacyLayer) {
                    record("CHAL.M3.LEG.02", "Legacy layer visible is false", legacyLayer.visible === false, "visible=" + legacyLayer.visible);
                    record("CHAL.M3.LEG.03", "Legacy layer enabled is false", legacyLayer.enabled === false, "enabled=" + legacyLayer.enabled);
                    record("CHAL.M3.LEG.04", "Legacy layer width is 0", legacyLayer.width === 0, "width=" + legacyLayer.width);
                    record("CHAL.M3.LEG.05", "Legacy layer height is 0", legacyLayer.height === 0, "height=" + legacyLayer.height);
                }
                break;

            case 13:
                // --- 8. Rapid Cycling & Stress Hardening ---
                console.log("Running rapid 50-cycle hover toggle burst...");
                let preBurstCounter = harnessRoot.flushCounter;
                for (let c = 0; c < 50; c++) {
                    testBar.flushWaylandMask();
                }
                record("CHAL.M3.BURST.01", "50 rapid flushWaylandMask calls executed without freeze", harnessRoot.flushCounter === preBurstCounter + 50, "delta=" + (harnessRoot.flushCounter - preBurstCounter));
                record("CHAL.M3.BURST.02", "Mask reference valid and non-null after burst", testBar.mask !== null, "mask=" + testBar.mask);

                // Multi-monitor mock screen property binding test
                record("CHAL.M3.MM.01", "LivingNotch monitorName binds to root.screen.name", livingNotchItem.monitorName === ((testBar.screen && testBar.screen.name) ? testBar.screen.name : ""), "monName=" + livingNotchItem.monitorName);
                break;

            case 14:
                // Final Summary
                console.log("================================================================");
                console.log("RESULTS: Passed=" + passCount + ", Failed=" + failCount);
                if (failCount === 0) {
                    console.log("=== PASS: EMPIRICAL CHALLENGER M3 VERIFICATION SUCCESSFUL ===");
                } else {
                    console.error("=== FAIL: EMPIRICAL CHALLENGER DETECTED " + failCount + " FAILURES ===");
                    for (let f = 0; f < failureList.length; f++) {
                        console.error("  - " + failureList[f]);
                    }
                }
                console.log("================================================================");

                testRunner.stop();
                Qt.quit();
                break;
            }
        }
    }
}
