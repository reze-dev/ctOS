#!/usr/bin/env bash
# ==============================================================================
# Tier 1 - Milestone 4: Empirical Challenger Stress Suite (R7: Calendar Popup)
# ==============================================================================
set -u
set +e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../harness/mock_environment.sh"
source "${SCRIPT_DIR}/../harness/qml_runner.sh"

CALENDAR_POPUP_QML="${PROJECT_ROOT}/shell/desktop/surfaces/components/CalendarPopup.qml"
CLOCK_WIDGET_QML="${PROJECT_ROOT}/shell/desktop/surfaces/components/ClockWidget.qml"
AMBIENT_BAR_QML="${PROJECT_ROOT}/shell/desktop/surfaces/AmbientBar.qml"
SHELL_QML="${PROJECT_ROOT}/shell/shell.qml"
CHALLENGER_HARNESS="${HARNESS_DIR}/test_m4_challenger_stress.qml"

echo "================================================================"
echo "=== TIER 1 M4: CHALLENGER STRESS & CONCURRENCY SUITE =========="
echo "================================================================"

# ------------------------------------------------------------------------------
# 1. Monospace Typography & Design Token Verification
# ------------------------------------------------------------------------------

test_case "CHAL.M4.STATIC.01" "CalendarPopup: Monospace font compliance across all Text elements"
text_count=$(grep -c "Text {" "${CALENDAR_POPUP_QML}" || true)
font_count=$(grep -c "font.family: Theme.fontFamilyMonospace" "${CALENDAR_POPUP_QML}" || true)
if [[ "${text_count}" -gt 0 && "${text_count}" -eq "${font_count}" ]]; then
    CURRENT_TEST_FAILED=0
else
    CURRENT_TEST_FAILED=1
    CURRENT_TEST_REASON="Expected all ${text_count} Text elements to use Theme.fontFamilyMonospace, but found ${font_count}"
fi

test_case "CHAL.M4.STATIC.02" "CalendarPopup: Zero hardcoded hex colors"
hex_count=$(grep -c -E '#[0-9a-fA-F]{3,8}' "${CALENDAR_POPUP_QML}" || true)
assert_eq "0" "${hex_count}" "Found ${hex_count} hardcoded hex colors in CalendarPopup.qml"

test_case "CHAL.M4.STATIC.03" "ClockWidget: Monospace font and zero hardcoded hex colors"
cw_text_count=$(grep -c "Text {" "${CLOCK_WIDGET_QML}" || true)
cw_font_count=$(grep -c "font.family: Theme.fontFamilyMonospace" "${CLOCK_WIDGET_QML}" || true)
cw_hex_count=$(grep -c -E '#[0-9a-fA-F]{3,8}' "${CLOCK_WIDGET_QML}" || true)
if [[ "${cw_text_count}" -eq "${cw_font_count}" && "${cw_hex_count}" -eq 0 ]]; then
    CURRENT_TEST_FAILED=0
else
    CURRENT_TEST_FAILED=1
    CURRENT_TEST_REASON="ClockWidget failed font or hex check: text=${cw_text_count}, font=${cw_font_count}, hex=${cw_hex_count}"
fi

test_case "CHAL.M4.STATIC.04" "Shell Calendar Panels: Focus isolation and layer hierarchy contracts"
has_popup_focus=$(grep -c "WlrKeyboardFocus.None" "${SHELL_QML}" || true)
has_popup_layer=$(grep -c "WlrLayershell.layer: WlrLayer.Overlay" "${SHELL_QML}" || true)
has_backdrop_layer=$(grep -c "WlrLayershell.layer: WlrLayer.Top" "${SHELL_QML}" || true)
if [[ "${has_popup_focus}" -ge 2 && "${has_popup_layer}" -ge 1 && "${has_backdrop_layer}" -ge 1 ]]; then
    CURRENT_TEST_FAILED=0
else
    CURRENT_TEST_FAILED=1
    CURRENT_TEST_REASON="Shell layer-shell wiring missing required layer or focus isolation contracts"
fi

test_case "CHAL.M4.STATIC.05" "CalendarPopup: Component registration and isolation check"
check_qml_property "${CALENDAR_POPUP_QML}" "viewYear" --type int
check_qml_property "${CALENDAR_POPUP_QML}" "viewMonth" --type int
check_qml_signal "${CALENDAR_POPUP_QML}" "closeRequested"
check_no_greeter_imports "${PROJECT_ROOT}/shell/desktop/"
check_no_polling_loops "${PROJECT_ROOT}/shell/desktop/"

# ------------------------------------------------------------------------------
# 2. Quickshell Runtime Empirical Stress Harness
# ------------------------------------------------------------------------------

test_case "CHAL.M4.RUNTIME.01" "Quickshell empirical multi-monitor, IPC, preemption & disconnect stress harness"
if [[ -f "${CHALLENGER_HARNESS}" ]]; then
    run_qml_test_harness "${CHALLENGER_HARNESS}" "Milestone 4 Challenger Stress Harness" 20
else
    test_skip "Challenger stress harness missing"
fi

report_summary
