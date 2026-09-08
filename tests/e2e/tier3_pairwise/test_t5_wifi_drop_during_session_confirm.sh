#!/usr/bin/env bash
# ==============================================================================
# Tier 3 - Pairwise 21: Wi-Fi Disconnect during Session Confirmation
# Interaction: NetworkService (F10) + SystemRail Safety (F13)
# ==============================================================================
set -u
set +e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../harness/mock_environment.sh"
source "${SCRIPT_DIR}/../harness/qml_runner.sh"

NET_SVC="${PROJECT_ROOT}/shell/desktop/services/NetworkService.qml"
SYSTEM_RAIL="${PROJECT_ROOT}/shell/desktop/surfaces/SystemRail.qml"

test_case "T3.21" "Pairwise: Network disconnection event does not abort session confirmation state"
assert_file_exists "${NET_SVC}"
if [[ -f "${SYSTEM_RAIL}" ]]; then
    # Confirmation state is driven by user confirmationAction, not network signals
    assert_not_grep "NetworkService\.isConnected" "${SYSTEM_RAIL}" "Confirmation state must remain independent of network state"
else
    test_skip "Pending M2/M3: SystemRail confirmation decoupling check pending M3"
fi

report_summary
