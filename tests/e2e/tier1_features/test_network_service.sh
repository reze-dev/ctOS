#!/usr/bin/env bash
# ==============================================================================
# Tier 1 - Feature 8: Network Service State
# Source: ORIGINAL_REQUEST §R2, interaction-spec.md, PROJECT.md
# ==============================================================================
set -u
set +e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../harness/mock_environment.sh"
source "${SCRIPT_DIR}/../harness/qml_runner.sh"

NETWORK_SVC="${PROJECT_ROOT}/shell/desktop/services/NetworkService.qml"
DESKTOP_DIR="${PROJECT_ROOT}/shell/desktop"

test_case "T1.08.1" "Network Service: NetworkService.qml exists in desktop/services/"
assert_file_exists "${NETWORK_SVC}" "NetworkService.qml must exist in desktop/services/"

test_case "T1.08.2" "Network Service: Exposes available and isConnected properties"
if [[ -f "${NETWORK_SVC}" ]]; then
    check_qml_property "${NETWORK_SVC}" "available" || assert_grep "available" "${NETWORK_SVC}" "available property required"
    check_qml_property "${NETWORK_SVC}" "isConnected" || assert_grep "isConnected" "${NETWORK_SVC}" "isConnected property required"
else
    assert_file_exists "${NETWORK_SVC}"
fi

test_case "T1.08.3" "Network Service: Exposes connectionType and networkName properties"
if [[ -f "${NETWORK_SVC}" ]]; then
    check_qml_property "${NETWORK_SVC}" "connectionType" || assert_grep "connectionType" "${NETWORK_SVC}" "connectionType property required"
    check_qml_property "${NETWORK_SVC}" "networkName" || assert_grep "networkName" "${NETWORK_SVC}" "networkName property required"
else
    assert_file_exists "${NETWORK_SVC}"
fi

test_case "T1.08.4" "Network Service: Network widget component exists in surfaces/components/"
if [[ -d "${DESKTOP_DIR}/surfaces" ]]; then
    local widget_found
    widget_found=$(find "${DESKTOP_DIR}/surfaces" -name "*Network*.qml" 2>/dev/null | head -n 1)
    if [[ -n "${widget_found}" ]]; then
        assert_file_exists "${widget_found}"
    else
        assert_file_exists "${DESKTOP_DIR}/surfaces/components/NetworkWidget.qml" "Network widget component required"
    fi
else
    assert_dir_exists "${DESKTOP_DIR}/surfaces"
fi

test_case "T1.08.5" "Network Service: Disconnected / unavailable state renders explicit --N/A--"
if [[ -d "${DESKTOP_DIR}" ]]; then
    assert_grep -i "(--N/A--|N/A|unavailable)" "${DESKTOP_DIR}" "Disconnected network status must render explicit --N/A--"
else
    assert_dir_exists "${DESKTOP_DIR}"
fi

report_summary
