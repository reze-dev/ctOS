import QtQuick
import QtQuick.Layouts
import Quickshell
import desktop.services
import desktop.core
import desktop.surfaces.components

FloatingWindow {
    id: testWindow
    visible: true
    implicitWidth: 1200
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

    // Measure live components
    Item {
        id: liveMeasureContainer
        visible: true

        // Left Section structure matching AmbientBar
        Rectangle {
            id: liveLeftIsland
            height: Theme.barHeight - 6
            width: liveLeftSection.implicitWidth + Theme.paddingLarge * 2

            RowLayout {
                id: liveLeftSection
                anchors.fill: parent
                anchors.leftMargin: Theme.paddingLarge
                anchors.rightMargin: Theme.paddingLarge
                spacing: Theme.spacingSmall

                Rectangle {
                    Layout.alignment: Qt.AlignVCenter
                    Layout.preferredHeight: 20
                    Layout.preferredWidth: 20
                    Image {
                        source: "components/os-icon.svg"
                        width: 14
                        height: 14
                    }
                }

                Rectangle {
                    Layout.alignment: Qt.AlignVCenter
                    Layout.preferredHeight: 16
                    Layout.preferredWidth: Theme.dividerWidth
                    color: Theme.divider
                }

                WorkspacesWidget {
                    id: liveWorkspaces
                    Layout.alignment: Qt.AlignVCenter
                }

                Rectangle {
                    Layout.alignment: Qt.AlignVCenter
                    Layout.preferredHeight: 16
                    Layout.preferredWidth: Theme.dividerWidth
                    color: Theme.divider
                }

                WindowTitleWidget {
                    id: liveWinTitle
                    Layout.alignment: Qt.AlignVCenter
                    Layout.maximumWidth: 380
                }
            }
        }

        // Dynamic Island
        DynamicIsland {
            id: liveDynamicIsland
        }

        // Right Section structure matching AmbientBar
        Rectangle {
            id: liveRightIsland
            height: Theme.barHeight - 6
            width: liveRightSection.implicitWidth + Theme.paddingLarge * 2

            RowLayout {
                id: liveRightSection
                anchors.fill: parent
                anchors.leftMargin: Theme.paddingLarge
                anchors.rightMargin: Theme.paddingLarge
                spacing: Theme.spacingSmall

                NetworkWidget {
                    Layout.alignment: Qt.AlignVCenter
                }

                Rectangle {
                    Layout.alignment: Qt.AlignVCenter
                    Layout.preferredHeight: 16
                    Layout.preferredWidth: Theme.dividerWidth
                    color: Theme.divider
                }

                VolumeWidget {
                    Layout.alignment: Qt.AlignVCenter
                }

                Rectangle {
                    Layout.alignment: Qt.AlignVCenter
                    Layout.preferredHeight: 16
                    Layout.preferredWidth: Theme.dividerWidth
                    color: Theme.divider
                }

                BatteryWidget {
                    Layout.alignment: Qt.AlignVCenter
                }

                Rectangle {
                    Layout.alignment: Qt.AlignVCenter
                    Layout.preferredHeight: 16
                    Layout.preferredWidth: Theme.dividerWidth
                    color: Theme.divider
                }

                ClockWidget {
                    Layout.alignment: Qt.AlignVCenter
                }

                Rectangle {
                    Layout.alignment: Qt.AlignVCenter
                    Layout.preferredHeight: 16
                    Layout.preferredWidth: Theme.dividerWidth
                    color: Theme.divider
                }

                Rectangle {
                    Layout.alignment: Qt.AlignVCenter
                    Layout.preferredHeight: 20
                    Layout.preferredWidth: 20
                    Text {
                        anchors.centerIn: parent
                        text: "="
                    }
                }
            }
        }
    }

    Timer {
        id: testTimer
        interval: 100
        running: true
        repeat: false
        onTriggered: {
            console.log("================================================================");
            console.log("=== EMPIRICAL CHALLENGER: LIVE MULTI-MONITOR STRESS HARNESS ===");
            console.log("================================================================");

            const leftWidth = liveLeftIsland.width;
            const rightWidth = liveRightIsland.width;
            const compactCenterWidth = liveDynamicIsland.compactWidth; // 120
            const expandedCenterWidth = liveDynamicIsland.expandedWidth; // 300
            const margin = Theme.barPaddingHorizontal; // 8

            console.log("MEASURED DIMENSIONS:");
            console.log("  liveLeftIsland.width     = " + leftWidth + "px");
            console.log("  liveRightIsland.width    = " + rightWidth + "px");
            console.log("  dynamicIsland (compact)  = " + compactCenterWidth + "px");
            console.log("  dynamicIsland (expanded) = " + expandedCenterWidth + "px");
            console.log("  barPaddingHorizontal     = " + margin + "px");

            // Evaluate across resolutions: 2560x1440, 1920x1080, 1366x768, 1280x800
            const resolutions = [
                { name: "2560x1440 (QHD)", width: 2560 },
                { name: "1920x1080 (FHD)", width: 1920 },
                { name: "1366x768  (HD Laptop)", width: 1366 },
                { name: "1280x800  (Compact/WXGA)", width: 1280 }
            ];

            for (let i = 0; i < resolutions.length; ++i) {
                const res = resolutions[i];
                const screenW = res.width;

                // 1. Compact Center Island (120px)
                const centerLeftCompact = (screenW - compactCenterWidth) / 2;
                const centerRightCompact = centerLeftCompact + compactCenterWidth;
                const leftIslandRightEdge = margin + leftWidth;
                const rightIslandLeftEdge = screenW - margin - rightWidth;

                const leftGapCompact = centerLeftCompact - leftIslandRightEdge;
                const rightGapCompact = rightIslandLeftEdge - centerRightCompact;

                assertCondition("MM.COMPACT." + screenW,
                    res.name + " Compact Island Gaps Positive (No Overlap)",
                    leftGapCompact > 0 && rightGapCompact > 0,
                    "leftGap=" + Math.round(leftGapCompact) + "px, rightGap=" + Math.round(rightGapCompact) + "px");

                // 2. Expanded Center Island (300px)
                const centerLeftExpanded = (screenW - expandedCenterWidth) / 2;
                const centerRightExpanded = centerLeftExpanded + expandedCenterWidth;

                const leftGapExpanded = centerLeftExpanded - leftIslandRightEdge;
                const rightGapExpanded = rightIslandLeftEdge - centerRightExpanded;

                assertCondition("MM.EXPANDED." + screenW,
                    res.name + " Expanded Island Gaps Positive (No Overlap)",
                    leftGapExpanded > 0 && rightGapExpanded > 0,
                    "leftGap=" + Math.round(leftGapExpanded) + "px, rightGap=" + Math.round(rightGapExpanded) + "px");
            }

            console.log("================================================================");
            console.log("RESULTS: Passed=" + passCount + ", Failed=" + failCount);
            if (failCount === 0) {
                console.log("=== PASS: ALL MULTI-MONITOR STRESS CHECKS PASSED ===");
            } else {
                console.error("=== FAIL: MULTI-MONITOR STRESS CHECKS FAILED ===");
            }
            console.log("================================================================");

            Qt.quit();
        }
    }
}
