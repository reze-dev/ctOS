#!/usr/bin/env bash
# ==============================================================================
# Tier 1 - Feature 12: Immediate Session Lock
# Source: interaction-spec.md, TEST_INFRA.md §Feature 12, PROJECT.md
# ==============================================================================
set -u
set +e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../harness/mock_environment.sh"
source "${SCRIPT_DIR}/../harness/qml_runner.sh"

ACTION_REG="${PROJECT_ROOT}/shell/desktop/core/ActionRegistry.qml"
SYSTEM_RAIL="${PROJECT_ROOT}/shell/desktop/surfaces/SystemRail.qml"

test_case "T1.26.1" "Immediate Lock: ActionRegistry declares action-lock"
assert_file_exists "${ACTION_REG}"
assert_grep "action-lock" "${ACTION_REG}" "action-lock must exist in ActionRegistry"

test_case "T1.26.2" "Immediate Lock: Executes discrete argument array ['loginctl', 'lock-session']"
assert_grep -E 'Quickshell\.execDetached\(\s*\[\s*"loginctl"\s*,\s*"lock-session"\s*\]\s*\)' "${ACTION_REG}" \
    "Lock action must execute discrete array ['loginctl', 'lock-session']"

test_case "T1.26.3" "Immediate Lock: Lock session action is non-destructive (immediate invocation)"
# Lock action must have destructive: false so it bypasses confirmation
lock_block=$(grep -A 10 '"action-lock"' "${ACTION_REG}")
assert_match "destructive:\s*false" "${lock_block}" "Lock session must not require destructive confirmation"

test_case "T1.26.4" "Immediate Lock: Lock action has enabled: true"
assert_match "enabled:\s*true" "${lock_block}" "Lock session action must be enabled"

test_case "T1.26.5" "Immediate Lock: SystemRail provides Lock Session tile or invocation"
if [[ -f "${SYSTEM_RAIL}" ]]; then
    assert_grep -E "(lock-session|lockSession|LOCK SESSION)" "${SYSTEM_RAIL}" "SystemRail must offer immediate lock action"
else
    test_skip "Pending M2: SystemRail Lock Session tile pending M2"
fi

report_summary
