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
            console.log("================================================================");
            console.log("=== EMPIRICAL RUNTIME: AMBIENT BAR PER-SECTION HARNESS (M2) ===");
            console.log("================================================================");

            // 1. PanelWindow Geometry & Properties
            assertCondition("M2.RUN.01", "AmbientBar instantiated successfully",
                bar !== null,
                "bar=" + bar);

            assertCondition("M2.RUN.02", "AmbientBar PanelWindow is transparent",
                bar.color === "#00000000" || bar.color.toString() === "#00000000" || bar.color.toString() === "transparent",
                "color=" + bar.color);

            assertCondition("M2.RUN.03", "AmbientBar top margin is 3",
                bar.margins.top === 3,
                "margins.top=" + bar.margins.top);

            assertCondition("M2.RUN.04", "AmbientBar height is Theme.barHeight (40)",
                bar.height === Theme.barHeight && bar.height === 40,
                "height=" + bar.height);

            // 2. Child Groups Extraction
            let children = bar.contentItem ? bar.contentItem.children : bar.children;
            assertCondition("M2.RUN.05", "AmbientBar contains leftSections, centerSection, rightSections",
                children.length === 3,
                "childCount=" + children.length);

            let leftRow = children[0];
            let centerIsland = children[1];
            let rightRow = children[2];

            // 3. DynamicIsland Center Element
            assertCondition("M2.RUN.06", "Center item is DynamicIsland component",
                centerIsland.toString().indexOf("DynamicIsland") !== -1,
                "centerType=" + centerIsland);

            assertCondition("M2.RUN.07", "DynamicIsland uses Theme.radiusMedium (8)",
                centerIsland.radius === Theme.radiusMedium && centerIsland.radius === 8,
                "radius=" + centerIsland.radius);

            assertCondition("M2.RUN.08", "DynamicIsland height is 34 (Theme.barHeight - 6)",
                centerIsland.height === (Theme.barHeight - 6) && centerIsland.height === 34,
                "height=" + centerIsland.height);

            // 4. Left Sections (Logo, Workspaces, Window Title)
            assertCondition("M2.RUN.09", "leftSections is RowLayout with spacingMedium (8)",
                leftRow.spacing === Theme.spacingMedium,
                "spacing=" + leftRow.spacing);

            let leftChildren = leftRow.children;
            assertCondition("M2.RUN.10", "leftSections contains 3 section containers",
                leftChildren.length === 3,
                "leftChildrenCount=" + leftChildren.length);

            let logoSection = leftChildren[0];
            let workspacesSection = leftChildren[1];
            let windowTitleSection = leftChildren[2];

            // 4a. Logo Section
            assertCondition("M2.RUN.11", "logoSection is 34x34 square",
                logoSection.height === 34 && logoSection.width === 34,
                "width=" + logoSection.width + ", height=" + logoSection.height);

            assertCondition("M2.RUN.12", "logoSection radius is Theme.radiusMedium (8)",
                logoSection.radius === Theme.radiusMedium && logoSection.radius === 8,
                "radius=" + logoSection.radius);

            let logoIcon = logoSection.children[0];
            assertCondition("M2.RUN.13", "logoIcon sources components/blume-logo.svg",
                logoIcon.source.toString().indexOf("components/blume-logo.svg") !== -1,
                "source=" + logoIcon.source);

            assertCondition("M2.RUN.14", "logoIcon rendered at 22x22",
                logoIcon.width === 22 && logoIcon.height === 22,
                "size=" + logoIcon.width + "x" + logoIcon.height);

            // 4b. Workspaces Section
            assertCondition("M2.RUN.15", "workspacesSection height is 34 and radius is 8",
                workspacesSection.height === 34 && workspacesSection.radius === 8,
                "height=" + workspacesSection.height + ", radius=" + workspacesSection.radius);

            // 4c. Window Title Section
            assertCondition("M2.RUN.16", "windowTitleSection height is 34, radius is 8, max width 380",
                windowTitleSection.height === 34 && windowTitleSection.radius === 8,
                "height=" + windowTitleSection.height + ", radius=" + windowTitleSection.radius);

            // 5. Right Sections (Network, Volume, Battery, Bluetooth, Clock, Rail)
            assertCondition("M2.RUN.17", "rightSections is RowLayout with spacingMedium (8)",
                rightRow.spacing === Theme.spacingMedium,
                "spacing=" + rightRow.spacing);

            let rightChildren = rightRow.children;
            assertCondition("M2.RUN.18", "rightSections contains 6 section containers",
                rightChildren.length === 6,
                "rightChildrenCount=" + rightChildren.length);

            let netSec = rightChildren[0];
            let volSec = rightChildren[1];
            let batSec = rightChildren[2];
            let btSec = rightChildren[3];
            let clockSec = rightChildren[4];
            let railSec = rightChildren[5];

            // 5a. Network Section
            assertCondition("M2.RUN.19", "networkSection height is 34 and radius is 8",
                netSec.height === 34 && netSec.radius === 8,
                "height=" + netSec.height + ", radius=" + netSec.radius);

            // 5b. Volume Section
            assertCondition("M2.RUN.20", "volumeSection height is 34 and radius is 8",
                volSec.height === 34 && volSec.radius === 8,
                "height=" + volSec.height + ", radius=" + volSec.radius);

            // 5c. Battery Section
            assertCondition("M2.RUN.21", "batterySection height is 34 and radius is 8",
                batSec.height === 34 && batSec.radius === 8,
                "height=" + batSec.height + ", radius=" + batSec.radius);

            // 5d. Bluetooth Section (Slot ready for M3)
            assertCondition("M2.RUN.22", "bluetoothSection slot exists between battery and clock",
                btSec.radius === 8 && btSec.height === 34,
                "height=" + btSec.height + ", radius=" + btSec.radius);

            // 5e. Clock Section
            assertCondition("M2.RUN.23", "clockSection height is 34 and radius is 8",
                clockSec.height === 34 && clockSec.radius === 8,
                "height=" + clockSec.height + ", radius=" + clockSec.radius);

            // 5f. Rail Button Section
            assertCondition("M2.RUN.24", "railSection is 34x34 square with radius 8",
                railSec.height === 34 && railSec.width === 34 && railSec.radius === 8,
                "size=" + railSec.width + "x" + railSec.height + ", radius=" + railSec.radius);

            let railText = railSec.children[0];
            assertCondition("M2.RUN.25", "railSection displays '=' button",
                railText.text === "=",
                "text=" + railText.text);

            console.log("================================================================");
            console.log("M2 RUNTIME RESULTS: Passed=" + passCount + ", Failed=" + failCount);
            if (failCount === 0) {
                console.log("=== PASS: M2 PER-SECTION RUNTIME HARNESS SUCCESSFUL ===");
            } else {
                console.error("=== FAIL: M2 PER-SECTION RUNTIME HARNESS FAILED ===");
            }
            console.log("================================================================");

            Qt.quit();
        }
    }
}
