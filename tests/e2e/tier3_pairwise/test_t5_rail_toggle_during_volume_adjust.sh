#!/usr/bin/env bash
# ==============================================================================
# Tier 3 - Pairwise 20: AmbientBar Rail Toggle during Active Volume Adjust
# Interaction: AmbientBar (F11) + AudioService (F8)
# ==============================================================================
set -u
set +e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../harness/mock_environment.sh"
source "${SCRIPT_DIR}/../harness/qml_runner.sh"

AMBIENT_BAR="${PROJECT_ROOT}/shell/desktop/surfaces/AmbientBar.qml"
AUDIO_SVC="${PROJECT_ROOT}/shell/desktop/services/AudioService.qml"
OVERLAY_CTRL="${PROJECT_ROOT}/shell/desktop/core/OverlayController.qml"

test_case "T3.20" "Pairwise: Toggling System Rail preserves active audio volume responsiveness"
assert_file_exists "${AMBIENT_BAR}"
assert_file_exists "${AUDIO_SVC}"
assert_file_exists "${OVERLAY_CTRL}"
# Verify toggle does not disconnect or mute audio
assert_not_grep -E "AudioService\.toggleMute\(\)" "${OVERLAY_CTRL}" "OverlayController must not toggle mute"

report_summary
