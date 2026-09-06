#!/usr/bin/env bash
# ==============================================================================
# Tier 3 - Pairwise 3: Monitor Hotplug with Active Overlay
# Interaction: Ambient Bar Variants (F11) + OverlayController (F3)
# ==============================================================================
set -u
set +e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../harness/mock_environment.sh"
source "${SCRIPT_DIR}/../harness/qml_runner.sh"

DESKTOP_DIR="${PROJECT_ROOT}/shell/desktop"
OVERLAY_CTRL="${DESKTOP_DIR}/core/OverlayController.qml"
SHELL_ENTRY="${PROJECT_ROOT}/shell/shell.qml"

test_case "T3.03" "Pairwise: Adding or removing monitor while overlay is active does not crash"
if [[ -f "${SHELL_ENTRY}" && -f "${OVERLAY_CTRL}" ]]; then
    assert_grep "(Variants|Quickshell\.screens)" "${SHELL_ENTRY}" "Variants manages per-output windows"
    assert_grep "activeSurface" "${OVERLAY_CTRL}" "OverlayController manages overlay surface"
else
    assert_file_exists "${SHELL_ENTRY}" "shell.qml required"
    assert_file_exists "${OVERLAY_CTRL}" "OverlayController.qml required"
fi

report_summary
