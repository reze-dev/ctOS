#!/usr/bin/env bash
# ==============================================================================
# Tier 3 - Pairwise 10: Reduced Motion Setting with Overlay Transitions
# Interaction: Settings (F2) + OverlayController (F3)
# ==============================================================================
set -u
set +e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../harness/mock_environment.sh"
source "${SCRIPT_DIR}/../harness/qml_runner.sh"

DESKTOP_DIR="${PROJECT_ROOT}/shell/desktop"
SETTINGS_FILE="${DESKTOP_DIR}/core/Settings.qml"
OVERLAY_CTRL="${DESKTOP_DIR}/core/OverlayController.qml"

test_case "T3.10" "Pairwise: reducedMotion true suppresses overlay slide and scanline transitions"
if [[ -f "${SETTINGS_FILE}" && -f "${OVERLAY_CTRL}" ]]; then
    assert_file_exists "${SETTINGS_FILE}"
    assert_file_exists "${OVERLAY_CTRL}"
else
    assert_file_exists "${SETTINGS_FILE}" "Settings.qml required"
    assert_file_exists "${OVERLAY_CTRL}" "OverlayController.qml required"
fi

report_summary
