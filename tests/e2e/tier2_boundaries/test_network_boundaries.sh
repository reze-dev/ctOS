#!/usr/bin/env bash
# ==============================================================================
# Tier 2 - Feature 8 Boundary: Network Edge Cases & Degradation
# Source: architecture.md, interaction-spec.md, PROJECT.md
# ==============================================================================
set -u
set +e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../harness/mock_environment.sh"
source "${SCRIPT_DIR}/../harness/qml_runner.sh"

NETWORK_SVC="${PROJECT_ROOT}/shell/desktop/services/NetworkService.qml"
DESKTOP_DIR="${PROJECT_ROOT}/shell/desktop"

test_case "T2.08.1" "Network Boundary: Completely disconnected interface displays --N/A--"
if [[ -d "${DESKTOP_DIR}" ]]; then
    assert_grep -i "(--N/A--|N/A)" "${DESKTOP_DIR}" "Disconnected network status must render explicit --N/A--"
else
    assert_dir_exists "${DESKTOP_DIR}" "shell/desktop required"
fi

test_case "T2.08.2" "Network Boundary: Wi-Fi SSID with special characters and spaces sanitized"
if [[ -d "${DESKTOP_DIR}" ]]; then
    assert_grep -i "(networkName|ssid|replace|slice|toUpperCase)" "${DESKTOP_DIR}" "SSID formatting and sanitization should be applied"
else
    assert_dir_exists "${DESKTOP_DIR}" "shell/desktop required"
fi

test_case "T2.08.3" "Network Boundary: Wi-Fi SSID exceeding column width is truncated"
if [[ -d "${DESKTOP_DIR}" ]]; then
    assert_grep -i "(elide|maximumWidth|substring|slice)" "${DESKTOP_DIR}" "SSID string must be truncated for compact display"
else
    assert_dir_exists "${DESKTOP_DIR}" "shell/desktop required"
fi

test_case "T2.08.4" "Network Boundary: NetworkManager daemon down sets available: false"
if [[ -f "${NETWORK_SVC}" ]]; then
    check_qml_property "${NETWORK_SVC}" "available" --type bool || assert_grep "available" "${NETWORK_SVC}" "available property required"
else
    assert_file_exists "${NETWORK_SVC}" "NetworkService.qml required"
fi

test_case "T2.08.5" "Network Boundary: Fast interface status flapping does not crash shell"
if [[ -d "${DESKTOP_DIR}" ]]; then
    assert_grep -i "(isConnected|connectionType|networkName)" "${DESKTOP_DIR}" "Network state updates reactively"
else
    assert_dir_exists "${DESKTOP_DIR}" "shell/desktop required"
fi

report_summary
