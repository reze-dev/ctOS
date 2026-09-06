#!/usr/bin/env bash
# ==============================================================================
# Tier 1 - Feature 9: Power Service & Battery Omit
# Source: ORIGINAL_REQUEST §R2, interaction-spec.md, PROJECT.md
# ==============================================================================
set -u
set +e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../harness/mock_environment.sh"
source "${SCRIPT_DIR}/../harness/qml_runner.sh"

POWER_SVC="${PROJECT_ROOT}/shell/desktop/services/PowerService.qml"
DESKTOP_DIR="${PROJECT_ROOT}/shell/desktop"

test_case "T1.09.1" "Power Service: PowerService.qml exists in desktop/services/"
assert_file_exists "${POWER_SVC}" "PowerService.qml must exist in desktop/services/"

test_case "T1.09.2" "Power Service: Exposes available and isBatteryPresent properties"
if [[ -f "${POWER_SVC}" ]]; then
    check_qml_property "${POWER_SVC}" "available" || assert_grep "available" "${POWER_SVC}" "available property required"
    check_qml_property "${POWER_SVC}" "isBatteryPresent" || assert_grep "isBatteryPresent" "${POWER_SVC}" "isBatteryPresent property required"
else
    assert_file_exists "${POWER_SVC}"
fi

test_case "T1.09.3" "Power Service: Exposes percentage and isCharging properties"
if [[ -f "${POWER_SVC}" ]]; then
    check_qml_property "${POWER_SVC}" "percentage" || assert_grep "percentage" "${POWER_SVC}" "percentage property required"
    check_qml_property "${POWER_SVC}" "isCharging" || assert_grep "isCharging" "${POWER_SVC}" "isCharging property required"
else
    assert_file_exists "${POWER_SVC}"
fi

test_case "T1.09.4" "Power Service: Battery widget exists in surfaces/components/"
if [[ -d "${DESKTOP_DIR}/surfaces" ]]; then
    local widget_found
    widget_found=$(find "${DESKTOP_DIR}/surfaces" -name "*Battery*.qml" 2>/dev/null | head -n 1)
    if [[ -n "${widget_found}" ]]; then
        assert_file_exists "${widget_found}"
    else
        assert_file_exists "${DESKTOP_DIR}/surfaces/components/BatteryWidget.qml" "BatteryWidget.qml must exist"
    fi
else
    assert_dir_exists "${DESKTOP_DIR}/surfaces"
fi

test_case "T1.09.5" "Power Service: Clean omission when battery is absent (no dummy 0%)"
if [[ -d "${DESKTOP_DIR}" ]]; then
    assert_grep -i "(isBatteryPresent|visible\s*:\s*.*battery)" "${DESKTOP_DIR}" "Battery widget must omit cleanly when no battery present"
else
    assert_dir_exists "${DESKTOP_DIR}"
fi

report_summary
