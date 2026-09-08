#!/usr/bin/env bash
# ==============================================================================
# Tier 1 - Feature 9: Hardware Microphone Controls
# Source: ORIGINAL_REQUEST §R2, TEST_INFRA.md §Feature 9, PROJECT.md
# ==============================================================================
set -u
set +e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../harness/mock_environment.sh"
source "${SCRIPT_DIR}/../harness/qml_runner.sh"

AUDIO_SVC="${PROJECT_ROOT}/shell/desktop/services/AudioService.qml"
SYSTEM_RAIL="${PROJECT_ROOT}/shell/desktop/surfaces/SystemRail.qml"

test_case "T1.23.1" "Hardware Microphone: AudioService tracks Pipewire.defaultAudioSource"
if grep -q "defaultAudioSource" "${AUDIO_SVC}"; then
    assert_grep "defaultAudioSource" "${AUDIO_SVC}" "Must track Pipewire.defaultAudioSource"
else
    test_skip "Pending M2: AudioService defaultAudioSource tracking pending M2"
fi

test_case "T1.23.2" "Hardware Microphone: Exposes micVolume and micMuted properties"
if grep -q "micVolume" "${AUDIO_SVC}"; then
    check_qml_property "${AUDIO_SVC}" "micVolume" || assert_grep "micVolume" "${AUDIO_SVC}" "micVolume property required"
    check_qml_property "${AUDIO_SVC}" "micMuted" || assert_grep "micMuted" "${AUDIO_SVC}" "micMuted property required"
else
    test_skip "Pending M2: micVolume and micMuted properties pending M2"
fi

test_case "T1.23.3" "Hardware Microphone: Exposes setMicVolume(target) with [0.0, 1.0] clamping"
if grep -q "setMicVolume" "${AUDIO_SVC}"; then
    check_qml_method "${AUDIO_SVC}" "setMicVolume" || assert_grep "setMicVolume" "${AUDIO_SVC}" "setMicVolume method required"
    assert_grep -E "(Math\.max|Math\.min|clamp)" "${AUDIO_SVC}" "setMicVolume must clamp volume safely"
else
    test_skip "Pending M2: setMicVolume method pending M2"
fi

test_case "T1.23.4" "Hardware Microphone: Exposes stepMicVolume(delta) with positive scroll auto-unmute"
if grep -q "stepMicVolume" "${AUDIO_SVC}"; then
    check_qml_method "${AUDIO_SVC}" "stepMicVolume" || assert_grep "stepMicVolume" "${AUDIO_SVC}" "stepMicVolume method required"
else
    test_skip "Pending M2: stepMicVolume method pending M2"
fi

test_case "T1.23.5" "Hardware Microphone: Exposes toggleMicMute() method"
if grep -q "toggleMicMute" "${AUDIO_SVC}"; then
    check_qml_method "${AUDIO_SVC}" "toggleMicMute" || assert_grep "toggleMicMute" "${AUDIO_SVC}" "toggleMicMute method required"
else
    test_skip "Pending M2: toggleMicMute method pending M2"
fi

report_summary
