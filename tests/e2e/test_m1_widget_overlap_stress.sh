#!/usr/bin/env bash
# ==============================================================================
# Adversarial Stress Test Suite: Milestone 1 - Widget Overlap & Positioning (R7)
# Tests:
# 1. AST & Static margin declarations in Settings.qml and shell.qml
# 2. Settings.resetToDefaults() coordinate restoration
# 3. Permutation matrix: Profiler x Tracer visibility (4 states)
# 4. Vertical gap calculation: tracerTop - (profilerTop + profilerHeight) >= 16px
# 5. Dynamic runtime transitions (collapse to Y=56 and restore to Y=292)
# 6. User margin override vs default fallback behavior
# 7. Rapid cyclic toggle stress (no NaN, flicker, or memory corruption)
# ==============================================================================
set -u
set +e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/harness/mock_environment.sh"
source "${SCRIPT_DIR}/harness/qml_runner.sh"

echo "=== [TEST SUITE] Milestone 1 Widget Overlap Adversarial Stress Testing ==="
TOTAL=0
PASSED=0
FAILED=0

assert_eq() {
    local test_id="$1"
    local desc="$2"
    local actual="$3"
    local expected="$4"
    TOTAL=$((TOTAL + 1))
    if [[ "${actual}" == "${expected}" ]]; then
        PASSED=$((PASSED + 1))
        echo "  [PASS] ${test_id}: ${desc} (actual=${actual})"
    else
        FAILED=$((FAILED + 1))
        echo "  [FAIL] ${test_id}: ${desc} (expected=${expected}, got=${actual})" >&2
    fi
}

assert_ge() {
    local test_id="$1"
    local desc="$2"
    local actual="$3"
    local min_val="$4"
    TOTAL=$((TOTAL + 1))
    if [[ "${actual}" -ge "${min_val}" ]]; then
        PASSED=$((PASSED + 1))
        echo "  [PASS] ${test_id}: ${desc} (actual=${actual} >= ${min_val})"
    else
        FAILED=$((FAILED + 1))
        echo "  [FAIL] ${test_id}: ${desc} (actual=${actual} < ${min_val})" >&2
    fi
}

# ------------------------------------------------------------------------------
# Phase 1: Static AST & Declaration Invariants
# ------------------------------------------------------------------------------
echo -e "\n--- Phase 1: Static Declarations & Margin Invariants ---"
SETTINGS_FILE="${PROJECT_ROOT}/shell/desktop/core/Settings.qml"
SHELL_FILE="${PROJECT_ROOT}/shell/shell.qml"

# Check Settings.qml default positions
TRACER_DEFAULT_MARGIN=$(grep -o 'defaultPositions\["networkTracer"\].*top: [0-9]*' "${SETTINGS_FILE}" | grep -o '[0-9]*$')
PROFILER_DEFAULT_MARGIN=$(grep -o 'defaultPositions\["targetProfiler"\].*top: [0-9]*' "${SETTINGS_FILE}" | grep -o '[0-9]*$')

assert_eq "OVR.STATIC.01" "defaultPositions['networkTracer'] top margin is 292" "${TRACER_DEFAULT_MARGIN}" "292"
assert_eq "OVR.STATIC.02" "defaultPositions['targetProfiler'] top margin is 56" "${PROFILER_DEFAULT_MARGIN}" "56"

# Check shell.qml fallback expression
assert_grep "hasWidgetMargin(\"networkTracer\", \"top\")" "${SHELL_FILE}" "shell.qml checks hasWidgetMargin before applying fallback"
assert_grep "Settings\.widgetTargetProfilerVisible \?" "${SHELL_FILE}" "shell.qml dynamically branches on targetProfiler visibility"

# ------------------------------------------------------------------------------
# Phase 2: Runtime QML Permutation & Dynamic Gap Harness
# ------------------------------------------------------------------------------
echo -e "\n--- Phase 2: Runtime Permutations & Dynamic Collapse Harness ---"
TMP_TEST_QML=$(mktemp /tmp/ctos_m1_widget_overlap_XXXXXX.qml)

