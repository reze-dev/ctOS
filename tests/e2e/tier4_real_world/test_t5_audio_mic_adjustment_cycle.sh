#!/usr/bin/env bash
# ==============================================================================
# Tier 4 - Scenario 8: Full Audio and Mic Adjustment Cycle
# Exercised: Output Volume, Mic Volume, Mute Toggles, Step Clamping
# ==============================================================================
set -u
set +e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../harness/mock_environment.sh"
source "${SCRIPT_DIR}/../harness/qml_runner.sh"

AUDIO_SVC="${PROJECT_ROOT}/shell/desktop/services/AudioService.qml"
SYSTEM_RAIL="${PROJECT_ROOT}/shell/desktop/surfaces/SystemRail.qml"

test_case "T4.08" "Real-World Scenario 8: Full Audio and Mic Adjustment Cycle"
assert_file_exists "${AUDIO_SVC}"

# 1. Output volume methods and clamping
check_qml_method "${AUDIO_SVC}" "setVolume" || assert_grep "setVolume" "${AUDIO_SVC}" "setVolume required"
check_qml_method "${AUDIO_SVC}" "stepVolume" || assert_grep "stepVolume" "${AUDIO_SVC}" "stepVolume required"
check_qml_method "${AUDIO_SVC}" "toggleMute" || assert_grep "toggleMute" "${AUDIO_SVC}" "toggleMute required"

# 2. Clamping in output volume
assert_grep -E "Math\.min\(1(\.0)?,\s*target\)" "${AUDIO_SVC}" "Output volume upper clamp required"
assert_grep -E "Math\.max\(0(\.0)?,\s*" "${AUDIO_SVC}" "Output volume lower clamp required"

# 3. Mic volume methods and clamping
if grep -q "setMicVolume" "${AUDIO_SVC}"; then
    check_qml_method "${AUDIO_SVC}" "setMicVolume" || assert_grep "setMicVolume" "${AUDIO_SVC}" "setMicVolume required"
    check_qml_method "${AUDIO_SVC}" "stepMicVolume" || assert_grep "stepMicVolume" "${AUDIO_SVC}" "stepMicVolume required"
    check_qml_method "${AUDIO_SVC}" "toggleMicMute" || assert_grep "toggleMicMute" "${AUDIO_SVC}" "toggleMicMute required"
else
    test_skip "Pending M2: Microphone volume methods pending M2 implementation"
fi

report_summary
