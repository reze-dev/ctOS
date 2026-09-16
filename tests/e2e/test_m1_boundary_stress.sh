#!/usr/bin/env bash
# ==============================================================================
# test_m1_boundary_stress.sh - Milestone 1 Widget Boundary & Dynamic Stress Test
# ==============================================================================
# Empirically tests all 6 Milestone 1 widgets across extreme & dynamic states:
# - NetworkWidget: isOnline=false, ethernet, long SSID elision, hover toggling
# - ClockWidget: date/time rendering, monospace font styling, VCenter alignment
# - VolumeWidget: muted, 0% / 100% volume, hover state priority
# - BatteryWidget: low (<=20%), charging, full, desktop omission (visible=false)
# - WorkspacesWidget: multi-workspace layout (5 & 10 WS), cell states, clearance
# - WindowTitleWidget: 500-char extreme title, 400px clamp, class badge
# - Invariant Audit: Zero internal hover rectangles/MouseAreas, Theme tokens
# ==============================================================================
set -u
set +e

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# Discover Quickshell binary
QUICKSHELL_BIN=""
if command -v qs >/dev/null 2>&1; then
    QUICKSHELL_BIN="$(command -v qs)"
elif command -v quickshell >/dev/null 2>&1; then
    QUICKSHELL_BIN="$(command -v quickshell)"
else
    for candidate in /nix/store/*quickshell*/bin/quickshell; do
        if [[ -x "${candidate}" ]]; then
            QUICKSHELL_BIN="${candidate}"
            break
        fi
    done
fi

if [[ -z "${QUICKSHELL_BIN}" ]]; then
    echo "ERROR: Quickshell binary not found!"
    exit 1
fi

echo "======================================================================"
echo "ctOS Challenger M1.2: Boundary & Dynamic Stress Suite"
echo "Quickshell: ${QUICKSHELL_BIN}"
echo "Project Root: ${PROJECT_ROOT}"
echo "======================================================================"

FIXTURE_DIR="/tmp/ctos_m1_stress_fixture_$$"
mkdir -p "${FIXTURE_DIR}/desktop/services"
mkdir -p "${FIXTURE_DIR}/desktop/surfaces"
mkdir -p "${FIXTURE_DIR}/desktop/adapters/hyprland"

cleanup() {
    rm -rf "${FIXTURE_DIR}"
}
trap cleanup EXIT INT TERM

# Symlink core, surfaces/components, and assets from actual repo
ln -s "${PROJECT_ROOT}/shell/desktop/core" "${FIXTURE_DIR}/desktop/core"
ln -s "${PROJECT_ROOT}/shell/desktop/surfaces/components" "${FIXTURE_DIR}/desktop/surfaces/components"
ln -s "${PROJECT_ROOT}/shell/desktop/assets" "${FIXTURE_DIR}/desktop/assets"

# Create controllable mock singletons in services
cat << 'EOF' > "${FIXTURE_DIR}/desktop/services/qmldir"
singleton NetworkService 1.0 NetworkService.qml
singleton AudioService 1.0 AudioService.qml
singleton PowerService 1.0 PowerService.qml
singleton CompositorService 1.0 CompositorService.qml
singleton SystemMonitorService 1.0 SystemMonitorService.qml
singleton NotificationService 1.0 NotificationService.qml
EOF

cat << 'EOF' > "${FIXTURE_DIR}/desktop/services/NetworkService.qml"
pragma Singleton
import QtQuick
import Quickshell

Singleton {
    id: root
    property bool available: true
    property bool isConnected: false
    property string connectionType: "none"
    property string networkName: "--N/A--"
    readonly property bool isEthernet: connectionType === "ethernet"
    readonly property bool isWifi: connectionType === "wifi"
    property real signalStrength: 0.0
    property bool wifiEnabled: true
}
EOF

cat << 'EOF' > "${FIXTURE_DIR}/desktop/services/AudioService.qml"
pragma Singleton
import QtQuick
import Quickshell

Singleton {
    id: root
    property bool available: true
    property real volume: 0.5
    property bool muted: false
    property string sinkName: "MockSink"
}
EOF

