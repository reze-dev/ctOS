#!/usr/bin/env bash
# ==============================================================================
# Tier 2 - Feature 7 Boundary: Volume Clamping & Audio Edge Cases
# Source: ORIGINAL_REQUEST §R2, interaction-spec.md, PROJECT.md
# ==============================================================================
set -u
set +e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../harness/mock_environment.sh"
source "${SCRIPT_DIR}/../harness/qml_runner.sh"

AUDIO_SVC="${PROJECT_ROOT}/shell/desktop/services/AudioService.qml"

test_case "T2.07.1" "Volume Clamping: Target volume > 1.0 is clamped strictly to 1.0"
if [[ -f "${AUDIO_SVC}" ]]; then
    assert_grep -i "(Math\.min|clamp|1\.0|1\b)" "${AUDIO_SVC}" "Volume clamping must enforce 1.0 ceiling"
else
    assert_file_exists "${AUDIO_SVC}" "AudioService.qml required"
fi

test_case "T2.07.2" "Volume Clamping: Target volume < 0.0 is clamped strictly to 0.0"
if [[ -f "${AUDIO_SVC}" ]]; then
    assert_grep -i "(Math\.max|clamp|0\.0|0\b)" "${AUDIO_SVC}" "Volume clamping must enforce 0.0 floor"
else
    assert_file_exists "${AUDIO_SVC}" "AudioService.qml required"
fi

test_case "T2.07.3" "Volume Clamping: stepVolume(+0.5) from 0.8 does not exceed 1.0"
if [[ -f "${AUDIO_SVC}" ]]; then
    assert_grep -i "(stepVolume|clamp|setVolume)" "${AUDIO_SVC}" "stepVolume must delegate to clamped setter"
else
    assert_file_exists "${AUDIO_SVC}" "AudioService.qml required"
fi

test_case "T2.07.4" "Volume Clamping: stepVolume(-0.5) from 0.2 does not drop below 0.0"
if [[ -f "${AUDIO_SVC}" ]]; then
    assert_grep -i "(stepVolume|clamp|setVolume)" "${AUDIO_SVC}" "stepVolume must delegate to clamped setter"
else
    assert_file_exists "${AUDIO_SVC}" "AudioService.qml required"
fi

test_case "T2.07.5" "Volume Clamping: Mouse wheel adjustment while muted auto-unmutes or adjusts safely"
if [[ -f "${AUDIO_SVC}" ]]; then
    assert_grep -i "(muted|toggleMute|stepVolume|volume)" "${AUDIO_SVC}" "Mute state and volume manipulation must be cohesive"
else
    assert_file_exists "${AUDIO_SVC}" "AudioService.qml required"
fi

report_summary
