#!/usr/bin/env bash
# ==============================================================================
# Tier 1 - Feature 13: Session Safety Confirmation
# Source: ORIGINAL_REQUEST §R2, TEST_INFRA.md §Feature 13, PROJECT.md
# ==============================================================================
set -u
set +e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../harness/mock_environment.sh"
source "${SCRIPT_DIR}/../harness/qml_runner.sh"

SYSTEM_RAIL="${PROJECT_ROOT}/shell/desktop/surfaces/SystemRail.qml"
ACTION_REG="${PROJECT_ROOT}/shell/desktop/core/ActionRegistry.qml"

test_case "T1.27.1" "Session Safety: SystemRail provides confirmation state property"
if [[ -f "${SYSTEM_RAIL}" ]]; then
    assert_grep -E "(confirmationAction|isConfirming|confirming)" "${SYSTEM_RAIL}" "SystemRail must track confirmation state"
else
    test_skip "Pending M3: SystemRail confirmation state pending M3"
fi

test_case "T1.27.2" "Session Safety: Destructive session actions defined (logout, reboot, poweroff)"
assert_file_exists "${ACTION_REG}"
assert_grep "action-logout" "${ACTION_REG}" "action-logout must exist"
assert_grep "action-reboot" "${ACTION_REG}" "action-reboot must exist"
assert_grep "action-poweroff" "${ACTION_REG}" "action-poweroff must exist"

test_case "T1.27.3" "Session Safety: Confirmation view renders with Theme.destructive styling"
if [[ -f "${SYSTEM_RAIL}" ]]; then
    assert_grep "Theme\.destructive" "${SYSTEM_RAIL}" "Confirmation state must use Theme.destructive"
else
    test_skip "Pending M3: Confirmation view styling pending M3"
fi

test_case "T1.27.4" "Session Safety: Confirmation view presents explicit Confirm button"
if [[ -f "${SYSTEM_RAIL}" ]]; then
    assert_grep -i -E "(CONFIRM|btnConfirm|onClicked:.*reboot|onClicked:.*poweroff)" "${SYSTEM_RAIL}" "Must present explicit Confirm button"
else
    test_skip "Pending M3: Explicit Confirm button pending M3"
fi

test_case "T1.27.5" "Session Safety: Confirmation view presents explicit Cancel button"
if [[ -f "${SYSTEM_RAIL}" ]]; then
    assert_grep -i -E "(CANCEL|btnCancel|Cancel/Escape)" "${SYSTEM_RAIL}" "Must present explicit Cancel button"
else
    test_skip "Pending M3: Explicit Cancel button pending M3"
fi

report_summary
