#!/usr/bin/env bash
# ==============================================================================
# Tier 3 - Pairwise 1: Overlay Summon while Audio Muted
# Interaction: OverlayController (F3) + AudioService (F7)
# ==============================================================================
set -u
set +e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../harness/mock_environment.sh"
source "${SCRIPT_DIR}/../harness/qml_runner.sh"

DESKTOP_DIR="${PROJECT_ROOT}/shell/desktop"
OVERLAY_CTRL="${DESKTOP_DIR}/core/OverlayController.qml"
AUDIO_SVC="${DESKTOP_DIR}/services/AudioService.qml"

test_case "T3.01" "Pairwise: Overlay summon maintains audio muted state without side-effects"
if [[ -f "${OVERLAY_CTRL}" && -f "${AUDIO_SVC}" ]]; then
    # Verify OverlayController does not mutate or touch AudioService state
    assert_not_grep "AudioService" "${OVERLAY_CTRL}" "OverlayController must be decoupled from audio state"
    assert_file_exists "${AUDIO_SVC}"
else
    assert_file_exists "${OVERLAY_CTRL}" "OverlayController.qml required"
    assert_file_exists "${AUDIO_SVC}" "AudioService.qml required"
fi

report_summary
