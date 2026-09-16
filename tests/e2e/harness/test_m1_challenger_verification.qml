import QtQuick
import QtQuick.Layouts
import Quickshell
import desktop.services
import desktop.core
import desktop.surfaces.components

FloatingWindow {
    id: testWindow
    visible: true
    implicitWidth: 600
    implicitHeight: 800

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

        // Font Probe Elements
        Text {
            id: textProbeMaple
            font.family: Theme.fontFamilyMonospace
            font.pixelSize: Theme.fontSizeSmall
            text: "WWWW"
        }

        Text {
            id: textProbeMapleNarrow
            font.family: Theme.fontFamilyMonospace
            font.pixelSize: Theme.fontSizeSmall
            text: "iiii"
        }

        Text {
            id: textProbeFallback
            // Simulate missing primary font: request non-existent font
            font.family: "NonExistentCyberFont9999"
            font.pixelSize: Theme.fontSizeSmall
            text: "FALLBACK_TEST"
        }

        // Child Bar Widgets at 36px
        Item {
            id: barContainer
            width: 500
            height: Theme.barHeight

            WorkspacesWidget {
                id: wsWidget
            }

            WindowTitleWidget {
                id: winTitleWidget
            }

            NetworkWidget {
                id: netWidget
            }

            VolumeWidget {
                id: volWidget
            }

            BatteryWidget {
                id: batWidget
            }

            ClockWidget {
                id: clkWidget
            }
        }
    }

    Timer {
        interval: 100
        running: true
        repeat: false
        onTriggered: {
            console.log("================================================================");
            console.log("=== EMPIRICAL CHALLENGER VERIFICATION HARNESS (MILESTONE 1) ===");
            console.log("================================================================");

            // 1. Font Tokens in Theme.qml
            assertCondition("CHAL.M1.01", "Theme.fontFamily is Maple Mono",
                Theme.fontFamily === "Maple Mono",
                "Theme.fontFamily=" + Theme.fontFamily);

            assertCondition("CHAL.M1.02", "Theme.fontFamilyMonospace is Maple Mono",
                Theme.fontFamilyMonospace === "Maple Mono",
                "Theme.fontFamilyMonospace=" + Theme.fontFamilyMonospace);

            assertCondition("CHAL.M1.03", "Theme.fontFamilies fallback array starts with Maple Mono",
                Array.isArray(Theme.fontFamilies) && Theme.fontFamilies.length > 0 && Theme.fontFamilies[0] === "Maple Mono",
                "fontFamilies=" + JSON.stringify(Theme.fontFamilies));

            assertCondition("CHAL.M1.04", "Theme.fontFamilies contains robust fallback chain",
                Array.isArray(Theme.fontFamilies) && Theme.fontFamilies.indexOf("monospace") !== -1,
                "fallback count=" + Theme.fontFamilies.length);

            // 2. Empirical Font Resolution
            const resolvedFamily = textProbeMaple.fontInfo.family;
            console.log("Empirical fontInfo for Theme.fontFamilyMonospace:",
                "family=" + resolvedFamily,
                "styleName=" + textProbeMaple.fontInfo.styleName,
                "pixelSize=" + textProbeMaple.fontInfo.pixelSize);

            assertCondition("CHAL.M1.05", "Text element resolves to Maple Mono family",
                resolvedFamily.indexOf("Maple Mono") !== -1,
                "resolvedFamily=" + resolvedFamily);

            // Monospace character advance test: "WWWW" width vs "iiii" width
            const widthWide = textProbeMaple.implicitWidth;
            const widthNarrow = textProbeMapleNarrow.implicitWidth;
            console.log("Character width check: 'WWWW' width=" + widthWide + ", 'iiii' width=" + widthNarrow);
            assertCondition("CHAL.M1.06", "Maple Mono produces true monospace metrics",
                Math.abs(widthWide - widthNarrow) < 0.1,
                "widthWide=" + widthWide + ", widthNarrow=" + widthNarrow);

            // Fallback font resolution test
            const fallbackFamily = textProbeFallback.fontInfo.family;
            console.log("Fallback fontInfo when requesting invalid font:", fallbackFamily);
            assertCondition("CHAL.M1.07", "System falls back to a valid font on missing family",
                fallbackFamily.length > 0,
                "fallbackFamily=" + fallbackFamily);

            // 3. Bar Height Scaling to 36px
            assertCondition("CHAL.M1.08", "Theme.barHeight is exactly 36",
                Theme.barHeight === 36,
                "Theme.barHeight=" + Theme.barHeight);

            assertCondition("CHAL.M1.09", "WorkspacesWidget implicitHeight is 36px",
                wsWidget.implicitHeight === 36,
                "wsWidget.implicitHeight=" + wsWidget.implicitHeight);

            assertCondition("CHAL.M1.10", "WindowTitleWidget implicitHeight is 36px",
                winTitleWidget.implicitHeight === 36,
                "winTitleWidget.implicitHeight=" + winTitleWidget.implicitHeight);

            assertCondition("CHAL.M1.11", "NetworkWidget implicitHeight is 36px",
                netWidget.implicitHeight === 36,
                "netWidget.implicitHeight=" + netWidget.implicitHeight);

            assertCondition("CHAL.M1.12", "VolumeWidget implicitHeight is 36px",
                volWidget.implicitHeight === 36,
                "volWidget.implicitHeight=" + volWidget.implicitHeight);

            assertCondition("CHAL.M1.13", "ClockWidget implicitHeight is 36px",
                clkWidget.implicitHeight === 36,
                "clkWidget.implicitHeight=" + clkWidget.implicitHeight);

            // Check that all child widgets have implicitHeight <= 36 (no vertical overflow)
            const widgets = [wsWidget, winTitleWidget, netWidget, volWidget, clkWidget];
            let allFit = true;
            for (let i = 0; i < widgets.length; i++) {
                if (widgets[i].implicitHeight > 36) {
                    allFit = false;
                }
            }
            assertCondition("CHAL.M1.14", "All tested bar widgets fit within 36px height without overflow",
                allFit,
                "all widgets implicitHeight <= 36");

            console.log("================================================================");
            console.log("RESULTS: Passed=" + passCount + ", Failed=" + failCount);
            if (failCount === 0) {
                console.log("=== PASS: EMPIRICAL CHALLENGER M1 VERIFICATION SUCCESSFUL ===");
            } else {
                console.error("=== FAIL: EMPIRICAL CHALLENGER M1 VERIFICATION FAILED ===");
            }
            console.log("================================================================");

            Qt.quit();
        }
    }
}
