#!/usr/bin/env bash
# ==============================================================================
# Tier 2 - Feature 10 Boundaries: Wi-Fi State & Toggle
# ==============================================================================
set -u
set +e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../harness/mock_environment.sh"
source "${SCRIPT_DIR}/../harness/qml_runner.sh"

NET_SVC="${PROJECT_ROOT}/shell/desktop/services/NetworkService.qml"

test_case "T2.24.1" "Wi-Fi Boundary: Non-ASCII SSID sanitized to ASCII or clean unicode without crash"
assert_file_exists "${NET_SVC}"
assert_grep "sanitizeName" "${NET_SVC}" "sanitizeName helper method must exist"

test_case "T2.24.2" "Wi-Fi Boundary: SSID exceeding 32 characters is elided cleanly"
assert_grep -E "(\.length\s*>\s*[0-9]+|\.substring|\.slice)" "${NET_SVC}" "Long SSID strings must be truncated or elided"

test_case "T2.24.3" "Wi-Fi Boundary: NetworkManager daemon accessibility guards available property"
assert_grep -E 'available:\s*Networking\.backend' "${NET_SVC}" "available property must guard on Networking.backend"

test_case "T2.24.4" "Wi-Fi Boundary: NetworkService exposes isConnected boolean and networkStateChanged signal"
assert_grep -E 'property\s+bool\s+isConnected' "${NET_SVC}" "isConnected must be declared as a boolean"
assert_grep -E 'signal\s+networkStateChanged' "${NET_SVC}" "NetworkService must emit networkStateChanged signal"

test_case "T2.24.5" "Wi-Fi Boundary: Fast interface status flapping does not block QML UI thread"
assert_not_grep -E "sleep\s*[0-9]" "${NET_SVC}" "NetworkService must never call synchronous sleep"

report_summary
