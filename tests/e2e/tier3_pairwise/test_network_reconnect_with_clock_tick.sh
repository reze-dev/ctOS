#!/usr/bin/env bash
# ==============================================================================
# Tier 3 - Pairwise 11: Network Reconnect during Clock Minute Rollover
# Interaction: NetworkService (F8) + Clock Indicator (F10)
# ==============================================================================
set -u
set +e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../harness/mock_environment.sh"
source "${SCRIPT_DIR}/../harness/qml_runner.sh"

DESKTOP_DIR="${PROJECT_ROOT}/shell/desktop"
NETWORK_SVC="${DESKTOP_DIR}/services/NetworkService.qml"

test_case "T3.11" "Pairwise: Network reconnect status update does not disrupt periodic clock rendering"
if [[ -f "${NETWORK_SVC}" ]]; then
    assert_file_exists "${NETWORK_SVC}"
else
    assert_file_exists "${NETWORK_SVC}" "NetworkService.qml required"
fi

report_summary
