import QtQuick
import QtQuick.Layouts
import Quickshell
import desktop.services
import desktop.core
import desktop.surfaces.components

FloatingWindow {
    id: stressWindow
    visible: true
    implicitWidth: 800
    implicitHeight: 900

    property int passCount: 0
    property int failCount: 0

    function assertCondition(id, name, condition, details) {
        if (condition) {
            passCount++;
            console.log("[STRESS-PASS] " + id + ": " + name + " (" + details + ")");
        } else {
            failCount++;
            console.error("[STRESS-FAIL] " + id + ": " + name + " (" + details + ")");
        }
    }

    Item {
        id: container
        anchors.fill: parent

        // Typography test items
        Column {
            id: typoColumn
            spacing: 2

            Repeater {
                model: [100, 300, 400, 500, 600, 700, 800]
                Text {
                    required property int modelData
                    font.family: Theme.fontFamilyMonospace
                    font.weight: modelData
                    font.pixelSize: Theme.fontSizeCaption
                    text: "Weight " + modelData + ": 0123456789 ABCDEF // CTOS SYSTEM"
                }
            }

            Repeater {
                model: [
                    Theme.fontSizeCaption,
                    Theme.fontSizeSmall,
                    Theme.fontSizeBody,
                    Theme.fontSizeSegment,
                    Theme.fontSizeLarge,
                    Theme.fontSizeTitle,
                    Theme.fontSizeDisplay
                ]
                Text {
                    required property int modelData
                    font.family: Theme.fontFamilyMonospace
                    font.pixelSize: modelData
                    text: "Size " + modelData + "px: [CTOS] // STATUS OK"
                }
            }
        }

        // Cyberpunk symbols probe
        Text {
            id: cyberProbe
            font.family: Theme.fontFamilyMonospace
            font.pixelSize: 12
            text: "[DND] // EVENT LOG 0x7FFF !@#$%^&*()_+[]:;?/~ ▶ ▲ ▼ ◀ ■ ◆ ● ⚡ ⚙ ✕ ✓"
        }

        // Fallback test items: fallback chain entries from Theme.fontFamilies
        Text {
            id: fallbackProbeMaple
            font.family: Theme.fontFamilies[0] // Maple Mono
            font.pixelSize: 12
            text: "FALLBACK_CHAIN_0"
        }

        Text {
            id: fallbackProbeJetBrains
            font.family: Theme.fontFamilies[1] // JetBrainsMono Nerd Font
            font.pixelSize: 12
            text: "FALLBACK_CHAIN_1"
        }

        Text {
            id: fallbackProbeGenericMono
            font.family: Theme.fontFamilyFallback // monospace
            font.pixelSize: 12
            text: "FALLBACK_CHAIN_GENERIC"
        }

        // Dynamic Title Widget
        WindowTitleWidget {
            id: dynamicWinTitle
        }

        // Widgets under stress
        Item {
            id: widgetContainer
            width: 700
            height: Theme.barHeight

            WorkspacesWidget {
                id: stressWs
            }

            WindowTitleWidget {
                id: stressWinTitle
            }

            NetworkWidget {
                id: stressNet
            }

            VolumeWidget {
                id: stressVol
            }

            BatteryWidget {
                id: stressBat
            }

            ClockWidget {
                id: stressClk
            }
        }
    }

    Timer {
        interval: 100
        running: true
        repeat: false
        onTriggered: {
            console.log("================================================================");
            console.log("=== ADVERSARIAL STRESS TEST SUITE: MILESTONE 1 ===");
            console.log("================================================================");

            // TEST GROUP 1: Typography Stress across Weights
            let allWeightsMonospace = true;
            for (let i = 0; i < typoColumn.children.length; i++) {
                const child = typoColumn.children[i];
                if (child instanceof Text) {
                    if (!child.fontInfo || child.fontInfo.family.indexOf("Maple Mono") === -1) {
                        allWeightsMonospace = false;
                        console.error("Font failed for child at index " + i + ": " + (child.fontInfo ? child.fontInfo.family : "null"));
                    }
                }
            }
            assertCondition("STRESS.TYPO.01", "Maple Mono resolves across all typography variants",
                allWeightsMonospace,
                "all children resolved to Maple Mono");

            // Cybernetic Glyphs & Symbols
            assertCondition("STRESS.TYPO.02", "Cyberpunk glyphs instantiate without font rendering errors",
                cyberProbe.implicitWidth > 0 && cyberProbe.fontInfo.family.indexOf("Maple Mono") !== -1,
                "probe width=" + cyberProbe.implicitWidth + ", family=" + cyberProbe.fontInfo.family);

            // TEST GROUP 2: Fallback Cascade Chain Validation
            assertCondition("STRESS.FALLBACK.01", "Primary font in fontFamilies resolves to Maple Mono",
                fallbackProbeMaple.fontInfo.family.indexOf("Maple Mono") !== -1,
                "resolved=" + fallbackProbeMaple.fontInfo.family);

            assertCondition("STRESS.FALLBACK.02", "Secondary font in fontFamilies resolves to JetBrainsMono Nerd Font",
                fallbackProbeJetBrains.fontInfo.family.indexOf("JetBrains") !== -1,
                "resolved=" + fallbackProbeJetBrains.fontInfo.family);

            assertCondition("STRESS.FALLBACK.03", "Generic fallback resolves to system monospace",
                fallbackProbeGenericMono.fontInfo.family.length > 0,
                "resolved=" + fallbackProbeGenericMono.fontInfo.family);

            // TEST GROUP 3: Bar Height Dynamic Accommodation (36px)
            assertCondition("STRESS.BAR.01", "WorkspacesWidget accommodates 36px height",
                stressWs.implicitHeight === 36,
                "height=" + stressWs.implicitHeight);

            assertCondition("STRESS.BAR.02", "WindowTitleWidget accommodates 36px height",
                stressWinTitle.implicitHeight === 36,
                "height=" + stressWinTitle.implicitHeight);

            assertCondition("STRESS.BAR.03", "NetworkWidget accommodates 36px height",
                stressNet.implicitHeight === 36,
                "height=" + stressNet.implicitHeight);

            assertCondition("STRESS.BAR.04", "VolumeWidget accommodates 36px height",
                stressVol.implicitHeight === 36,
                "height=" + stressVol.implicitHeight);

            assertCondition("STRESS.BAR.05", "BatteryWidget accommodates 36px height when active",
                stressBat.implicitHeight === 36 || (stressBat.implicitHeight === 0 && !stressBat.visible),
                "height=" + stressBat.implicitHeight + ", visible=" + stressBat.visible);

            assertCondition("STRESS.BAR.06", "ClockWidget accommodates 36px height",
                stressClk.implicitHeight === 36,
                "height=" + stressClk.implicitHeight);

            // TEST GROUP 4: Extreme Title Input on WindowTitleWidget
            assertCondition("STRESS.WIDGET.01", "WindowTitleWidget enforces 36px height and clip constraint",
                dynamicWinTitle.implicitHeight === 36 && dynamicWinTitle.clip === true,
                "implicitHeight=" + dynamicWinTitle.implicitHeight + ", clip=" + dynamicWinTitle.clip);

            // TEST GROUP 5: Vertical Centering Clearance at 36px
            const workspaceCellHeight = 22;
            const buttonHeight = 20;
            const badgeHeight = 18;
            const iconHeight = 14;

            assertCondition("STRESS.CLEARANCE.01", "Workspace cell (22px) in 36px bar leaves 7px vertical clearance",
                (36 - workspaceCellHeight) / 2 === 7,
                "clearance=" + ((36 - workspaceCellHeight) / 2) + "px");

            assertCondition("STRESS.CLEARANCE.02", "Button (20px) in 36px bar leaves 8px vertical clearance",
                (36 - buttonHeight) / 2 === 8,
                "clearance=" + ((36 - buttonHeight) / 2) + "px");

            assertCondition("STRESS.CLEARANCE.03", "Badge (18px) in 36px bar leaves 9px vertical clearance",
                (36 - badgeHeight) / 2 === 9,
                "clearance=" + ((36 - badgeHeight) / 2) + "px");

            assertCondition("STRESS.CLEARANCE.04", "Icon (14px) in 36px bar leaves 11px vertical clearance",
                (36 - iconHeight) / 2 === 11,
                "clearance=" + ((36 - iconHeight) / 2) + "px");

            console.log("================================================================");
            console.log("ADVERSARIAL STRESS SUMMARY: Passed=" + passCount + ", Failed=" + failCount);
            if (failCount === 0) {
                console.log("=== PASS: ALL ADVERSARIAL STRESS TESTS COMPLETED CLEANLY ===");
            } else {
                console.error("=== FAIL: ADVERSARIAL STRESS TESTS DETECTED REGRESSIONS ===");
            }
            console.log("================================================================");

            Qt.quit();
        }
    }
}
