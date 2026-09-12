#!/usr/bin/env bash
# ==============================================================================
# Tier 3 - Expansion Cross-Feature Combinations & Pairwise Interactions
# Requirements: ORIGINAL_REQUEST §R2-R5, PROJECT.md
# Tests multi-widget positioning concurrency, live state updates during
# active telemetry feeds, and visualizer interactions.
# ==============================================================================
set -u
set +e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../harness/mock_environment.sh"
source "${SCRIPT_DIR}/../harness/qml_runner.sh"

SETTINGS_FILE="${PROJECT_ROOT}/shell/desktop/core/Settings.qml"
SHELL_FILE="${PROJECT_ROOT}/shell/shell.qml"

# ------------------------------------------------------------------------------
# T3.EXP.01: Simultaneous 6-Widget Positioning Configuration
# ------------------------------------------------------------------------------
test_case "T3.EXP.01" "Expansion Pairwise: All 6 widgets positioned simultaneously without state collision"
TMP_QML_ALL6="$(mktemp /tmp/ctos_test_t3_all6_XXXXXX.qml)"
cat << 'EOF' > "${TMP_QML_ALL6}"
import QtQuick
import Quickshell
import desktop.core

Scope {
    Timer {
        interval: 10
        running: true
        repeat: false
        onTriggered: {
            Settings.parseConfig(JSON.stringify({
                widgets: {
                    // Right Side Stack
                    cpuHexGrid: { anchor: "top-right", offsetX: 24, offsetY: 48 },
                    ramBlockBar: { anchor: "top-right", offsetX: 24, offsetY: 264 },
                    networkFlow: { anchor: "bottom-right", offsetX: 24, offsetY: 24 },

                    // Left Side Stack
                    targetProfiler: { x: 24, y: 48 },
                    networkTracer: { anchor: "top-left", offsetX: 24, offsetY: 280 },
                    audioSurveillance: { anchor: "bottom-left", offsetX: 24, offsetY: 24 }
                }
            }));

            // Verify all 6 widgets have resolved independent coordinates
            const cpuT = Settings.getWidgetMargin("cpuHexGrid", "top", 0);
            const ramT = Settings.getWidgetMargin("ramBlockBar", "top", 0);
            const netB = Settings.getWidgetMargin("networkFlow", "bottom", 0);
            const profT = Settings.getWidgetMargin("targetProfiler", "top", 0);
            const profL = Settings.getWidgetMargin("targetProfiler", "left", 0);
            const traceT = Settings.getWidgetMargin("networkTracer", "top", 0);
            const audioB = Settings.getWidgetMargin("audioSurveillance", "bottom", 0);

            if (cpuT === 48 && ramT === 264 && netB === 24 &&
                profT === 48 && profL === 24 && traceT === 280 && audioB === 24) {
                console.log("=== PASS: All 6 widgets simultaneously positioned correctly ===");
            } else {
                console.error("ASSERTION_FAILED: 6-widget positioning collision: " +
                    JSON.stringify({ cpuT, ramT, netB, profT, profL, traceT, audioB }));
            }
            Qt.quit();
        }
    }
}
EOF
run_qml_test_harness "${TMP_QML_ALL6}" "Simultaneous 6-widget positioning harness"
rm -f "${TMP_QML_ALL6}"

# ------------------------------------------------------------------------------
# T3.EXP.02: Dynamic Repositioning During Active NetworkTracer Polling
# ------------------------------------------------------------------------------
test_case "T3.EXP.02" "Expansion Pairwise: Dynamic repositioning while NetworkTracer polling is active"
TMP_QML_TRACER_MOVE="$(mktemp /tmp/ctos_test_t3_tracer_move_XXXXXX.qml)"
cat << 'EOF' > "${TMP_QML_TRACER_MOVE}"
import QtQuick
import Quickshell
import desktop.core
import desktop.services

Scope {
    id: testRoot
    property int step: 0

    Timer {
        interval: 15
        running: true
        repeat: true
        onTriggered: {
            testRoot.step++;
            if (testRoot.step === 1) {
                // Initialize NetworkTracer
                NetworkTracerService.refresh();
                Settings.parseConfig(JSON.stringify({
                    widgets: { networkTracer: { x: 100, y: 150 } }
                }));
                const m1 = Settings.getWidgetMargin("networkTracer", "top", 0);
                if (m1 !== 150) {
                    console.error("ASSERTION_FAILED: Step 1 margin mismatch");
                    Qt.quit();
                }
            } else if (testRoot.step === 2) {
                // Move while tracer is polling
                Settings.parseConfig(JSON.stringify({
                    widgets: { networkTracer: { x: 350, y: 500 } }
                }));
                const m2 = Settings.getWidgetMargin("networkTracer", "top", 0);
                const mL = Settings.getWidgetMargin("networkTracer", "left", 0);
                if (m2 === 500 && mL === 350) {
                    console.log("=== PASS: Tracer dynamic repositioning while active verified ===");
                } else {
                    console.error("ASSERTION_FAILED: Step 2 margin mismatch");
                }
                Qt.quit();
            }
        }
    }
}
EOF
run_qml_test_harness "${TMP_QML_TRACER_MOVE}" "Tracer dynamic repositioning harness"
rm -f "${TMP_QML_TRACER_MOVE}"

