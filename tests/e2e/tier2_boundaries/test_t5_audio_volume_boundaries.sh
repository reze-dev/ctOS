#!/usr/bin/env bash
# ==============================================================================
# Tier 2 - Feature 8 Boundaries: Hardware Volume Controls
# ==============================================================================
set -u
set +e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../harness/mock_environment.sh"
source "${SCRIPT_DIR}/../harness/qml_runner.sh"

AUDIO_SVC="${PROJECT_ROOT}/shell/desktop/services/AudioService.qml"

test_case "T2.22.1" "Audio Volume Boundary: Volume target > 1.0 strictly clamped to 1.0"
assert_file_exists "${AUDIO_SVC}"
assert_grep -E "Math\.min\(1(\.0)?,\s*target\)" "${AUDIO_SVC}" "Upper bound 1.0 clamping required"

test_case "T2.22.2" "Audio Volume Boundary: Volume target < 0.0 strictly clamped to 0.0"
assert_grep -E "Math\.max\(0(\.0)?,\s*" "${AUDIO_SVC}" "Lower bound 0.0 clamping required"

test_case "T2.22.3" "Audio Volume Boundary: Null PipeWire audio sink handled without throwing error"
assert_grep -E '(_sink\s*!==\s*null|_sink\?\.audio)' "${AUDIO_SVC}" "Safe null navigation for _sink required"

test_case "T2.22.4" "Audio Volume Boundary: available is false when PipeWire is not ready or sink is null"
assert_grep -E 'available:\s*Boolean\(Pipewire\.ready\s*&&\s*_sink\s*!==\s*null' "${AUDIO_SVC}" \
    "available property must guard on Pipewire.ready and _sink"

test_case "T2.22.5" "Audio Volume Boundary: Volume defaults to 0.0 when sink is unavailable"
assert_grep -E "available\s*\?\s*\(_sink\?\.audio\?\.volume\s*\?\?\s*0(\.0)?\)\s*:\s*0(\.0)?" "${AUDIO_SVC}" \
    "Volume must evaluate to 0.0 when unavailable"

report_summary
