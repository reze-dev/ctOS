#!/usr/bin/env bash
# ==============================================================================
# Tier 1 - Feature R2: Flexible Widget Positioning Engine
# Requirements: ORIGINAL_REQUEST §R2, PROJECT.md
# Verifies dynamic positioning configuration in Settings.qml, JSON schema
# normalization (x/y coordinates, named anchors, margins), hot-reloading,
# and backwards compatibility with existing shell anchoring contracts.
# ==============================================================================
set -u
set +e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../harness/mock_environment.sh"
source "${SCRIPT_DIR}/../harness/qml_runner.sh"

SETTINGS_FILE="${PROJECT_ROOT}/shell/desktop/core/Settings.qml"
SHELL_FILE="${PROJECT_ROOT}/shell/shell.qml"

# ------------------------------------------------------------------------------
# R2.01: Positioning API Contract in Settings.qml
# ------------------------------------------------------------------------------
test_case "R2.01" "Flexible Positioning: Settings.qml declares widgetPositions and helper methods"
if [[ -f "${SETTINGS_FILE}" ]]; then
    assert_qml_property "${SETTINGS_FILE}" "widgetPositions" --type var
    assert_qml_method "${SETTINGS_FILE}" "normalizePosition"
    assert_qml_method "${SETTINGS_FILE}" "hasWidgetPosition"
    assert_qml_method "${SETTINGS_FILE}" "hasWidgetMargin"
    assert_qml_method "${SETTINGS_FILE}" "getWidgetAnchor"
    assert_qml_method "${SETTINGS_FILE}" "getWidgetMargin"
else
    assert_file_exists "${SETTINGS_FILE}"
fi

# ------------------------------------------------------------------------------
# R2.02: Coordinate Positioning Schema (x, y coordinates -> top/left anchors)
# ------------------------------------------------------------------------------
test_case "R2.02" "Flexible Positioning: (x, y) coordinates normalize to top/left anchors & margins"
TMP_QML_COORD="$(mktemp /tmp/ctos_test_r2_coord_XXXXXX.qml)"
cat << 'EOF' > "${TMP_QML_COORD}"
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
                    cpuHexGrid: { x: 500, y: 120 }
                }
            }));
            const aTop = Settings.getWidgetAnchor("cpuHexGrid", "top", false);
            const aLeft = Settings.getWidgetAnchor("cpuHexGrid", "left", false);
            const aRight = Settings.getWidgetAnchor("cpuHexGrid", "right", true);
            const aBottom = Settings.getWidgetAnchor("cpuHexGrid", "bottom", true);
            const mTop = Settings.getWidgetMargin("cpuHexGrid", "top", 0);
            const mLeft = Settings.getWidgetMargin("cpuHexGrid", "left", 0);

            if (aTop === true && aLeft === true && aRight === false && aBottom === false &&
                mTop === 120 && mLeft === 500) {
                console.log("=== PASS: (x, y) coordinate normalization verified ===");
            } else {
                console.error("ASSERTION_FAILED: (x, y) coordinates failed: aTop=" + aTop + " aLeft=" + aLeft + " mTop=" + mTop + " mLeft=" + mLeft);
            }
            Qt.quit();
        }
    }
}
EOF
run_qml_test_harness "${TMP_QML_COORD}" "(x, y) coordinate normalization harness"
rm -f "${TMP_QML_COORD}"

# ------------------------------------------------------------------------------
# R2.03: Named String Anchors (e.g. "top-right", "bottom-left", "bottom-right")
# ------------------------------------------------------------------------------
test_case "R2.03" "Flexible Positioning: Named string anchors parse edge flags & offset margins"
TMP_QML_NAMED="$(mktemp /tmp/ctos_test_r2_named_XXXXXX.qml)"
cat << 'EOF' > "${TMP_QML_NAMED}"
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
                    ramBlockBar: { anchor: "bottom-left", offsetX: 40, offsetY: 80 },
                    networkFlow: { anchor: "top-right", offsetX: 25, offsetY: 35 }
                }
            }));

            // Check ramBlockBar (bottom-left)
            const ramB = Settings.getWidgetAnchor("ramBlockBar", "bottom", false);
            const ramL = Settings.getWidgetAnchor("ramBlockBar", "left", false);
            const ramT = Settings.getWidgetAnchor("ramBlockBar", "top", true);
            const ramR = Settings.getWidgetAnchor("ramBlockBar", "right", true);
            const ramMB = Settings.getWidgetMargin("ramBlockBar", "bottom", 0);
            const ramML = Settings.getWidgetMargin("ramBlockBar", "left", 0);

            // Check networkFlow (top-right)
            const netT = Settings.getWidgetAnchor("networkFlow", "top", false);
            const netR = Settings.getWidgetAnchor("networkFlow", "right", false);
            const netMT = Settings.getWidgetMargin("networkFlow", "top", 0);
            const netMR = Settings.getWidgetMargin("networkFlow", "right", 0);

            if (ramB && ramL && !ramT && !ramR && ramMB === 80 && ramML === 40 &&
                netT && netR && netMT === 35 && netMR === 25) {
                console.log("=== PASS: Named anchor parsing verified ===");
            } else {
                console.error("ASSERTION_FAILED: Named anchors failed");
            }
            Qt.quit();
        }
    }
}
EOF
run_qml_test_harness "${TMP_QML_NAMED}" "Named anchor parsing harness"
rm -f "${TMP_QML_NAMED}"

