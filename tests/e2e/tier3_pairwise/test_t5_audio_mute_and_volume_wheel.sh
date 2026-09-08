#!/usr/bin/env bash
# ==============================================================================
# Tier 3 - Pairwise 16: Audio Mute + Volume Wheel Interaction
# Interaction: AudioService (F8) + SystemRail / VolumeWidget (F8)
# ==============================================================================
set -u
set +e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../harness/mock_environment.sh"
source "${SCRIPT_DIR}/../harness/qml_runner.sh"

AUDIO_SVC="${PROJECT_ROOT}/shell/desktop/services/AudioService.qml"
DESKTOP_DIR="${PROJECT_ROOT}/shell/desktop"

test_case "T3.16" "Pairwise: Positive wheel scroll on volume slider unmutes sink"
assert_file_exists "${AUDIO_SVC}"
# In AudioService stepVolume, positive delta while muted unmutes sink
if grep -q "stepVolume" "${AUDIO_SVC}"; then
    assert_grep -E "(\.muted\s*=\s*false|!root\.muted)" "${AUDIO_SVC}" \
        "AudioService stepVolume must auto-unmute when positive delta applied"
else
    test_skip "Pending M2: stepVolume auto-unmute check pending M2"
fi

report_summary
