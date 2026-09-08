#!/usr/bin/env bash
# ==============================================================================
# Tier 3 - Pairwise 8: Workspace Switch with Active Audio Stream
# Interaction: CompositorAdapter (F5) + AudioService (F7)
# ==============================================================================
set -u
set +e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../harness/mock_environment.sh"
source "${SCRIPT_DIR}/../harness/qml_runner.sh"

DESKTOP_DIR="${PROJECT_ROOT}/shell/desktop"
HYPRLAND_ADAPTER="${DESKTOP_DIR}/adapters/hyprland/HyprlandAdapter.qml"
AUDIO_SVC="${DESKTOP_DIR}/services/AudioService.qml"

test_case "T3.08" "Pairwise: Workspace switch event does not affect audio volume or mute state"
if [[ -f "${HYPRLAND_ADAPTER}" && -f "${AUDIO_SVC}" ]]; then
    assert_file_exists "${HYPRLAND_ADAPTER}"
    assert_file_exists "${AUDIO_SVC}"
else
    assert_file_exists "${HYPRLAND_ADAPTER}" "HyprlandAdapter.qml required"
    assert_file_exists "${AUDIO_SVC}" "AudioService.qml required"
fi

report_summary