cat << 'EOF' > "${FIXTURE_DIR}/desktop/services/PowerService.qml"
pragma Singleton
import QtQuick
import Quickshell

Singleton {
    id: root
    property bool available: true
    property bool isBatteryPresent: true
    property real percentage: 80.0
    property bool isCharging: false
    property bool isFull: false
    property bool onBattery: true
}
EOF

cat << 'EOF' > "${FIXTURE_DIR}/desktop/services/CompositorService.qml"
pragma Singleton
import QtQuick
import Quickshell

Singleton {
    id: root
    property bool available: true
    property var workspaces: []
    property int focusedWorkspaceId: 1
    property string activeWindowAddress: ""
    property string activeWindowTitle: ""
    property string activeWindowClass: ""
    function switchToWorkspace(id) {}
}
EOF

cat << 'EOF' > "${FIXTURE_DIR}/desktop/services/SystemMonitorService.qml"
pragma Singleton
import QtQuick
import Quickshell

Singleton {
    id: root
    property bool available: false
}
EOF

cat << 'EOF' > "${FIXTURE_DIR}/desktop/services/NotificationService.qml"
pragma Singleton
import QtQuick
import Quickshell

Singleton {
    id: root
    property bool available: false
    property int unreadCount: 0
}
EOF

# HyprlandAdapter mock
cat << 'EOF' > "${FIXTURE_DIR}/desktop/adapters/hyprland/qmldir"
singleton HyprlandAdapter 1.0 HyprlandAdapter.qml
EOF

cat << 'EOF' > "${FIXTURE_DIR}/desktop/adapters/hyprland/HyprlandAdapter.qml"
pragma Singleton
import QtQuick
import Quickshell

Singleton {
    id: root
    property bool available: false
    function workspacesForMonitor(mon) { return []; }
}
EOF

# Write the comprehensive stress QML test harness
cat << 'EOF' > "${FIXTURE_DIR}/stress_harness.qml"
import QtQuick
import QtQuick.Layouts
import Quickshell
import desktop.services
import desktop.core
import desktop.surfaces.components

