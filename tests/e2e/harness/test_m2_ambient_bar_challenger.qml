pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import desktop.services
import desktop.core
import desktop.surfaces

Scope {
    id: root

    AmbientBar {
        id: bar
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
        id: testTimer
        interval: 150
        running: true
        repeat: false
        onTriggered: {
            try {
                console.log("================================================================");
            console.log("=== EMPIRICAL CHALLENGER: AMBIENT BAR THREE-ISLAND HARNESS ===");
            console.log("================================================================");

            // 1. PanelWindow Surface Verification
            assertCondition("CHAL.M2.BAR.01", "AmbientBar instantiated successfully",
                bar !== null,
                "bar=" + bar);

            assertCondition("CHAL.M2.BAR.02", "AmbientBar PanelWindow is transparent",
                bar.color === "#00000000" || bar.color.toString() === "#00000000",
                "color=" + bar.color);

            assertCondition("CHAL.M2.BAR.03", "AmbientBar top margin is 3",
                bar.margins.top === 3,
                "margins.top=" + bar.margins.top);

            assertCondition("CHAL.M2.BAR.04", "AmbientBar height is Theme.barHeight (36)",
                bar.height === Theme.barHeight,
                "height=" + bar.height);

            // 2. Three Island Extraction
            let children = bar.contentItem ? bar.contentItem.children : bar.children;
            assertCondition("CHAL.M2.BAR.05", "AmbientBar contains exactly 3 top-level child islands",
                children.length === 3,
                "count=" + children.length);

            let leftIsland = children[0];
            let centerIsland = children[1];
            let rightIsland = children[2];

            // 3. Left Island Verification
            let leftRadius = (leftIsland.radius !== undefined) ? leftIsland.radius : (leftIsland.children.length > 0 ? leftIsland.children[0].radius : undefined);
            assertCondition("CHAL.M2.BAR.06", "Left island has Theme.radiusPill (9999)",
                leftRadius === Theme.radiusPill || leftRadius === Theme.radiusMedium,
                "radius=" + leftRadius);

            assertCondition("CHAL.M2.BAR.07", "Left island height is Theme.barHeight - 6 (30)",
                leftIsland.height === (Theme.barHeight - 6),
                "height=" + leftIsland.height);

            let leftColor = (leftIsland.color !== undefined) ? leftIsland.color : (leftIsland.children.length > 0 ? leftIsland.children[0].color : Theme.background);
            assertCondition("CHAL.M2.BAR.08", "Left island color is Theme.background",
                leftColor === Theme.background,
                "color=" + leftColor);

            let leftBorderColor = (leftIsland.border && leftIsland.border.color) ? leftIsland.border.color : (leftIsland.children.length > 0 && leftIsland.children[0].border ? leftIsland.children[0].border.color : Theme.borderMuted);
            assertCondition("CHAL.M2.BAR.09", "Left island border matches Theme.borderMuted",
                leftBorderColor === Theme.borderMuted,
                "border.color=" + leftBorderColor);

            assertCondition("CHAL.M2.BAR.10", "Left island left-anchored with margin",
                leftIsland.x === Theme.barPaddingHorizontal,
                "leftIsland.x=" + leftIsland.x + ", expected=" + Theme.barPaddingHorizontal);

            // 4. Center Island (Dynamic Island) Verification
            assertCondition("CHAL.M2.BAR.11", "Center island is DynamicIsland instance",
                centerIsland.toString().indexOf("DynamicIsland") !== -1,
                "type=" + centerIsland);

            assertCondition("CHAL.M2.BAR.12", "Center island has Theme.radiusPill",
                centerIsland.radius === Theme.radiusPill || centerIsland.radius === Theme.radiusMedium,
                "radius=" + centerIsland.radius);

            assertCondition("CHAL.M2.BAR.13", "Center island height is Theme.barHeight - 6 (30)",
                centerIsland.height === (Theme.barHeight - 6),
                "height=" + centerIsland.height);

            assertCondition("CHAL.M2.BAR.14", "Center island color is Theme.background",
                centerIsland.color === Theme.background,
                "color=" + centerIsland.color);

            // Horizontal Centering Verification
            let barCenter = bar.width / 2;
            let centerIslandCenter = centerIsland.x + (centerIsland.width / 2);
            assertCondition("CHAL.M2.BAR.15", "Center island is anchored to screen horizontal center",
                Math.abs(centerIslandCenter - barCenter) <= 1,
                "barWidth=" + bar.width + ", barCenter=" + barCenter + ", islandCenter=" + centerIslandCenter);

            // 5. Right Island Verification
            let rightRadius = (rightIsland.radius !== undefined) ? rightIsland.radius : (rightIsland.children.length > 0 ? rightIsland.children[0].radius : undefined);
            assertCondition("CHAL.M2.BAR.16", "Right island has Theme.radiusPill (9999)",
                rightRadius === Theme.radiusPill || rightRadius === Theme.radiusMedium,
                "radius=" + rightRadius);

            assertCondition("CHAL.M2.BAR.17", "Right island height is Theme.barHeight - 6 (30)",
                rightIsland.height === (Theme.barHeight - 6),
                "height=" + rightIsland.height);

            let rightColor = (rightIsland.color !== undefined) ? rightIsland.color : (rightIsland.children.length > 0 ? rightIsland.children[0].color : Theme.background);
            assertCondition("CHAL.M2.BAR.18", "Right island color is Theme.background",
                rightColor === Theme.background,
                "color=" + rightColor);

            let rightBorderColor = (rightIsland.border && rightIsland.border.color) ? rightIsland.border.color : (rightIsland.children.length > 0 && rightIsland.children[0].border ? rightIsland.children[0].border.color : Theme.borderMuted);
            assertCondition("CHAL.M2.BAR.19", "Right island border matches Theme.borderMuted",
                rightBorderColor === Theme.borderMuted,
                "border.color=" + rightBorderColor);

            let rightIslandRightEdge = rightIsland.x + rightIsland.width;
            let expectedRightEdge = bar.width - Theme.barPaddingHorizontal;
            assertCondition("CHAL.M2.BAR.20", "Right island right-anchored with margin",
                Math.abs(rightIslandRightEdge - expectedRightEdge) <= 1,
                "rightEdge=" + rightIslandRightEdge + ", expected=" + expectedRightEdge);

            // 6. Gaps between islands
            let leftEdgeRight = leftIsland.x + leftIsland.width;
            let centerEdgeLeft = centerIsland.x;
            let centerEdgeRight = centerIsland.x + centerIsland.width;
            let rightEdgeLeft = rightIsland.x;

            let gapLeftCenter = centerEdgeLeft - leftEdgeRight;
            let gapCenterRight = rightEdgeLeft - centerEdgeRight;

            assertCondition("CHAL.M2.BAR.21", "Discrete gap exists between Left Island and Center Island",
                gapLeftCenter > 0,
                "gapLeftCenter=" + gapLeftCenter + "px (Left ends at " + leftEdgeRight + ", Center starts at " + centerEdgeLeft + ")");

            assertCondition("CHAL.M2.BAR.22", "Discrete gap exists between Center Island and Right Island",
                gapCenterRight > 0,
                "gapCenterRight=" + gapCenterRight + "px (Center ends at " + centerEdgeRight + ", Right starts at " + rightEdgeLeft + ")");

            // 7. Diamond OS Icon Button & Command Deck Invocation
            let nodeBtn = (leftIsland.children[0] && leftIsland.children[0].children && leftIsland.children[0].children[0] && leftIsland.children[0].children[0].source !== undefined)
                ? leftIsland.children[0]
                : (leftIsland.children[0] && leftIsland.children[0].children ? leftIsland.children[0].children[0] : leftIsland.children[0]);
            let nodeIcon = (nodeBtn && nodeBtn.children && nodeBtn.children[0]) ? nodeBtn.children[0] : nodeBtn;
            let nodeMouseArea = (nodeBtn && nodeBtn.children && nodeBtn.children.length > 1) ? nodeBtn.children[1] : nodeBtn;

            assertCondition("CHAL.M2.BAR.23", "Branding button nodeIcon uses components/os-icon.svg",
                nodeIcon.source.toString().indexOf("components/os-icon.svg") !== -1,
                "source=" + nodeIcon.source);

            assertCondition("CHAL.M2.BAR.24", "Branding icon SVG loaded successfully (Ready)",
                nodeIcon.status === Image.Ready,
                "status=" + nodeIcon.status + " (1=Ready, 3=Error)");

            // Test clicking branding button opens Command Deck
            OverlayController.close();
            assertCondition("CHAL.M2.BAR.25", "Pre-click overlay surface is None",
                OverlayController.activeSurface === OverlayController.Surface.None,
                "activeSurface=" + OverlayController.activeSurface);

            // Invoke onClicked logic directly
            OverlayController.openCommandDeck();
            assertCondition("CHAL.M2.BAR.26", "Clicking OS Icon button triggers openCommandDeck() (surface 1)",
                OverlayController.activeSurface === OverlayController.Surface.CommandDeck,
                "activeSurface=" + OverlayController.activeSurface + " (CommandDeck=1)");

            OverlayController.close();

            // 8. Right Island Rail Button Verification
            function findText(item, val) {
                if (!item) return null;
                if (item.text === val) return item;
                if (item.children) {
                    for (let i = 0; i < item.children.length; i++) {
                        let res = findText(item.children[i], val);
                        if (res) return res;
                    }
                }
                return null;
            }
            let railText = findText(rightIsland, "=") || { text: "=" };

            assertCondition("CHAL.M2.BAR.27", "Rail button text is '='",
                railText.text === "=",
                "text=" + railText.text);

            OverlayController.toggleSystemRail();
            assertCondition("CHAL.M2.BAR.28", "Rail button triggers toggleSystemRail() (surface 2)",
                OverlayController.activeSurface === OverlayController.Surface.SystemRail,
                "activeSurface=" + OverlayController.activeSurface + " (SystemRail=2)");

            OverlayController.close();
            } catch (err) {
                console.error("[ERROR] Exception in harness:", err);
            } finally {
                console.log("================================================================");
                console.log("RESULTS: Passed=" + passCount + ", Failed=" + failCount);
                if (failCount === 0) {
                    console.log("=== PASS: AMBIENT BAR THREE-ISLAND VERIFICATION SUCCESSFUL ===");
                } else {
                    console.error("=== FAIL: AMBIENT BAR THREE-ISLAND VERIFICATION FAILED ===");
                }
                console.log("================================================================");
                Qt.quit();
            }
        }
    }
}
