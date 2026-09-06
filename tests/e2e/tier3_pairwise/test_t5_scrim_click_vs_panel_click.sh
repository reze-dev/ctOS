#!/usr/bin/env bash
# ==============================================================================
# Tier 3 - Pairwise 18: Scrim Click vs Internal Panel Click Capture
# Interaction: shell.qml overlayHost (F7) + SystemRail panel (F7)
# ==============================================================================
set -u
set +e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../harness/mock_environment.sh"
source "${SCRIPT_DIR}/../harness/qml_runner.sh"

SHELL_QML="${PROJECT_ROOT}/shell/shell.qml"
SYSTEM_RAIL="${PROJECT_ROOT}/shell/desktop/surfaces/SystemRail.qml"

test_case "T3.18" "Pairwise: Scrim clicks dismiss overlay while internal panel clicks are consumed"
assert_file_exists "${SHELL_QML}"
# Scrim must close overlay
assert_grep "scrimBackdrop" "${SHELL_QML}" "shell.qml must have scrimBackdrop"
assert_grep "OverlayController\.close\(\)" "${SHELL_QML}" "scrimBackdrop must call OverlayController.close()"

if [[ -f "${SYSTEM_RAIL}" ]]; then
    # SystemRail internal MouseArea must prevent stealing
    assert_grep -E "(preventStealing|onClicked:\s*function|mouse\.accepted)" "${SYSTEM_RAIL}" \
        "SystemRail must trap internal clicks to avoid bubbling to scrim"
else
    test_skip "Pending M2: SystemRail internal MouseArea pending M2"
fi

report_summary