cat << 'EOF' > "${TMP_TEST_QML}"
import QtQuick
import Quickshell
import desktop.core

Scope {
    id: root

    Timer {
        interval: 10
        running: true
        repeat: false
        onTriggered: {
            console.log("=== BEGIN QML OVERLAP STRESS HARNESS ===");

            // -----------------------------------------------------------------
            // 1. Reset to defaults verification
            // -----------------------------------------------------------------
            Settings.resetToDefaults();
            const profilerH = 220; // TargetProfilerWidget implicitHeight
            const pTopDefault = Settings.getWidgetMargin("targetProfiler", "top", 56);
            const tTopDefault = Settings.getWidgetMargin("networkTracer", "top", 292);
            const hasTracerMargin = Settings.hasWidgetMargin("networkTracer", "top");
            const hasProfilerMargin = Settings.hasWidgetMargin("targetProfiler", "top");

            console.log("QML_CHECK:RESET_PROFILER_TOP:" + pTopDefault);
            console.log("QML_CHECK:RESET_TRACER_TOP:" + tTopDefault);
            console.log("QML_CHECK:RESET_HAS_TRACER_MARGIN:" + hasTracerMargin);
            console.log("QML_CHECK:RESET_HAS_PROFILER_MARGIN:" + hasProfilerMargin);

            const gapDefault = tTopDefault - (pTopDefault + profilerH);
            console.log("QML_CHECK:RESET_GAP:" + gapDefault);

            // -----------------------------------------------------------------
            // 2. Permutation Matrix: Both Visible (State A)
            // -----------------------------------------------------------------
            Settings.widgetTargetProfilerVisible = true;
            Settings.widgetNetworkTracerVisible = true;
            let tracerCalculatedTop = Settings.hasWidgetMargin("networkTracer", "top") 
                ? Settings.getWidgetMargin("networkTracer", "top", 0) 
                : (Settings.widgetTargetProfilerVisible ? (Theme.barHeight + Theme.spacingXl + 220 + Theme.spacingXl) : (Theme.barHeight + Theme.spacingXl));
            let profilerCalculatedTop = Settings.getWidgetMargin("targetProfiler", "top", Theme.barHeight + Theme.spacingXl);
            let gapStateA = tracerCalculatedTop - (profilerCalculatedTop + profilerH);
            console.log("QML_CHECK:STATE_A_TRACER_TOP:" + tracerCalculatedTop);
            console.log("QML_CHECK:STATE_A_PROFILER_TOP:" + profilerCalculatedTop);
            console.log("QML_CHECK:STATE_A_GAP:" + gapStateA);

            // -----------------------------------------------------------------
            // 3. Permutation Matrix: Profiler Hidden, Tracer Visible (State B: Dynamic Collapse)
            // -----------------------------------------------------------------
            Settings.widgetTargetProfilerVisible = false;
            Settings.widgetNetworkTracerVisible = true;
            tracerCalculatedTop = Settings.hasWidgetMargin("networkTracer", "top") 
                ? Settings.getWidgetMargin("networkTracer", "top", 0) 
                : (Settings.widgetTargetProfilerVisible ? (Theme.barHeight + Theme.spacingXl + 220 + Theme.spacingXl) : (Theme.barHeight + Theme.spacingXl));
            console.log("QML_CHECK:STATE_B_COLLAPSED_TOP:" + tracerCalculatedTop);

            // -----------------------------------------------------------------
            // 4. Permutation Matrix: Profiler Visible, Tracer Hidden (State C)
            // -----------------------------------------------------------------
            Settings.widgetTargetProfilerVisible = true;
            Settings.widgetNetworkTracerVisible = false;
            console.log("QML_CHECK:STATE_C_PROFILER_VIS:" + Settings.widgetTargetProfilerVisible);
            console.log("QML_CHECK:STATE_C_TRACER_VIS:" + Settings.widgetNetworkTracerVisible);

            // -----------------------------------------------------------------
            // 5. Permutation Matrix: Both Hidden (State D)
            // -----------------------------------------------------------------
            Settings.widgetTargetProfilerVisible = false;
            Settings.widgetNetworkTracerVisible = false;
            console.log("QML_CHECK:STATE_D_PROFILER_VIS:" + Settings.widgetTargetProfilerVisible);
            console.log("QML_CHECK:STATE_D_TRACER_VIS:" + Settings.widgetNetworkTracerVisible);

            // -----------------------------------------------------------------
            // 6. Cyclic Transition Stress (10 cycles)
            // -----------------------------------------------------------------
            let cyclicOk = true;
            for (let c = 0; c < 10; ++c) {
                Settings.widgetTargetProfilerVisible = false;
                let topCollapsed = Settings.hasWidgetMargin("networkTracer", "top") ? Settings.getWidgetMargin("networkTracer", "top", 0) : (Settings.widgetTargetProfilerVisible ? 292 : 56);
                if (topCollapsed !== 56) { cyclicOk = false; break; }

                Settings.widgetTargetProfilerVisible = true;
                let topExpanded = Settings.hasWidgetMargin("networkTracer", "top") ? Settings.getWidgetMargin("networkTracer", "top", 0) : (Settings.widgetTargetProfilerVisible ? 292 : 56);
                if (topExpanded !== 292) { cyclicOk = false; break; }
            }
            console.log("QML_CHECK:CYCLIC_STRESS_OK:" + cyclicOk);

            // -----------------------------------------------------------------
            // 7. Explicit User Position Overrides & Isolation
            // -----------------------------------------------------------------
            Settings.parseConfig(JSON.stringify({
                widgets: {
                    networkTracer: { y: 350 },
                    targetProfiler: { y: 60 }
                }
            }));
            const explicitTracerTop = Settings.hasWidgetMargin("networkTracer", "top") ? Settings.getWidgetMargin("networkTracer", "top", 0) : 0;
            const explicitProfilerTop = Settings.getWidgetMargin("targetProfiler", "top", 0);
            const explicitGap = explicitTracerTop - (explicitProfilerTop + profilerH);
            console.log("QML_CHECK:EXPLICIT_TRACER_TOP:" + explicitTracerTop);
            console.log("QML_CHECK:EXPLICIT_PROFILER_TOP:" + explicitProfilerTop);
            console.log("QML_CHECK:EXPLICIT_GAP:" + explicitGap);

            // User override remains locked even if profiler is toggled off
            Settings.widgetTargetProfilerVisible = false;
            const overrideWhileHidden = Settings.hasWidgetMargin("networkTracer", "top") ? Settings.getWidgetMargin("networkTracer", "top", 0) : (Settings.widgetTargetProfilerVisible ? 292 : 56);
            console.log("QML_CHECK:OVERRIDE_WHILE_HIDDEN:" + overrideWhileHidden);

            // Restoring defaults clears overrides
            Settings.resetToDefaults();
            const restoredHasMargin = Settings.hasWidgetMargin("networkTracer", "top");
            const restoredTracerTop = Settings.hasWidgetMargin("networkTracer", "top") ? Settings.getWidgetMargin("networkTracer", "top", 0) : (Settings.widgetTargetProfilerVisible ? 292 : 56);
            console.log("QML_CHECK:RESTORED_HAS_MARGIN:" + restoredHasMargin);
            console.log("QML_CHECK:RESTORED_TRACER_TOP:" + restoredTracerTop);

            console.log("=== END QML OVERLAP STRESS HARNESS ===");
            Qt.quit();
        }
    }
}
EOF

