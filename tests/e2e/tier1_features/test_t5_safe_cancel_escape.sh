#!/usr/bin/env bash
# ==============================================================================
# Tier 1 - Feature 14: Safe Cancel & Escape
# Source: ORIGINAL_REQUEST §R2, TEST_INFRA.md §Feature 14, PROJECT.md
# ==============================================================================
set -u
set +e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../harness/mock_environment.sh"
source "${SCRIPT_DIR}/../harness/qml_runner.sh"

SYSTEM_RAIL="${PROJECT_ROOT}/shell/desktop/surfaces/SystemRail.qml"
SHELL_QML="${PROJECT_ROOT}/shell/shell.qml"

test_case "T1.28.1" "Safe Cancel: Clicking Cancel in confirmation returns to normal view"
if [[ -f "${SYSTEM_RAIL}" ]]; then
    assert_grep -E '(confirmationAction\s*=\s*""|isConfirming\s*=\s*false)' "${SYSTEM_RAIL}" \
        "Cancel click must reset confirmation state without running command"
else
    test_skip "Pending M3: Cancel click handler pending M3"
fi

test_case "T1.28.2" "Safe Cancel: Escape key in confirmation mode cancels confirmation"
if [[ -f "${SYSTEM_RAIL}" ]]; then
    assert_grep -E '(Escape|onEscapePressed)' "${SYSTEM_RAIL}" "SystemRail must trap Escape to abort confirmation"
else
    test_skip "Pending M3: Escape cancellation handler pending M3"
fi

test_case "T1.28.3" "Safe Cancel: Scrim click closes overlay and aborts destructive session"
assert_file_exists "${SHELL_QML}"
assert_grep "scrimBackdrop" "${SHELL_QML}" "shell.qml must have scrimBackdrop"
assert_grep "OverlayController\.close\(\)" "${SHELL_QML}" "scrimBackdrop must call OverlayController.close()"

test_case "T1.28.4" "Safe Cancel: Cancel handler does not trigger Quickshell.execDetached"
if [[ -f "${SYSTEM_RAIL}" ]]; then
    # Ensure Cancel button does not call execDetached
    cancel_block
    cancel_block=$(grep -B 2 -A 5 -i "cancel" "${SYSTEM_RAIL}" || true)
    assert_not_grep "execDetached" <(echo "${cancel_block}") "Cancel block must not execute system commands"
else
    test_skip "Pending M3: Cancel safety verification pending M3"
fi

test_case "T1.28.5" "Safe Cancel: Escape shortcut in shell.qml closes overlay when not trapped"
assert_grep 'Shortcut' "${SHELL_QML}" "shell.qml must contain Escape shortcut"
assert_grep 'sequence:\s*"Escape"' "${SHELL_QML}" "Shortcut must bind to Escape"

report_summary
