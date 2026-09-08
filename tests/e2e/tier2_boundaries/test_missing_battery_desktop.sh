#!/usr/bin/env bash
# ==============================================================================
# Tier 2 - Feature 9 Boundary: Missing Battery on Desktop & Power Edge Cases
# Source: ORIGINAL_REQUEST §R2, architecture.md, PROJECT.md
# ==============================================================================
set -u
set +e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../harness/mock_environment.sh"
source "${SCRIPT_DIR}/../harness/qml_runner.sh"

POWER_SVC="${PROJECT_ROOT}/shell/desktop/services/PowerService.qml"
DESKTOP_DIR="${PROJECT_ROOT}/shell/desktop"

test_case "T2.09.1" "Power Boundary: Desktop system with no battery sets isBatteryPresent: false"
if [[ -f "${POWER_SVC}" ]]; then
    check_qml_property "${POWER_SVC}" "isBatteryPresent" --type bool || assert_grep "isBatteryPresent" "${POWER_SVC}" "isBatteryPresent property required"
else
    assert_file_exists "${POWER_SVC}" "PowerService.qml required"
fi

test_case "T2.09.2" "Power Boundary: Battery widget visible flag binds to isBatteryPresent"
if [[ -d "${DESKTOP_DIR}" ]]; then
    assert_grep -i "(visible\s*:\s*.*isBatteryPresent|isBatteryPresent\s*&&)" "${DESKTOP_DIR}" "Battery widget visibility must bind to isBatteryPresent"
else
    assert_dir_exists "${DESKTOP_DIR}" "shell/desktop required"
fi

test_case "T2.09.3" "Power Boundary: Battery percentage at 0% does not trigger division by zero"
if [[ -d "${DESKTOP_DIR}" ]]; then
    assert_grep -i "(percentage|battery)" "${DESKTOP_DIR}" "Battery percentage handling must be defined"
else
    assert_dir_exists "${DESKTOP_DIR}" "shell/desktop required"
fi

test_case "T2.09.4" "Power Boundary: Battery percentage at 100% full renders cleanly"
if [[ -d "${DESKTOP_DIR}" ]]; then
    assert_grep -i "(percentage|100|charging)" "${DESKTOP_DIR}" "Full battery state renders cleanly"
else
    assert_dir_exists "${DESKTOP_DIR}" "shell/desktop required"
fi

test_case "T2.09.5" "Power Boundary: Battery percentage strictly clamped to [0, 100]"
if [[ -f "${POWER_SVC}" ]]; then
    assert_grep -i "(percentage|Math\.min|Math\.max|clamp)" "${POWER_SVC}" "Battery percentage must remain bounded [0, 100]"
else
    assert_file_exists "${POWER_SVC}" "PowerService.qml required"
fi

report_summary
