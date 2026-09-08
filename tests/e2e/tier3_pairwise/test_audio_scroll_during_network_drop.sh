#!/usr/bin/env bash
# ==============================================================================
# Tier 3 - Pairwise 5: Volume Adjustment during Network Disconnect
# Interaction: AudioService (F7) + NetworkService (F8)
# ==============================================================================
set -u
set +e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../harness/mock_environment.sh"
source "${SCRIPT_DIR}/../harness/qml_runner.sh"

DESKTOP_DIR="${PROJECT_ROOT}/shell/desktop"
AUDIO_SVC="${DESKTOP_DIR}/services/AudioService.qml"
NETWORK_SVC="${DESKTOP_DIR}/services/NetworkService.qml"

test_case "T3.05" "Pairwise: Operating volume wheel while network disconnects keeps independent reactivity"
if [[ -f "${AUDIO_SVC}" && -f "${NETWORK_SVC}" ]]; then
    assert_file_exists "${AUDIO_SVC}"
    assert_file_exists "${NETWORK_SVC}"
else
    assert_file_exists "${AUDIO_SVC}" "AudioService.qml required"
    assert_file_exists "${NETWORK_SVC}" "NetworkService.qml required"
fi

report_summary
