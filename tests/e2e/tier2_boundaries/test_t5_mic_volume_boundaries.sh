#!/usr/bin/env bash
# ==============================================================================
# Tier 2 - Feature 9 Boundaries: Hardware Microphone Controls
# ==============================================================================
set -u
set +e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../harness/mock_environment.sh"
source "${SCRIPT_DIR}/../harness/qml_runner.sh"

AUDIO_SVC="${PROJECT_ROOT}/shell/desktop/services/AudioService.qml"

test_case "T2.23.1" "Mic Volume Boundary: Mic volume target > 1.0 strictly clamped to 1.0"
if grep -q "setMicVolume" "${AUDIO_SVC}"; then
    assert_grep -E "Math\.min\(1(\.0)?,\s*target\)" "${AUDIO_SVC}" "Upper bound 1.0 clamping required in setMicVolume"
else
    test_skip "Pending M2: setMicVolume clamping pending M2"
fi

test_case "T2.23.2" "Mic Volume Boundary: Mic volume target < 0.0 strictly clamped to 0.0"
if grep -q "setMicVolume" "${AUDIO_SVC}"; then
    assert_grep -E "Math\.max\(0(\.0)?,\s*" "${AUDIO_SVC}" "Lower bound 0.0 clamping required in setMicVolume"
else
    test_skip "Pending M2: setMicVolume lower clamp pending M2"
fi

test_case "T2.23.3" "Mic Volume Boundary: Null PipeWire audio source handled cleanly (headless system)"
if grep -q "micAvailable" "${AUDIO_SVC}"; then
    assert_grep -E '(_source\s*!==\s*null|_source\?\.audio)' "${AUDIO_SVC}" "Safe null navigation for _source required"
else
    test_skip "Pending M2: micAvailable safe null check pending M2"
fi

test_case "T2.23.4" "Mic Volume Boundary: micVolume defaults to 0.0 when source is unavailable"
if grep -q "micVolume" "${AUDIO_SVC}"; then
    assert_grep -E "micAvailable\s*\?\s*.*:\s*0(\.0)?" "${AUDIO_SVC}" "micVolume must evaluate to 0.0 when unavailable"
else
    test_skip "Pending M2: micVolume default value pending M2"
fi

test_case "T2.23.5" "Mic Volume Boundary: Hardware external mic mute reflection without error"
if grep -q "micMuted" "${AUDIO_SVC}"; then
    assert_grep -E '(_source\?\.audio\?\.muted|\.muted)' "${AUDIO_SVC}" "Must bind micMuted to hardware source state"
else
    test_skip "Pending M2: micMuted hardware binding pending M2"
fi

report_summary
