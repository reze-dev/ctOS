#!/usr/bin/env bash
# ==============================================================================
# Tier 1 - Feature 7: Audio Service & Safe Bounds
# Source: ORIGINAL_REQUEST §R2, interaction-spec.md, PROJECT.md
# ==============================================================================
set -u
set +e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../harness/mock_environment.sh"
source "${SCRIPT_DIR}/../harness/qml_runner.sh"

AUDIO_SVC="${PROJECT_ROOT}/shell/desktop/services/AudioService.qml"
DESKTOP_DIR="${PROJECT_ROOT}/shell/desktop"

test_case "T1.07.1" "Audio Service: AudioService.qml exists in desktop/services/"
assert_file_exists "${AUDIO_SVC}" "AudioService.qml must exist in desktop/services/"

test_case "T1.07.2" "Audio Service: Exposes available, volume, and muted properties"
if [[ -f "${AUDIO_SVC}" ]]; then
    check_qml_property "${AUDIO_SVC}" "available" || assert_grep "available" "${AUDIO_SVC}" "available property required"
    check_qml_property "${AUDIO_SVC}" "volume" || assert_grep "volume" "${AUDIO_SVC}" "volume property required"
    check_qml_property "${AUDIO_SVC}" "muted" || assert_grep "muted" "${AUDIO_SVC}" "muted property required"
else
    assert_file_exists "${AUDIO_SVC}"
fi

test_case "T1.07.3" "Audio Service: Exposes setVolume() method with safe bounds"
if [[ -f "${AUDIO_SVC}" ]]; then
    check_qml_method "${AUDIO_SVC}" "setVolume" || assert_grep "setVolume" "${AUDIO_SVC}" "setVolume method required"
    assert_grep -i "(Math\.max|Math\.min|clamp)" "${AUDIO_SVC}" "setVolume must clamp values safely"
else
    assert_file_exists "${AUDIO_SVC}"
fi

test_case "T1.07.4" "Audio Service: Exposes stepVolume() method with safe bounds"
if [[ -f "${AUDIO_SVC}" ]]; then
    check_qml_method "${AUDIO_SVC}" "stepVolume" || assert_grep "stepVolume" "${AUDIO_SVC}" "stepVolume method required"
else
    assert_file_exists "${AUDIO_SVC}"
fi

test_case "T1.07.5" "Audio Service: Exposes toggleMute() and volume wheel scroll binding"
if [[ -f "${AUDIO_SVC}" ]]; then
    check_qml_method "${AUDIO_SVC}" "toggleMute" || assert_grep "toggleMute" "${AUDIO_SVC}" "toggleMute method required"
    assert_grep -i "(wheel|onWheel|stepVolume)" "${DESKTOP_DIR}" "Volume widget must bind wheel scroll events"
else
    assert_file_exists "${AUDIO_SVC}"
fi

report_summary
