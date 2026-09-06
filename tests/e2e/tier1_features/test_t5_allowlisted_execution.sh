#!/usr/bin/env bash
# ==============================================================================
# Tier 1 - Feature 15: Allowlisted Confirm Execution
# Source: ORIGINAL_REQUEST §R2, TEST_INFRA.md §Feature 15, PROJECT.md
# ==============================================================================
set -u
set +e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../harness/mock_environment.sh"
source "${SCRIPT_DIR}/../harness/qml_runner.sh"

SYSTEM_RAIL="${PROJECT_ROOT}/shell/desktop/surfaces/SystemRail.qml"
ACTION_REG="${PROJECT_ROOT}/shell/desktop/core/ActionRegistry.qml"
DESKTOP_DIR="${PROJECT_ROOT}/shell/desktop"

test_case "T1.29.1" "Allowlisted Execution: Reboot executes discrete ['systemctl', 'reboot']"
if [[ -f "${SYSTEM_RAIL}" ]]; then
    assert_grep -E '\[\s*"systemctl"\s*,\s*"reboot"\s*\]' "${SYSTEM_RAIL}" "Reboot must use discrete ['systemctl', 'reboot']"
else
    test_skip "Pending M3: SystemRail reboot command pending M3"
fi

test_case "T1.29.2" "Allowlisted Execution: Power Off executes discrete ['systemctl', 'poweroff']"
if [[ -f "${SYSTEM_RAIL}" ]]; then
    assert_grep -E '\[\s*"systemctl"\s*,\s*"poweroff"\s*\]' "${SYSTEM_RAIL}" "Poweroff must use discrete ['systemctl', 'poweroff']"
else
    test_skip "Pending M3: SystemRail poweroff command pending M3"
fi

test_case "T1.29.3" "Allowlisted Execution: Logout executes discrete exit command"
if [[ -f "${SYSTEM_RAIL}" ]]; then
    assert_grep -E '(\[\s*"hyprctl"\s*,\s*"dispatch"\s*,\s*"exit"\s*\]|\[\s*"loginctl"\s*,\s*"terminate-user")' "${SYSTEM_RAIL}" \
        "Logout must use discrete exit array"
else
    test_skip "Pending M3: SystemRail logout command pending M3"
fi

test_case "T1.29.4" "Allowlisted Execution: Zero sh -c or subshell string execution"
assert_not_grep -E '\[\s*"sh"\s*,\s*"-c"' "${DESKTOP_DIR}" "Prohibit sh -c execution across desktop components"

test_case "T1.29.5" "Allowlisted Execution: Zero string concatenation in execDetached arguments"
assert_not_grep -E 'execDetached\s*\(\s*".*\+' "${DESKTOP_DIR}" "Prohibit string concatenation in execDetached"

report_summary
