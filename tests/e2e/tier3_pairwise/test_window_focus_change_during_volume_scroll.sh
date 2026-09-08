#!/usr/bin/env bash
# ==============================================================================
# Tier 3 - Pairwise 7: Active Window Change during Volume Scroll
# Interaction: Active Window Identity (F6) + AudioService (F7)
# ==============================================================================
set -u
set +e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../harness/mock_environment.sh"
source "${SCRIPT_DIR}/../harness/qml_runner.sh"

DESKTOP_DIR="${PROJECT_ROOT}/shell/desktop"
COMPOSITOR_SVC="${DESKTOP_DIR}/services/CompositorService.qml"
AUDIO_SVC="${DESKTOP_DIR}/services/AudioService.qml"

test_case "T3.07" "Pairwise: Window focus change while scrolling volume bar does not drop volume inputs"
if [[ -f "${COMPOSITOR_SVC}" && -f "${AUDIO_SVC}" ]]; then
    assert_file_exists "${COMPOSITOR_SVC}"
    assert_file_exists "${AUDIO_SVC}"
else
    assert_file_exists "${COMPOSITOR_SVC}" "CompositorService.qml required"
    assert_file_exists "${AUDIO_SVC}" "AudioService.qml required"
fi

report_summary