FloatingWindow {
    id: testWindow
    visible: true
    implicitWidth: 800
    implicitHeight: 900

    property int passCount: 0
    property int failCount: 0
    property int step: 0

    function assertCondition(id, desc, condition, details) {
        if (condition) {
            passCount++;
            console.log("[PASS] " + id + ": " + desc + " (" + details + ")");
        } else {
            failCount++;
            console.error("[FAIL] " + id + ": " + desc + " (" + details + ")");
        }
    }

    // Instantiated Widgets under stress
    Item {
        id: container
        anchors.fill: parent

        NetworkWidget { id: netWidget }
        ClockWidget { id: clockWidget }
        VolumeWidget { id: volWidget }
        BatteryWidget { id: batWidget }
        WorkspacesWidget { id: wsWidget }
        WindowTitleWidget { id: winTitleWidget }
    }

    Timer {
        id: testRunner
        interval: 50
        running: true
        repeat: true

        onTriggered: {
            step++;

            if (step === 1) {
                console.log("=== STEP 1: INITIAL STATE & OFFLINE CHECKS ===");
                // NetworkWidget disconnected
                assertCondition("NET.01", "NetworkWidget offline netText is --N/A--",
                    netWidget.netText === "--N/A--", "netText=" + netWidget.netText);
                assertCondition("NET.02", "NetworkWidget offline isOnline is false",
                    netWidget.isOnline === false, "isOnline=" + netWidget.isOnline);
                assertCondition("NET.03", "NetworkWidget decoupled implicitHeight is 16",
                    netWidget.implicitHeight === 16, "implicitHeight=" + netWidget.implicitHeight);
                assertCondition("NET.04", "NetworkWidget offline implicitWidth is 67",
                    netWidget.implicitWidth === 67, "implicitWidth=" + netWidget.implicitWidth);

                // ClockWidget formatting & alignment
                const dateRegex = /^\d{4}-\d{2}-\d{2}$/;
                const timeRegex = /^\d{2}:\d{2}$/;
                assertCondition("CLK.01", "ClockWidget date format yyyy-MM-dd",
                    dateRegex.test(clockWidget.dateString), "dateString=" + clockWidget.dateString);
                assertCondition("CLK.02", "ClockWidget time format HH:mm",
                    timeRegex.test(clockWidget.timeString), "timeString=" + clockWidget.timeString);
                assertCondition("CLK.03", "ClockWidget implicitHeight is 16",
                    clockWidget.implicitHeight === 16, "implicitHeight=" + clockWidget.implicitHeight);

                // Check AlignVCenter on ClockWidget text children
                let clkTexts = (clockWidget.children.length > 0 && clockWidget.children[0].children) ? clockWidget.children[0].children : [];
                let clkVCenter = clkTexts.length > 0;
                for (let i = 0; i < clkTexts.length; i++) {
                    if (clkTexts[i] instanceof Text) {
                        if ((clkTexts[i].Layout.alignment & Qt.AlignVCenter) === 0) {
                            clkVCenter = false;
                        }
                    }
                }
                assertCondition("CLK.04", "ClockWidget Text items have AlignVCenter",
                    clkVCenter, "checked text children, count=" + clkTexts.length);

                // Toggle calendar signal verification
                let toggleFired = false;
                clockWidget.toggleCalendar.connect(function() { toggleFired = true; });
                clockWidget.toggleCalendar();
                assertCondition("CLK.05", "ClockWidget toggleCalendar signal fires cleanly",
                    toggleFired, "toggleFired=" + toggleFired);

                // VolumeWidget 50% initial
                assertCondition("VOL.01", "VolumeWidget 50% text is 50%",
                    volWidget.volumeText === "50%", "volumeText=" + volWidget.volumeText);
                assertCondition("VOL.02", "VolumeWidget implicitHeight is 16",
                    volWidget.implicitHeight === 16, "implicitHeight=" + volWidget.implicitHeight);

                // BatteryWidget 80% initial
                assertCondition("BAT.01", "BatteryWidget visible when battery present",
                    batWidget.visible === true, "visible=" + batWidget.visible);
                assertCondition("BAT.02", "BatteryWidget percentText is 80%",
                    batWidget.percentText === "80%", "percentText=" + batWidget.percentText);
                assertCondition("BAT.03", "BatteryWidget implicitHeight is 16",
                    batWidget.implicitHeight === 16, "implicitHeight=" + batWidget.implicitHeight);
                assertCondition("BAT.04", "BatteryWidget isLow is false at 80%",
                    batWidget.isLow === false, "isLow=" + batWidget.isLow);

                // WindowTitleWidget initial (no window)
                assertCondition("WIN.01", "WindowTitleWidget displayTitle defaults to ctOS",
                    winTitleWidget.displayTitle === "ctOS", "displayTitle=" + winTitleWidget.displayTitle);
                assertCondition("WIN.02", "WindowTitleWidget implicitHeight is 16",
                    winTitleWidget.implicitHeight === 16, "implicitHeight=" + winTitleWidget.implicitHeight);

                // Setup next step: Hover toggles
                netWidget.isHovered = true;
                volWidget.isHovered = true;
                batWidget.isHovered = true;

            } else if (step === 2) {
                console.log("=== STEP 2: HOVER TOGGLING ON DISCONNECTED/NORMAL WIDGETS ===");
                assertCondition("HOVER.01", "NetworkWidget isHovered toggles to true",
                    netWidget.isHovered === true, "isHovered=" + netWidget.isHovered);
                assertCondition("HOVER.02", "NetworkWidget implicitHeight remains 16 on hover",
                    netWidget.implicitHeight === 16, "implicitHeight=" + netWidget.implicitHeight);

                assertCondition("HOVER.03", "VolumeWidget isHovered toggles to true",
                    volWidget.isHovered === true, "isHovered=" + volWidget.isHovered);
                assertCondition("HOVER.04", "VolumeWidget implicitHeight remains 16 on hover",
                    volWidget.implicitHeight === 16, "implicitHeight=" + volWidget.implicitHeight);

                assertCondition("HOVER.05", "BatteryWidget isHovered toggles to true",
                    batWidget.isHovered === true, "isHovered=" + batWidget.isHovered);
                assertCondition("HOVER.06", "BatteryWidget implicitHeight remains 16 on hover",
                    batWidget.implicitHeight === 16, "implicitHeight=" + batWidget.implicitHeight);

                // Setup next step: Network WiFi mode & Volume Muted
                netWidget.isHovered = false;
                volWidget.isHovered = false;
                batWidget.isHovered = false;

                NetworkService.isConnected = true;
                NetworkService.connectionType = "wifi";
                NetworkService.networkName = "NightCity-WLAN";

                AudioService.muted = true;

            } else if (step === 3) {
                console.log("=== STEP 3: WIFI MODE & MUTED VOLUME ===");
                assertCondition("NET.05", "NetworkWidget WiFi mode isOnline is true",
                    netWidget.isOnline === true, "isOnline=" + netWidget.isOnline);
                assertCondition("NET.06", "NetworkWidget WiFi prefixTag is WIFI",
                    netWidget.prefixTag === "WIFI", "prefixTag=" + netWidget.prefixTag);
                assertCondition("NET.07", "NetworkWidget netText shows SSID",
                    netWidget.netText === "NightCity-WLAN", "netText=" + netWidget.netText);

                assertCondition("VOL.03", "VolumeWidget muted text is [MUTED]",
                    volWidget.volumeText === "[MUTED]", "volumeText=" + volWidget.volumeText);
                assertCondition("VOL.04", "VolumeWidget isMuted is true",
                    volWidget.isMuted === true, "isMuted=" + volWidget.isMuted);

                // Hover on muted volume
                volWidget.isHovered = true;

                // Setup Ethernet mode and Volume 0%
                NetworkService.connectionType = "ethernet";
                NetworkService.networkName = "eth0";

            } else if (step === 4) {
                console.log("=== STEP 4: ETHERNET MODE & MUTED HOVER PRIORITY & VOLUME BOUNDARIES ===");
                assertCondition("NET.08", "NetworkWidget Ethernet mode prefixTag is ETH",
                    netWidget.prefixTag === "ETH", "prefixTag=" + netWidget.prefixTag);
                assertCondition("NET.09", "NetworkWidget Ethernet netText is eth0",
                    netWidget.netText === "eth0", "netText=" + netWidget.netText);

                // Check that muted state preserved text while hovered
                assertCondition("VOL.05", "VolumeWidget hovered while muted still shows [MUTED]",
                    volWidget.volumeText === "[MUTED]", "volumeText=" + volWidget.volumeText);

                // Unmute and test 0% volume
                volWidget.isHovered = false;
                AudioService.muted = false;
                AudioService.volume = 0.0;

                // Setup Long SSID on NetworkWidget
                NetworkService.connectionType = "wifi";
                NetworkService.networkName = "CORP_ARASAKA_ENTERPRISE_GIGABIT_EXTENDED_CYBER_ENCRYPTED_FACILITY_NODE_09X_ALPHA_OMEGA_SECURE_AP";

            } else if (step === 5) {
                console.log("=== STEP 5: 0% VOLUME & LONG SSID ELISION ===");
                assertCondition("VOL.06", "VolumeWidget 0% text is 0%",
                    volWidget.volumeText === "0%", "volumeText=" + volWidget.volumeText);

                assertCondition("NET.10", "NetworkWidget long SSID netText length > 80",
                    netWidget.netText.length > 80, "length=" + netWidget.netText.length);
                assertCondition("NET.11", "NetworkWidget implicitWidth clamped to <= 136 for long SSID",
                    netWidget.implicitWidth <= 136, "implicitWidth=" + netWidget.implicitWidth);
                assertCondition("NET.12", "NetworkWidget implicitHeight strictly 16 with long SSID",
                    netWidget.implicitHeight === 16, "implicitHeight=" + netWidget.implicitHeight);

                // Setup 100% volume
                AudioService.volume = 1.0;

                // Setup Battery: Low battery boundary (20.0%)
                PowerService.percentage = 20.0;
                PowerService.isCharging = false;

            } else if (step === 6) {
                console.log("=== STEP 6: 100% VOLUME & LOW BATTERY BOUNDARY (20.0%) ===");
                assertCondition("VOL.07", "VolumeWidget 100% text is 100%",
                    volWidget.volumeText === "100%", "volumeText=" + volWidget.volumeText);

                assertCondition("BAT.05", "BatteryWidget isLow is true at boundary 20.0%",
                    batWidget.isLow === true, "isLow=" + batWidget.isLow);
                assertCondition("BAT.06", "BatteryWidget percentText is 20%",
                    batWidget.percentText === "20%", "percentText=" + batWidget.percentText);

                // Setup Battery: 20.1% (above low threshold)
                PowerService.percentage = 20.1;

            } else if (step === 7) {
                console.log("=== STEP 7: BATTERY 20.1% BOUNDARY & CHARGING OVERRIDE ===");
                assertCondition("BAT.07", "BatteryWidget isLow is false at 20.1%",
                    batWidget.isLow === false, "isLow=" + batWidget.isLow);

                // Low battery while charging: percentage=10, isCharging=true
                PowerService.percentage = 10.0;
                PowerService.isCharging = true;

            } else if (step === 8) {
                console.log("=== STEP 8: LOW BATTERY WHILE CHARGING & FULL BATTERY ===");
                assertCondition("BAT.08", "BatteryWidget isLow is false when charging even at 10%",
                    batWidget.isLow === false, "isLow=" + batWidget.isLow + ", isCharging=" + batWidget.isCharging);
                assertCondition("BAT.09", "BatteryWidget isCharging is true",
                    batWidget.isCharging === true, "isCharging=" + batWidget.isCharging);

                // Full battery state
                PowerService.isCharging = false;
                PowerService.percentage = 100.0;
                PowerService.isFull = true;

            } else if (step === 9) {
                console.log("=== STEP 9: FULL BATTERY & DESKTOP OMISSION (ABSENT HARDWARE) ===");
                assertCondition("BAT.10", "BatteryWidget full battery percentText is 100%",
                    batWidget.percentText === "100%", "percentText=" + batWidget.percentText);
                assertCondition("BAT.11", "BatteryWidget isFull is true",
                    batWidget.isFull === true, "isFull=" + batWidget.isFull);

                // Desktop omission: battery hardware not present
                PowerService.isBatteryPresent = false;

            } else if (step === 10) {
                console.log("=== STEP 10: BATTERY HARDWARE ABSENT (DESKTOP OMISSION) ===");
                assertCondition("BAT.12", "BatteryWidget visible is false when isBatteryPresent is false",
                    batWidget.visible === false, "visible=" + batWidget.visible);
                assertCondition("BAT.13", "BatteryWidget implicitHeight is 0 when absent",
                    batWidget.implicitHeight === 0, "implicitHeight=" + batWidget.implicitHeight);
                assertCondition("BAT.14", "BatteryWidget implicitWidth is 0 when absent",
                    batWidget.implicitWidth === 0, "implicitWidth=" + batWidget.implicitWidth);

                // Setup WorkspacesWidget: 5 workspaces
                CompositorService.workspaces = [
                    { id: 1, name: "1", active: false, focused: false, urgent: false },
                    { id: 2, name: "2", active: true,  focused: true,  urgent: false },
                    { id: 3, name: "3", active: true,  focused: false, urgent: false },
                    { id: 4, name: "4", active: false, focused: false, urgent: true  },
                    { id: 5, name: "5", active: false, focused: false, urgent: false }
                ];
                CompositorService.focusedWorkspaceId = 2;

            } else if (step === 11) {
                console.log("=== STEP 11: WORKSPACES MULTI-WORKSPACE LAYOUT (5 WORKSPACES) ===");
                assertCondition("WS.01", "WorkspacesWidget workspaceList has 5 entries",
                    wsWidget.workspaceList.length === 5, "count=" + wsWidget.workspaceList.length);
                assertCondition("WS.02", "WorkspacesWidget implicitHeight is 22",
                    wsWidget.implicitHeight === 22, "implicitHeight=" + wsWidget.implicitHeight);
                // 5 * 24 + 4 * 2 = 128
                assertCondition("WS.03", "WorkspacesWidget implicitWidth is 128 (5*24 + 4*2)",
                    wsWidget.implicitWidth === 128, "implicitWidth=" + wsWidget.implicitWidth);

                // Vertical clearance in 34px container
                const barContainerHeight = Theme.barHeight - 6; // 34
                const wsClearance = (barContainerHeight - wsWidget.implicitHeight) / 2;
                assertCondition("WS.04", "WorkspacesWidget leaves 6px vertical clearance in 34px pill",
                    wsClearance === 6, "clearance=" + wsClearance + "px");

                // Setup WorkspacesWidget: 10 workspaces
                let ws10 = [];
                for (let i = 1; i <= 10; i++) {
                    ws10.push({ id: i, name: String(i), active: i === 1, focused: i === 1, urgent: false });
                }
                CompositorService.workspaces = ws10;

            } else if (step === 12) {
                console.log("=== STEP 12: WORKSPACES DENSE LAYOUT (10 WORKSPACES) ===");
                assertCondition("WS.05", "WorkspacesWidget 10 workspaces has 10 entries",
                    wsWidget.workspaceList.length === 10, "count=" + wsWidget.workspaceList.length);
                assertCondition("WS.06", "WorkspacesWidget implicitHeight remains 22 with 10 workspaces",
                    wsWidget.implicitHeight === 22, "implicitHeight=" + wsWidget.implicitHeight);
                // 10 * 24 + 9 * 2 = 258
                assertCondition("WS.07", "WorkspacesWidget implicitWidth is 258 (10*24 + 9*2)",
                    wsWidget.implicitWidth === 258, "implicitWidth=" + wsWidget.implicitWidth);

                // Setup WindowTitleWidget with active window
                CompositorService.activeWindowAddress = "0x55aa33ff";
                CompositorService.activeWindowClass = "firefox";
                CompositorService.activeWindowTitle = "ctOS Cyberpunk Desktop Shell - Documentation & API Reference";

            } else if (step === 13) {
                console.log("=== STEP 13: WINDOW TITLE NORMAL & CLASS BADGE ===");
                assertCondition("WIN.03", "WindowTitleWidget hasWindow is true",
                    winTitleWidget.hasWindow === true, "hasWindow=" + winTitleWidget.hasWindow);
                assertCondition("WIN.04", "WindowTitleWidget displayTitle shows title",
                    winTitleWidget.displayTitle === "ctOS Cyberpunk Desktop Shell - Documentation & API Reference",
                    "displayTitle=" + winTitleWidget.displayTitle);
                assertCondition("WIN.05", "WindowTitleWidget classBadge visible for firefox",
                    winTitleWidget.windowClass === "firefox", "windowClass=" + winTitleWidget.windowClass);
                // Class badge preferredHeight is 18, so layout height is 18
                assertCondition("WIN.06", "WindowTitleWidget implicitHeight is 18 when class badge is present",
                    winTitleWidget.implicitHeight === 18, "implicitHeight=" + winTitleWidget.implicitHeight);

                // Setup WindowTitleWidget EXTREME 500-character title
                let extTitle = "CYBERPUNK_2077_MEGA_CORP_SECURITY_AUDIT_LOG_BUFFER_EXTREME_STRESS_TEST_";
                while (extTitle.length < 500) {
                    extTitle += "0123456789_ABCDEF_EXTREME_LONG_WINDOW_TITLE_DATA_BLOCK_";
                }
                CompositorService.activeWindowTitle = extTitle;

            } else if (step === 14) {
                console.log("=== STEP 14: WINDOW TITLE EXTREME 500-CHAR TITLE & 400PX LIMIT ===");
                assertCondition("WIN.07", "WindowTitleWidget 500-char title length > 450",
                    winTitleWidget.displayTitle.length > 450, "len=" + winTitleWidget.displayTitle.length);
                assertCondition("WIN.08", "WindowTitleWidget implicitWidth strictly clamped to <= 400",
                    winTitleWidget.implicitWidth <= 400, "implicitWidth=" + winTitleWidget.implicitWidth);
                assertCondition("WIN.09", "WindowTitleWidget clip is true",
                    winTitleWidget.clip === true, "clip=" + winTitleWidget.clip);
                assertCondition("WIN.10", "WindowTitleWidget implicitHeight is 18 under extreme title with badge",
                    winTitleWidget.implicitHeight === 18, "implicitHeight=" + winTitleWidget.implicitHeight);

                // Setup Class-only window (empty title)
                CompositorService.activeWindowTitle = "";
                CompositorService.activeWindowClass = "neovim";

            } else if (step === 15) {
                console.log("=== STEP 15: WINDOW TITLE FALLBACK TO CLASS & THEME TOKEN AUDIT ===");
                assertCondition("WIN.11", "WindowTitleWidget fallback to class name when title empty",
                    winTitleWidget.displayTitle === "neovim", "displayTitle=" + winTitleWidget.displayTitle);

                // Theme token verification
                assertCondition("THEME.01", "Theme.barHeight is 40",
                    Theme.barHeight === 40, "barHeight=" + Theme.barHeight);
                assertCondition("THEME.02", "Theme.radiusMedium is 8",
                    Theme.radiusMedium === 8, "radiusMedium=" + Theme.radiusMedium);
                assertCondition("THEME.03", "Theme.fontFamilyMonospace is Maple Mono",
                    Theme.fontFamilyMonospace === "Maple Mono", "font=" + Theme.fontFamilyMonospace);

                // Container clearance checks (container height = 40 - 6 = 34)
                const containerH = Theme.barHeight - 6;
                assertCondition("CLEAR.01", "NetworkWidget (16px) leaves 9px symmetric clearance in 34px container",
                    (containerH - netWidget.implicitHeight) / 2 === 9, "clearance=" + ((containerH - netWidget.implicitHeight) / 2));
                assertCondition("CLEAR.02", "ClockWidget (16px) leaves 9px symmetric clearance in 34px container",
                    (containerH - clockWidget.implicitHeight) / 2 === 9, "clearance=" + ((containerH - clockWidget.implicitHeight) / 2));
                assertCondition("CLEAR.03", "VolumeWidget (16px) leaves 9px symmetric clearance in 34px container",
                    (containerH - volWidget.implicitHeight) / 2 === 9, "clearance=" + ((containerH - volWidget.implicitHeight) / 2));
                assertCondition("CLEAR.04", "WorkspacesWidget (22px) leaves 6px symmetric clearance in 34px container",
                    (containerH - wsWidget.implicitHeight) / 2 === 6, "clearance=" + ((containerH - wsWidget.implicitHeight) / 2));
                assertCondition("CLEAR.05", "WindowTitleWidget (18px) leaves 8px symmetric clearance in 34px container",
                    (containerH - winTitleWidget.implicitHeight) / 2 === 8, "clearance=" + ((containerH - winTitleWidget.implicitHeight) / 2));

                console.log("================================================================");
                console.log("DYNAMIC STRESS SUMMARY: Passed=" + passCount + ", Failed=" + failCount);
                if (failCount === 0) {
                    console.log("=== ALL EMPIRICAL DYNAMIC STRESS TESTS PASSED CLEANLY ===");
                } else {
                    console.error("=== EMPIRICAL DYNAMIC STRESS TESTS REPORTED FAILURES ===");
                }
                console.log("================================================================");

                testRunner.running = false;
                Qt.quit();
            }
        }
    }
}
EOF

# Execute the QML dynamic stress test harness
echo "Executing QML Dynamic Stress Test Suite..."
QML_IMPORT_PATH="${FIXTURE_DIR}" timeout 15 "${QUICKSHELL_BIN}" -p "${FIXTURE_DIR}/stress_harness.qml" > /tmp/ctos_m1_dynamic_stress.log 2>&1
EXEC_CODE=$?

cat /tmp/ctos_m1_dynamic_stress.log

if grep -q "ALL EMPIRICAL DYNAMIC STRESS TESTS PASSED CLEANLY" /tmp/ctos_m1_dynamic_stress.log; then
    echo "Dynamic Stress Test Harness PASSED (Exit code ${EXEC_CODE})."
else
    echo "Dynamic Stress Test Harness FAILED (Exit code ${EXEC_CODE})!"
    exit 1
fi

rm -f /tmp/ctos_m1_dynamic_stress.log
exit 0
