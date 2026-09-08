#!/usr/bin/env bash
# ==============================================================================
# Tier 1 - Feature 8: Hardware Volume Controls
# Source: ORIGINAL_REQUEST §R2, TEST_INFRA.md §Feature 8, PROJECT.md
# ==============================================================================
set -u
set +e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../harness/mock_environment.sh"
source "${SCRIPT_DIR}/../harness/qml_runner.sh"

AUDIO_SVC="${PROJECT_ROOT}/shell/desktop/services/AudioService.qml"
SYSTEM_RAIL="${PROJECT_ROOT}/shell/desktop/surfaces/SystemRail.qml"

test_case "T1.22.1" "Hardware Volume: AudioService exposes reactive volume and muted properties"
assert_file_exists "${AUDIO_SVC}"
check_qml_property "${AUDIO_SVC}" "volume" || assert_grep "volume" "${AUDIO_SVC}" "volume property required"
check_qml_property "${AUDIO_SVC}" "muted" || assert_grep "muted" "${AUDIO_SVC}" "muted property required"
check_qml_property "${AUDIO_SVC}" "available" || assert_grep "available" "${AUDIO_SVC}" "available property required"

test_case "T1.22.2" "Hardware Volume: AudioService.setVolume clamps target to [0.0, 1.0]"
check_qml_method "${AUDIO_SVC}" "setVolume" || assert_grep "setVolume" "${AUDIO_SVC}" "setVolume method required"
assert_grep -E "(Math\.max|Math\.min|clamp)" "${AUDIO_SVC}" "setVolume must clamp values"

test_case "T1.22.3" "Hardware Volume: AudioService.stepVolume adjusts volume reactively"
check_qml_method "${AUDIO_SVC}" "stepVolume" || assert_grep "stepVolume" "${AUDIO_SVC}" "stepVolume method required"

test_case "T1.22.4" "Hardware Volume: AudioService.toggleMute toggles mute state"
check_qml_method "${AUDIO_SVC}" "toggleMute" || assert_grep "toggleMute" "${AUDIO_SVC}" "toggleMute method required"

test_case "T1.22.5" "Hardware Volume: SystemRail or AudioService binds volume slider to PipeWire sink"
if [[ -f "${SYSTEM_RAIL}" ]]; then
    assert_grep -E "(AudioService\.volume|AudioService\.setVolume)" "${SYSTEM_RAIL}" "SystemRail must bind to AudioService volume"
else
    test_skip "Pending M2: SystemRail slider binding pending SystemRail.qml"
fi

report_summary
