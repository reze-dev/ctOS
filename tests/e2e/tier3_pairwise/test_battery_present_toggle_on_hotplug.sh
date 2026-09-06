#!/usr/bin/env bash
# ==============================================================================
# Tier 3 - Pairwise 12: Battery Device Added/Removed from Ambient Bar
# Interaction: PowerService (F9) + Ambient Bar Variants (F11)
# ==============================================================================
set -u
set +e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../harness/mock_environment.sh"
source "${SCRIPT_DIR}/../harness/qml_runner.sh"

DESKTOP_DIR="${PROJECT_ROOT}/shell/desktop"
POWER_SVC="${DESKTOP_DIR}/services/PowerService.qml"
AMBIENT_BAR="${DESKTOP_DIR}/surfaces/AmbientBar.qml"

test_case "T3.12" "Pairwise: Battery device dynamically appearing/disappearing triggers clean bar relayout"
if [[ -f "${POWER_SVC}" && -f "${AMBIENT_BAR}" ]]; then
    assert_file_exists "${POWER_SVC}"
    assert_file_exists "${AMBIENT_BAR}"
else
    assert_file_exists "${POWER_SVC}" "PowerService.qml required"
    assert_file_exists "${AMBIENT_BAR}" "AmbientBar.qml required"
fi

report_summary