# ------------------------------------------------------------------------------
# R2.04: Explicit Anchors and Margins Schema
# ------------------------------------------------------------------------------
test_case "R2.04" "Flexible Positioning: Explicit anchors and margins maps parse accurately"
TMP_QML_EXPL="$(mktemp /tmp/ctos_test_r2_explicit_XXXXXX.qml)"
cat << 'EOF' > "${TMP_QML_EXPL}"
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
                    networkTracer: {
                        anchors: { top: true, right: true, bottom: false, left: false },
                        margins: { top: 55, right: 30 }
                    }
                }
            }));

            const aTop = Settings.getWidgetAnchor("networkTracer", "top", false);
            const aRight = Settings.getWidgetAnchor("networkTracer", "right", false);
            const aBottom = Settings.getWidgetAnchor("networkTracer", "bottom", true);
            const aLeft = Settings.getWidgetAnchor("networkTracer", "left", true);
            const mTop = Settings.getWidgetMargin("networkTracer", "top", 0);
            const mRight = Settings.getWidgetMargin("networkTracer", "right", 0);

            if (aTop && aRight && !aBottom && !aLeft && mTop === 55 && mRight === 30) {
                console.log("=== PASS: Explicit anchors & margins verified ===");
            } else {
                console.error("ASSERTION_FAILED: Explicit schema parsing failed");
            }
            Qt.quit();
        }
    }
}
EOF
run_qml_test_harness "${TMP_QML_EXPL}" "Explicit anchors and margins harness"
rm -f "${TMP_QML_EXPL}"

# ------------------------------------------------------------------------------
# R2.05: Dynamic Hot-Reloading via FileView
# ------------------------------------------------------------------------------
test_case "R2.05" "Flexible Positioning: Settings updates dynamically recompute widget positions"
TMP_QML_HOTRELOAD="$(mktemp /tmp/ctos_test_r2_hotreload_XXXXXX.qml)"
cat << 'EOF' > "${TMP_QML_HOTRELOAD}"
import QtQuick
import Quickshell
import desktop.core

Scope {
    Timer {
        interval: 10
        running: true
        repeat: false
        onTriggered: {
            // First config
            Settings.parseConfig(JSON.stringify({
                widgets: {
                    targetProfiler: { x: 100, y: 100 }
                }
            }));
            const m1 = Settings.getWidgetMargin("targetProfiler", "top", 0);

            // Second config (hot reload simulation)
            Settings.parseConfig(JSON.stringify({
                widgets: {
                    targetProfiler: { x: 450, y: 600 }
                }
            }));
            const m2 = Settings.getWidgetMargin("targetProfiler", "top", 0);
            const mLeft2 = Settings.getWidgetMargin("targetProfiler", "left", 0);

            if (m1 === 100 && m2 === 600 && mLeft2 === 450) {
                console.log("=== PASS: Dynamic hot-reloading position recomputation verified ===");
            } else {
                console.error("ASSERTION_FAILED: Hot reload failed: m1=" + m1 + " m2=" + m2);
            }
            Qt.quit();
        }
    }
}
EOF
run_qml_test_harness "${TMP_QML_HOTRELOAD}" "Dynamic hot reload harness"
rm -f "${TMP_QML_HOTRELOAD}"

# ------------------------------------------------------------------------------
# R2.06: Backward Compatibility Preservation with T7.06.3
# ------------------------------------------------------------------------------
test_case "R2.06" "Flexible Positioning: Fallback defaults preserve existing anchor expressions"
if [[ -f "${SHELL_FILE}" ]]; then
    # Must preserve fallback compatibility expressions checked by T7.06.3
    assert_grep "Settings\.widgetCpuHexGridVisible" "${SHELL_FILE}" "shell.qml must preserve widgetCpuHexGridVisible fallback"
    assert_grep "Theme\.barHeight" "${SHELL_FILE}" "shell.qml must use Theme.barHeight default offset"
    assert_grep "Theme\.spacing2Xl" "${SHELL_FILE}" "shell.qml must use Theme.spacing2Xl default margin"
else
    assert_file_exists "${SHELL_FILE}"
fi

# ------------------------------------------------------------------------------
# R2.07: Safe Fallback when Widget Position Config is Missing
# ------------------------------------------------------------------------------
test_case "R2.07" "Flexible Positioning: Missing widget position falls back cleanly without crash"
TMP_QML_FALLBACK="$(mktemp /tmp/ctos_test_r2_fallback_XXXXXX.qml)"
cat << 'EOF' > "${TMP_QML_FALLBACK}"
import QtQuick
import Quickshell
import desktop.core

Scope {
    Timer {
        interval: 10
        running: true
        repeat: false
        onTriggered: {
            Settings.resetToDefaults();
            // Query unknown widget with fallbacks
            const aTop = Settings.getWidgetAnchor("unknownWidget", "top", true);
            const aBottom = Settings.getWidgetAnchor("unknownWidget", "bottom", false);
            const mTop = Settings.getWidgetMargin("unknownWidget", "top", 48);
            const hasPos = Settings.hasWidgetPosition("unknownWidget");

            if (aTop === true && aBottom === false && mTop === 48 && hasPos === false) {
                console.log("=== PASS: Fallback defaults cleanly verified ===");
            } else {
                console.error("ASSERTION_FAILED: Fallback mismatch");
            }
            Qt.quit();
        }
    }
}
EOF
run_qml_test_harness "${TMP_QML_FALLBACK}" "Missing position fallback harness"
rm -f "${TMP_QML_FALLBACK}"

report_summary
