#!/usr/bin/env bash
# ==============================================================================
# Tier 2 - Feature 13 Boundaries: Session Safety Confirmation
# ==============================================================================
set -u
set +e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../harness/mock_environment.sh"
source "${SCRIPT_DIR}/../harness/qml_runner.sh"

SYSTEM_RAIL="${PROJECT_ROOT}/shell/desktop/surfaces/SystemRail.qml"
ACTION_REG="${PROJECT_ROOT}/shell/desktop/core/ActionRegistry.qml"

test_case "T2.27.1" "Session Safety Boundary: Arbitrary non-destructive actions bypass confirmation view"
# Immediate actions such as lock must bypass confirmation
lock_action=$(grep -A 10 '"action-lock"' "${ACTION_REG}")
assert_match "destructive:\s*false" "${lock_action}" "Lock action must not trigger confirmation view"

test_case "T2.27.2" "Session Safety Boundary: Destructive session actions are strictly allowlisted"
assert_grep '"action-logout"' "${ACTION_REG}" "action-logout must exist"
assert_grep '"action-reboot"' "${ACTION_REG}" "action-reboot must exist"
assert_grep '"action-poweroff"' "${ACTION_REG}" "action-poweroff must exist"

test_case "T2.27.3" "Session Safety Boundary: Warning headline text elision prevented"
if [[ -f "${SYSTEM_RAIL}" ]]; then
    assert_grep -E "(wrapMode|Text\.WordWrap|noElide|fontSize)" "${SYSTEM_RAIL}" \
        "Confirmation warning message text must not be silently elided"
else
    test_skip "Pending M3: Confirmation text layout check pending M3"
fi

test_case "T2.27.4" "Session Safety Boundary: Keyboard navigation focus trapped on confirmation view"
if [[ -f "${SYSTEM_RAIL}" ]]; then
    assert_grep -E "(FocusScope|focus:\s*true|forceActiveFocus)" "${SYSTEM_RAIL}" \
        "Confirmation dialog must capture active keyboard focus"
else
    test_skip "Pending M3: Confirmation focus capture check pending M3"
fi

test_case "T2.27.5" "Session Safety Boundary: Safety view explicitly communicates data loss warning"
if [[ -f "${SYSTEM_RAIL}" ]]; then
    assert_grep -i -E "(UNSAVED|TERMINATE|PROCESSES|DATA|WARNING|CRITICAL)" "${SYSTEM_RAIL}" \
        "Confirmation view must warn user about terminating processes or data"
else
    test_skip "Pending M3: Confirmation warning text check pending M3"
fi

report_summary
