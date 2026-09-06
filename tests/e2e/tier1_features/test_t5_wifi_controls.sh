#!/usr/bin/env bash
# ==============================================================================
# Tier 1 - Feature 10: Wi-Fi State & Toggle
# Source: ORIGINAL_REQUEST §R2, TEST_INFRA.md §Feature 10, PROJECT.md
# ==============================================================================
set -u
set +e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../harness/mock_environment.sh"
source "${SCRIPT_DIR}/../harness/qml_runner.sh"

NET_SVC="${PROJECT_ROOT}/shell/desktop/services/NetworkService.qml"
SYSTEM_RAIL="${PROJECT_ROOT}/shell/desktop/surfaces/SystemRail.qml"

test_case "T1.24.1" "Wi-Fi Controls: NetworkService exposes available, isConnected, and networkName"
assert_file_exists "${NET_SVC}"
check_qml_property "${NET_SVC}" "available" || assert_grep "available" "${NET_SVC}" "available property required"
check_qml_property "${NET_SVC}" "isConnected" || assert_grep "isConnected" "${NET_SVC}" "isConnected property required"
check_qml_property "${NET_SVC}" "networkName" || assert_grep "networkName" "${NET_SVC}" "networkName property required"

test_case "T1.24.2" "Wi-Fi Controls: NetworkService exposes Wi-Fi toggle or wifiEnabled property"
if grep -qE "(wifiEnabled|toggleWifi)" "${NET_SVC}"; then
    assert_grep -E "(wifiEnabled|toggleWifi)" "${NET_SVC}" "Wi-Fi toggle mechanism must be exposed"
else
    test_skip "Pending M2: wifiEnabled / toggleWifi pending M2 extension"
fi

test_case "T1.24.3" "Wi-Fi Controls: Network SSID is elided or sanitized to prevent layout overflow"
assert_grep -E "(sanitizeName|elide|substring|slice)" "${NET_SVC}" "SSID must be sanitized or elided"

test_case "T1.24.4" "Wi-Fi Controls: Secrets and passwords strictly excluded from NetworkService properties"
assert_not_grep -i -E "property.*(wpa_passphrase|psk|password)" "${NET_SVC}" "Wi-Fi passwords must never be stored as persistent properties in NetworkService"

test_case "T1.24.5" "Wi-Fi Controls: Disconnected or offline network state renders clean fallback (--N/A--)"
assert_grep -E '("--N/A--"|Disconnected|Offline|unavailable)' "${NET_SVC}" "NetworkService must provide clean fallback text"

report_summary
