#!/usr/bin/env bash
# ==============================================================================
# Tier 3 - Pairwise 19: Microphone Mute + Mic Volume Wheel Interaction
# Interaction: AudioService (F9) + SystemRail Mic Slider (F9)
# ==============================================================================
set -u
set +e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../harness/mock_environment.sh"
source "${SCRIPT_DIR}/../harness/qml_runner.sh"

AUDIO_SVC="${PROJECT_ROOT}/shell/desktop/services/AudioService.qml"

test_case "T3.19" "Pairwise: Positive wheel scroll on mic slider unmutes microphone source"
assert_file_exists "${AUDIO_SVC}"
if grep -q "stepMicVolume" "${AUDIO_SVC}"; then
    assert_grep -E "(\.micMuted\s*=\s*false|_source\.audio\.muted\s*=\s*false|!root\.micMuted)" "${AUDIO_SVC}" \
        "stepMicVolume must auto-unmute when positive delta applied"
else
    test_skip "Pending M2: stepMicVolume auto-unmute pending M2"
fi

report_summary
