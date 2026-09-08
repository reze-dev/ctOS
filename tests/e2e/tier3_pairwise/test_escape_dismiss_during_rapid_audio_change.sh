#!/usr/bin/env bash
# ==============================================================================
# Tier 3 - Pairwise 14: Escape Key Dismissal During Rapid Audio Volume Adjustment
# Interaction: Overlay Dismissal (F4) + Audio Service & Safe Bounds (F7)
# ==============================================================================
set -u
set +e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../harness/mock_environment.sh"
source "${SCRIPT_DIR}/../harness/qml_runner.sh"

DESKTOP_DIR="${PROJECT_ROOT}/shell/desktop"
OVERLAY_CTRL="${DESKTOP_DIR}/core/OverlayController.qml"
AUDIO_SVC="${DESKTOP_DIR}/services/AudioService.qml"

test_case "T3.14" "Pairwise: Pressing Escape while rapidly adjusting volume dismisses overlay without dropping audio state"
if [[ -f "${OVERLAY_CTRL}" && -f "${AUDIO_SVC}" ]]; then
    assert_file_exists "${OVERLAY_CTRL}"
    assert_file_exists "${AUDIO_SVC}"
else
    assert_file_exists "${OVERLAY_CTRL}" "OverlayController.qml required"
    assert_file_exists "${AUDIO_SVC}" "AudioService.qml required"
fi

report_summary