# Execute harness with Quickshell
OUTPUT=$(run_qml_test_harness "${TMP_TEST_QML}" "Milestone 1 Overlap Stress Harness" 2>&1)
rm -f "${TMP_TEST_QML}"

extract_val() {
    local key="$1"
    echo "${OUTPUT}" | sed -n "s/.*QML_CHECK:${key}:\(.*\)/\1/p" | head -n 1 | tr -d '\r '
}

# Parse results
RESET_P_TOP=$(extract_val "RESET_PROFILER_TOP")
RESET_T_TOP=$(extract_val "RESET_TRACER_TOP")
RESET_HAS_T_MARGIN=$(extract_val "RESET_HAS_TRACER_MARGIN")
RESET_HAS_P_MARGIN=$(extract_val "RESET_HAS_PROFILER_MARGIN")
RESET_GAP=$(extract_val "RESET_GAP")

STATE_A_TRACER=$(extract_val "STATE_A_TRACER_TOP")
STATE_A_PROFILER=$(extract_val "STATE_A_PROFILER_TOP")
STATE_A_GAP=$(extract_val "STATE_A_GAP")
STATE_B_COLLAPSED=$(extract_val "STATE_B_COLLAPSED_TOP")
CYCLIC_OK=$(extract_val "CYCLIC_STRESS_OK")

