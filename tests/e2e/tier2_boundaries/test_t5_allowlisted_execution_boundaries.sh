#!/usr/bin/env bash
# ==============================================================================
# Tier 2 - Feature 15 Boundaries: Allowlisted Confirm Execution
# ==============================================================================
set -u
set +e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../harness/mock_environment.sh"
source "${SCRIPT_DIR}/../harness/qml_runner.sh"

DESKTOP_DIR="${PROJECT_ROOT}/shell/desktop"
SYSTEM_RAIL="${PROJECT_ROOT}/shell/desktop/surfaces/SystemRail.qml"

test_case "T2.29.1" "Allowlisted Execution Boundary: Zero sh -c command invocations across desktop surfaces"
assert_not_grep -E '\[\s*"sh"\s*,\s*"-c"' "${DESKTOP_DIR}" "Prohibit [\"sh\", \"-c\"] invocations"

test_case "T2.29.2" "Allowlisted Execution Boundary: Zero bash -c command invocations across desktop surfaces"
assert_not_grep -E '\[\s*"bash"\s*,\s*"-c"' "${DESKTOP_DIR}" "Prohibit [\"bash\", \"-c\"] invocations"

test_case "T2.29.3" "Allowlisted Execution Boundary: Zero subshell backtick execution in commands"
assert_not_grep -E 'execDetached\s*\(\s*\[[^\]]*`' "${DESKTOP_DIR}" "Prohibit command substitution backticks in execDetached"

test_case "T2.29.4" "Allowlisted Execution Boundary: System command invocations strictly specify string arrays"
if [[ -f "${SYSTEM_RAIL}" ]]; then
    assert_grep "Quickshell\.execDetached" "${SYSTEM_RAIL}" "Execution must use Quickshell.execDetached"
    assert_not_grep 'execDetached\s*\(\s*"' "${SYSTEM_RAIL}" "execDetached must not be called with raw string command"
else
    test_skip "Pending M3: execDetached array verification pending M3"
fi

test_case "T2.29.5" "Allowlisted Execution Boundary: Discrete allowlisted commands only (systemctl, loginctl, hyprctl)"
if [[ -f "${SYSTEM_RAIL}" ]]; then
    assert_grep -E '(systemctl|loginctl|hyprctl)' "${SYSTEM_RAIL}" "Must use standard allowlisted binaries"
else
    test_skip "Pending M3: Allowlisted binary verification pending M3"
fi

report_summary
