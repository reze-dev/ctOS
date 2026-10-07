#!/usr/bin/env bash
# ==============================================================================
# Tier 2 - Boundary & Corner Cases: Living Notch Volume Scroll Clamping
# Source: ORIGINAL_REQUEST.md §R2, PROJECT.md §Feature Inventory F12, F13
# ==============================================================================
set -u
set +e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../harness/mock_environment.sh"
source "${SCRIPT_DIR}/../harness/qml_runner.sh"

AUDIO_SVC="${PROJECT_ROOT}/shell/desktop/services/AudioService.qml"
LIVING_NOTCH="${PROJECT_ROOT}/shell/desktop/surfaces/components/LivingNotch.qml"

test_case "T2.VOL.01" "Volume Boundary: Math.max(0.0, Math.min(1.0, target)) clamping in AudioService"
assert_file_exists "${AUDIO_SVC}"
assert_grep 'Math\.max\(0\.0,\s*Math\.min\(1\.0' "${AUDIO_SVC}" \
    "AudioService setVolume must strictly clamp volume to [0.0, 1.0]"

test_case "T2.VOL.02" "Volume Boundary: Positive wheel step un-mutes muted sink"
assert_grep 'root\.muted\s*&&\s*delta\s*>\s*0' "${AUDIO_SVC}" \
    "AudioService stepVolume must un-mute on positive delta"

test_case "T2.VOL.03" "Volume Boundary: Negative step delta on zero volume prevents underflow"
assert_grep 'root\.setVolume\(root\.volume\s*\+\s*delta\)' "${AUDIO_SVC}" \
    "AudioService stepVolume delegates to clamped setVolume"

test_case "T2.VOL.04" "Volume Wheel: Living Notch wheel handler passes delta safely"
if [[ -f "${LIVING_NOTCH}" ]]; then
    assert_grep -E '(wheel\.angleDelta|stepVolume)' "${LIVING_NOTCH}" \
        "Living Notch WheelHandler/MouseArea must invoke AudioService.stepVolume"
else
    assert_grep 'stepVolume\(delta:\s*real\)' "${AUDIO_SVC}" \
        "AudioService stepVolume signature accepts delta parameter"
fi

report_summary