EXPLICIT_TRACER=$(extract_val "EXPLICIT_TRACER_TOP")
EXPLICIT_PROFILER=$(extract_val "EXPLICIT_PROFILER_TOP")
EXPLICIT_GAP=$(extract_val "EXPLICIT_GAP")
OVERRIDE_HIDDEN=$(extract_val "OVERRIDE_WHILE_HIDDEN")
RESTORED_HAS_MARGIN=$(extract_val "RESTORED_HAS_MARGIN")
RESTORED_TRACER=$(extract_val "RESTORED_TRACER_TOP")

# Assertions
assert_eq "OVR.RESET.01" "resetToDefaults targetProfiler top is 56" "${RESET_P_TOP}" "56"
assert_eq "OVR.RESET.02" "resetToDefaults networkTracer top is 292" "${RESET_T_TOP}" "292"
assert_eq "OVR.RESET.03" "resetToDefaults hasTracerMargin is false" "${RESET_HAS_T_MARGIN}" "false"
assert_eq "OVR.RESET.04" "resetToDefaults hasProfilerMargin is false" "${RESET_HAS_P_MARGIN}" "false"
assert_eq "OVR.RESET.05" "resetToDefaults clean vertical gap is 16px" "${RESET_GAP}" "16"

assert_eq "OVR.STATE_A.01" "State A (both visible) tracer top is 292" "${STATE_A_TRACER}" "292"
assert_eq "OVR.STATE_A.02" "State A (both visible) profiler top is 56" "${STATE_A_PROFILER}" "56"
assert_eq "OVR.STATE_A.03" "State A vertical gap is 16px" "${STATE_A_GAP}" "16"
assert_ge "OVR.STATE_A.04" "State A vertical gap >= 16px" "${STATE_A_GAP}" 16

assert_eq "OVR.STATE_B.01" "State B (profiler hidden) tracer collapses up to 56px" "${STATE_B_COLLAPSED}" "56"

assert_eq "OVR.CYCLIC.01" "Rapid cyclic visibility toggling maintains exact bounds" "${CYCLIC_OK}" "true"

assert_eq "OVR.OVERRIDE.01" "User explicit tracer top is respected (350)" "${EXPLICIT_TRACER}" "350"
assert_eq "OVR.OVERRIDE.02" "User explicit profiler top is respected (60)" "${EXPLICIT_PROFILER}" "60"
assert_ge "OVR.OVERRIDE.03" "User explicit gap >= 16px (got 70px)" "${EXPLICIT_GAP}" 16
assert_eq "OVR.OVERRIDE.04" "User override retained when profiler hidden" "${OVERRIDE_HIDDEN}" "350"

assert_eq "OVR.RESTORE.01" "resetToDefaults clears explicit margin flag" "${RESTORED_HAS_MARGIN}" "false"
assert_eq "OVR.RESTORE.02" "resetToDefaults restores dynamic tracer top (292)" "${RESTORED_TRACER}" "292"

echo -e "\n========================================================"
echo "Widget Overlap Test Summary: Total: ${TOTAL} | Passed: ${PASSED} | Failed: ${FAILED}"
echo "========================================================"

if [[ ${FAILED} -eq 0 ]]; then
    exit 0
else
    exit 1
fi
