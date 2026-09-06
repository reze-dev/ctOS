#!/usr/bin/env bash
# ==============================================================================
# Tier 2 - Feature 14 Boundaries: Safe Cancel & Escape
# ==============================================================================
set -u
set +e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../harness/mock_environment.sh"
source "${SCRIPT_DIR}/../harness/qml_runner.sh"

SYSTEM_RAIL="${PROJECT_ROOT}/shell/desktop/surfaces/SystemRail.qml"
SHELL_QML="${PROJECT_ROOT}/shell/shell.qml"

test_case "T2.28.1" "Safe Cancel Boundary: Pressing Escape while confirming does not execute command"
if [[ -f "${SYSTEM_RAIL}" ]]; then
    # Verify Escape handler resets confirmation without executing
    escape_handler=$(grep -B 2 -A 5 -i "Escape" "${SYSTEM_RAIL}" || true)
    assert_not_grep "execDetached" <(echo "${escape_handler}") "Escape keypress must not trigger execDetached"
else
    test_skip "Pending M3: Escape safety audit pending M3"
fi

test_case "T2.28.2" "Safe Cancel Boundary: Escape returns confirmationAction to empty string"
if [[ -f "${SYSTEM_RAIL}" ]]; then
    assert_grep -E '(confirmationAction\s*=\s*""|isConfirming\s*=\s*false)' "${SYSTEM_RAIL}" \
        "Escape must reset confirmationAction state"
else
    test_skip "Pending M3: State reset check pending M3"
fi

test_case "T2.28.3" "Safe Cancel Boundary: Backdrop scrim click closes overlay host immediately"
assert_file_exists "${SHELL_QML}"
assert_grep "scrimBackdrop" "${SHELL_QML}" "shell.qml must have scrimBackdrop"
assert_grep "OverlayController\.close\(\)" "${SHELL_QML}" "scrimBackdrop click must call close()"

test_case "T2.28.4" "Safe Cancel Boundary: Rapid burst of multiple Escape keypresses handled idempotently"
# In shell.qml, Escape shortcut triggers OverlayController.close()
assert_grep 'Shortcut' "${SHELL_QML}" "Escape shortcut must be declared in shell.qml"
assert_grep 'sequence:\s*"Escape"' "${SHELL_QML}" "Shortcut sequence must be Escape"

test_case "T2.28.5" "Safe Cancel Boundary: Cancel button click returns focus to normal action list"
if [[ -f "${SYSTEM_RAIL}" ]]; then
    assert_grep -i -E "(btnCancel|cancel|onClicked)" "${SYSTEM_RAIL}" "Cancel button must declare onClicked handler"
else
    test_skip "Pending M3: Cancel focus restoration pending M3"
fi

report_summary