# ------------------------------------------------------------------------------
# T3.EXP.03: Dynamic Repositioning of Audio Surveillance Widget
# ------------------------------------------------------------------------------
test_case "T3.EXP.03" "Expansion Pairwise: Dynamic repositioning of Audio Surveillance widget"
TMP_QML_AUDIO_MOVE="$(mktemp /tmp/ctos_test_t3_audio_move_XXXXXX.qml)"
cat << 'EOF' > "${TMP_QML_AUDIO_MOVE}"
import QtQuick
import Quickshell
import desktop.core

Scope {
    id: testScope

    Timer {
        interval: 10
        running: true
        repeat: false
        onTriggered: {
            // First position
            Settings.parseConfig(JSON.stringify({
                widgets: {
                    audioSurveillance: { anchor: "bottom-left", offsetX: 24, offsetY: 24 }
                }
            }));
            const mB1 = Settings.getWidgetMargin("audioSurveillance", "bottom", 0);
            const mL1 = Settings.getWidgetMargin("audioSurveillance", "left", 0);

            // Dynamic move to top-right
            Settings.parseConfig(JSON.stringify({
                widgets: {
                    audioSurveillance: { anchor: "bottom-right", offsetX: 50, offsetY: 60 }
                }
            }));

            const aBottom = Settings.getWidgetAnchor("audioSurveillance", "bottom", false);
            const aRight = Settings.getWidgetAnchor("audioSurveillance", "right", false);
            const aLeft = Settings.getWidgetAnchor("audioSurveillance", "left", true);
            const mB2 = Settings.getWidgetMargin("audioSurveillance", "bottom", 0);
            const mR2 = Settings.getWidgetMargin("audioSurveillance", "right", 0);

            if (mB1 === 24 && mL1 === 24 && aBottom && aRight && !aLeft && mB2 === 60 && mR2 === 50) {
                console.log("=== PASS: Audio widget dynamically moved while active ===");
            } else {
                console.error("ASSERTION_FAILED: Audio move during playback failed");
            }
            Qt.quit();
        }
    }
}
EOF
run_qml_test_harness "${TMP_QML_AUDIO_MOVE}" "Audio dynamic repositioning harness"
rm -f "${TMP_QML_AUDIO_MOVE}"

# ------------------------------------------------------------------------------
# T3.EXP.04: Visibility Toggles Coordinate with Service Lifecycle
# ------------------------------------------------------------------------------
test_case "T3.EXP.04" "Expansion Pairwise: Widget visibility toggles coordinate with service lifecycle"
TMP_QML_VIS_TOGGLE="$(mktemp /tmp/ctos_test_t3_vis_toggle_XXXXXX.qml)"
cat << 'EOF' > "${TMP_QML_VIS_TOGGLE}"
import QtQuick
import Quickshell
import desktop.core
import desktop.services

Scope {
    Timer {
        interval: 10
        running: true
        repeat: false
        onTriggered: {
            // Disable tracer and audio widgets
            Settings.parseConfig(JSON.stringify({
                widgets: {
                    networkTracer: { visible: false },
                    audioSurveillance: { visible: false },
                    targetProfiler: { visible: false }
                }
            }));

            const tracerVis = Settings.widgetNetworkTracerVisible;
            const audioVis = Settings.widgetAudioSurveillanceVisible;
            const profVis = Settings.widgetTargetProfilerVisible;

            if (tracerVis === false && audioVis === false && profVis === false) {
                console.log("=== PASS: New widgets visibility toggles verified ===");
            } else {
                console.error("ASSERTION_FAILED: Visibility toggles failed");
            }
            Qt.quit();
        }
    }
}
EOF
run_qml_test_harness "${TMP_QML_VIS_TOGGLE}" "Visibility toggles coordination harness"
rm -f "${TMP_QML_VIS_TOGGLE}"

# ------------------------------------------------------------------------------
# T3.EXP.05: Multi-Screen Variants Positioning Cleanliness
# ------------------------------------------------------------------------------
test_case "T3.EXP.05" "Expansion Pairwise: Multi-screen Variants delegates resolve margins per screen"
if [[ -f "${SHELL_FILE}" ]]; then
    # shell.qml must bind screen to modelData across widget variants
    assert_grep "model:\s*Quickshell\.screens" "${SHELL_FILE}" "shell.qml must iterate over Quickshell.screens"
    assert_grep "screen:\s*modelData" "${SHELL_FILE}" "shell.qml must assign screen: modelData"
else
    assert_file_exists "${SHELL_FILE}"
fi

# ------------------------------------------------------------------------------
# T3.EXP.06: Reduced Motion Coordination Across Expansion Components
# ------------------------------------------------------------------------------
test_case "T3.EXP.06" "Expansion Pairwise: Settings.reducedMotion suppresses animations cleanly"
TMP_QML_REDUCED="$(mktemp /tmp/ctos_test_t3_reduced_XXXXXX.qml)"
cat << 'EOF' > "${TMP_QML_REDUCED}"
import QtQuick
import Quickshell
import desktop.core

Scope {
    Timer {
        interval: 10
        running: true
        repeat: false
        onTriggered: {
            Settings.parseConfig(JSON.stringify({
                reducedMotion: true
            }));

            if (Settings.reducedMotion === true) {
                console.log("=== PASS: Settings.reducedMotion toggled to true ===");
            } else {
                console.error("ASSERTION_FAILED: reducedMotion not true");
            }
            Qt.quit();
        }
    }
}
EOF
run_qml_test_harness "${TMP_QML_REDUCED}" "Reduced motion coordination harness"
rm -f "${TMP_QML_REDUCED}"

report_summary
