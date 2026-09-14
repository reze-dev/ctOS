pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import desktop.services
import desktop.core
import desktop.surfaces
import desktop.surfaces.components

Scope {
    id: root

    AmbientBar {
        id: bar
        width: 1920
    }

    property int passCount: 0
    property int failCount: 0

    function assertCondition(id, name, condition, details) {
        if (condition) {
            passCount++;
            console.log("[PASS] " + id + ": " + name + " (" + details + ")");
        } else {
            failCount++;
            console.error("[FAIL] " + id + ": " + name + " (" + details + ")");
        }
    }

    Timer {
        id: stressRunner
        interval: 100
        running: true
        repeat: false
        onTriggered: {
            try {
                console.log("================================================================================");
                console.log("=== EMPIRICAL CHALLENGER: M2 ADVERSARIAL RUNTIME BOUNDARY STRESS TEST ===");
                console.log("================================================================================");

                let barChildren = bar.contentItem ? bar.contentItem.children : bar.children;
                let leftLayout = barChildren[0];
                let centerElement = barChildren[1];
                let rightLayout = barChildren[2];

                let leftContainers = leftLayout.children;
                let rightContainers = rightLayout.children;

                let logoSec = leftContainers[0];
                let wsSec = leftContainers[1];
                let titleSec = leftContainers[2];
                let netSec = rightContainers[0];
                let volSec = rightContainers[1];
                let batSec = rightContainers[2];
                let btSec = rightContainers[3];
                let clkSec = rightContainers[4];
                let railSec = rightContainers[5];

                // =====================================================================
                // 1. All 10 Containers Height (34px) & Radius (8px) Baseline
                // =====================================================================
                let allSections = [
                    { name: "logoSection", item: logoSec },
                    { name: "workspacesSection", item: wsSec },
                    { name: "windowTitleSection", item: titleSec },
                    { name: "centerSection", item: centerElement },
                    { name: "networkSection", item: netSec },
                    { name: "volumeSection", item: volSec },
                    { name: "batterySection", item: batSec },
                    { name: "bluetoothSection", item: btSec },
                    { name: "clockSection", item: clkSec },
                    { name: "railSection", item: railSec }
                ];

                for (let i = 0; i < allSections.length; i++) {
                    let s = allSections[i];
                    assertCondition("STRESS.BASE.DIM." + (i + 1),
                        s.name + " height is exactly 34px and radius is 8px",
                        s.item.height === 34 && s.item.radius === 8,
                        "height=" + s.item.height + ", radius=" + s.item.radius);
                }

                // =====================================================================
                // 2. Logo Branding & Geometry
                // =====================================================================
                assertCondition("STRESS.LOGO.DIM", "logoSection is 34x34 square",
                    logoSec.width === 34 && logoSec.height === 34,
                    "w=" + logoSec.width + ", h=" + logoSec.height);

                let logoImg = null;
                for (let i = 0; i < logoSec.children.length; i++) {
                    let c = logoSec.children[i];
                    if (c.toString().indexOf("Image") !== -1) logoImg = c;
                }
                assertCondition("STRESS.LOGO.IMG", "logo bare Image is 22x22 and ready",
                    logoImg !== null && logoImg.width === 22 && logoImg.height === 22 && logoImg.status === Image.Ready,
                    "img=" + (logoImg ? (logoImg.width + "x" + logoImg.height + ", status=" + logoImg.status) : "null"));

                assertCondition("STRESS.LOGO.CLEARANCE", "logo has 6px symmetric clearance in 34px container",
                    logoImg !== null && logoImg.x === 6 && logoImg.y === 6,
                    "x=" + (logoImg ? logoImg.x : -1) + ", y=" + (logoImg ? logoImg.y : -1));

                // =====================================================================
                // 3. Window Title Boundary Stress (clamping to 380px, clip, elision)
                // =====================================================================
                let titleWidget = null;
                for (let i = 0; i < titleSec.children.length; i++) {
                    let c = titleSec.children[i];
                    if (c.toString().indexOf("WindowTitleWidget") !== -1) titleWidget = c;
                }
                assertCondition("STRESS.TITLE.FOUND", "WindowTitleWidget found inside titleSec",
                    titleWidget !== null, "widget=" + titleWidget);

                assertCondition("STRESS.TITLE.MAXWIDTH", "titleSec width strictly clamped to <= 380px",
                    titleSec.width <= 380 && titleSec.Layout.maximumWidth === 380,
                    "width=" + titleSec.width + ", maxWidth=" + titleSec.Layout.maximumWidth);

                assertCondition("STRESS.TITLE.HEIGHT", "titleSec height strictly 34px under title rendering",
                    titleSec.height === 34, "height=" + titleSec.height);

                // =====================================================================
                // 4. Workspaces Clearance & Dynamic Sizing
                // =====================================================================
                let wsWidget = null;
                for (let i = 0; i < wsSec.children.length; i++) {
                    let c = wsSec.children[i];
                    if (c.toString().indexOf("WorkspacesWidget") !== -1) wsWidget = c;
                }
                assertCondition("STRESS.WS.FOUND", "WorkspacesWidget found inside wsSec",
                    wsWidget !== null, "widget=" + wsWidget);

                assertCondition("STRESS.WS.HEIGHT", "wsSec height strictly 34px",
                    wsSec.height === 34, "height=" + wsSec.height);

                assertCondition("STRESS.WS.CLEARANCE", "wsWidget implicitHeight leaves vertical clearance",
                    wsWidget !== null && wsWidget.implicitHeight <= 22,
                    "implicitHeight=" + (wsWidget ? wsWidget.implicitHeight : -1));

                // =====================================================================
                // 5. Volume Section Boundary Invariants
                // =====================================================================
                let volWidget = null;
                for (let i = 0; i < volSec.children.length; i++) {
                    let c = volSec.children[i];
                    if (c.toString().indexOf("VolumeWidget") !== -1) volWidget = c;
                }
                assertCondition("STRESS.VOL.FOUND", "VolumeWidget found inside volSec",
                    volWidget !== null, "widget=" + volWidget);

                assertCondition("STRESS.VOL.HEIGHT", "volSec height strictly 34px",
                    volSec.height === 34, "height=" + volSec.height);

                assertCondition("STRESS.VOL.CLEARANCE", "volWidget implicitHeight is 16px (9px clearance)",
                    volWidget !== null && volWidget.implicitHeight === 16,
                    "implicitHeight=" + (volWidget ? volWidget.implicitHeight : -1));

                // =====================================================================
                // 6. Battery Section Hardware Omission & Boundary
                // =====================================================================
                let batWidget = null;
                for (let i = 0; i < batSec.children.length; i++) {
                    let c = batSec.children[i];
                    if (c.toString().indexOf("BatteryWidget") !== -1) batWidget = c;
                }
                assertCondition("STRESS.BAT.FOUND", "BatteryWidget found inside batSec",
                    batWidget !== null, "widget=" + batWidget);

                assertCondition("STRESS.BAT.VIS_BOUND", "batSec visibility is coupled to batteryWidget.visible",
                    batSec.visible === batWidget.visible,
                    "secVis=" + batSec.visible + ", widgetVis=" + batWidget.visible);

                assertCondition("STRESS.BAT.HEIGHT", "batSec height strictly 34px",
                    batSec.height === 34, "height=" + batSec.height);

                // =====================================================================
                // 7. Hover Rectangles & Containment
                // =====================================================================
                let hoverSections = [
                    { name: "logoSection", sec: logoSec },
                    { name: "windowTitleSection", sec: titleSec },
                    { name: "networkSection", sec: netSec },
                    { name: "volumeSection", sec: volSec },
                    { name: "batterySection", sec: batSec },
                    { name: "bluetoothSection", sec: btSec },
                    { name: "clockSection", sec: clkSec },
                    { name: "railSection", sec: railSec }
                ];

                for (let i = 0; i < hoverSections.length; i++) {
                    let h = hoverSections[i];
                    let ma = null;
                    for (let c = 0; c < h.sec.children.length; c++) {
                        let child = h.sec.children[c];
                        if (child.toString().indexOf("MouseArea") !== -1) ma = child;
                    }
                    let maFills = ma !== null && ma.width === h.sec.width && ma.height === h.sec.height;
                    let maCursor = ma !== null && ma.cursorShape === Qt.PointingHandCursor;
                    assertCondition("STRESS.HOVER.MA." + (i + 1),
                        h.name + " MouseArea fills container exactly with PointingHandCursor",
                        maFills && maCursor,
                        "fills=" + maFills + ", cursor=" + (ma ? ma.cursorShape : -1));
                }

                // =====================================================================
                // 8. DynamicIsland Expand / Collapse Boundary Invariants
                // =====================================================================
                assertCondition("STRESS.DI.COMPACT", "DynamicIsland initial compact width is 120px and height 34px",
                    centerElement.width === 120 && centerElement.height === 34,
                    "w=" + centerElement.width + ", h=" + centerElement.height);

                assertCondition("STRESS.DI.RADIUS", "DynamicIsland radius is Theme.radiusMedium (8px)",
                    centerElement.radius === 8, "radius=" + centerElement.radius);

                assertCondition("STRESS.DI.CLIP", "DynamicIsland clip is true",
                    centerElement.clip === true, "clip=" + centerElement.clip);

                // =====================================================================
                // 9. Spacing & Gaps Between Adjacent Containers
                // =====================================================================
                assertCondition("STRESS.GAP.LEFT_LAYOUT", "leftLayout spacing is Theme.spacingMedium (8px)",
                    leftLayout.spacing === 8, "spacing=" + leftLayout.spacing);

                assertCondition("STRESS.GAP.RIGHT_LAYOUT", "rightLayout spacing is Theme.spacingMedium (8px)",
                    rightLayout.spacing === 8, "spacing=" + rightLayout.spacing);

                // =====================================================================
                // SUMMARY
                // =====================================================================
                console.log("================================================================================");
                console.log("STRESS TEST HARNESS SUMMARY: Passed=" + passCount + ", Failed=" + failCount);
                if (failCount === 0) {
                    console.log("=== EMPIRICAL CHALLENGER: ALL RUNTIME BOUNDARY STRESS TESTS PASSED ===");
                } else {
                    console.error("=== EMPIRICAL CHALLENGER: RUNTIME STRESS TESTS FAILED ===");
                }
                console.log("================================================================================");

            } catch (err) {
                console.error("ERROR IN RUNTIME STRESS TEST: " + err);
            } finally {
                Qt.quit();
            }
        }
    }
}
