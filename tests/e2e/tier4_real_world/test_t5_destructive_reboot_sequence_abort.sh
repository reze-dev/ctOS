#!/usr/bin/env bash
# ==============================================================================
# Tier 4 - Scenario 9: Destructive Reboot Confirmation and Safe Abort
# Exercised: System Rail, Reboot Action, Confirmation View, Cancel Button
# ==============================================================================
set -u
set +e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../harness/mock_environment.sh"
source "${SCRIPT_DIR}/../harness/qml_runner.sh"

SYSTEM_RAIL="${PROJECT_ROOT}/shell/desktop/surfaces/SystemRail.qml"
ACTION_REG="${PROJECT_ROOT}/shell/desktop/core/ActionRegistry.qml"
THEME_FILE="${PROJECT_ROOT}/shell/desktop/core/Theme.qml"

test_case "T4.09" "Real-World Scenario 9: Destructive Reboot Confirmation and Safe Abort"
assert_file_exists "${ACTION_REG}"
assert_file_exists "${THEME_FILE}"

if [[ -f "${SYSTEM_RAIL}" ]]; then
    # Confirmation view in Theme.destructive
    assert_grep "Theme\.destructive" "${SYSTEM_RAIL}" "Confirmation must use Theme.destructive"
    # Explicit Cancel resets confirmation
    assert_grep -E '(confirmationAction\s*=\s*""|isConfirming\s*=\s*false)' "${SYSTEM_RAIL}" \
        "Cancel button must abort confirmation without executing reboot"
    # Discrete array reboot command
    assert_grep -E '\[\s*"systemctl"\s*,\s*"reboot"\s*\]' "${SYSTEM_RAIL}" "Reboot must use discrete ['systemctl', 'reboot']"
else
    test_skip "Pending M2/M3: SystemRail confirmation view pending implementation"
fi

report_summary
