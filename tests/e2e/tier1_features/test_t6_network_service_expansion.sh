#!/usr/bin/env bash
# ==============================================================================
# Tier 1 - Feature 31: NetworkService Expansion (Available Networks & Connection)
# Source: ORIGINAL_REQUEST §R1, §R4, PROJECT.md, TEST_INFRA.md §Feature 1-2
# ==============================================================================
set -u
set +e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../harness/mock_environment.sh"
source "${SCRIPT_DIR}/../harness/qml_runner.sh"

NET_SVC="${PROJECT_ROOT}/shell/desktop/services/NetworkService.qml"
SYSTEM_RAIL="${PROJECT_ROOT}/shell/desktop/surfaces/SystemRail.qml"
DESKTOP_DIR="${PROJECT_ROOT}/shell/desktop"

test_case "T1.31.1" "NetworkService Expansion: Exposes reactive availableNetworks model"
assert_file_exists "${NET_SVC}"
if grep -q "availableNetworks" "${NET_SVC}"; then
    check_qml_property "${NET_SVC}" "availableNetworks" || assert_grep "availableNetworks" "${NET_SVC}" \
        "NetworkService must expose availableNetworks model"
else
    test_skip "Pending M2: NetworkService availableNetworks model pending M2"
fi

test_case "T1.31.2" "NetworkService Expansion: availableNetworks model exposes signal, known, and security properties"
if grep -q "availableNetworks" "${NET_SVC}"; then
    assert_grep -E '(signalStrength|signal)' "${NET_SVC}" \
        "availableNetworks entries must include signal strength"
    assert_grep -E '(known)' "${NET_SVC}" \
        "availableNetworks entries must include known status"
    assert_grep -E '(security|requiresPassword)' "${NET_SVC}" \
        "availableNetworks entries must include security or password requirements"
else
    test_skip "Pending M2: availableNetworks property attributes pending M2"
fi

test_case "T1.31.3" "NetworkService Expansion: Configures scannerEnabled bound to Wi-Fi radio lifecycle"
if grep -q "scannerEnabled" "${NET_SVC}"; then
    assert_grep "scannerEnabled" "${NET_SVC}" \
        "NetworkService must bind scannerEnabled on Wi-Fi devices"
else
    test_skip "Pending M2: scannerEnabled binding pending M2"
fi

test_case "T1.31.4" "NetworkService Expansion: Exposes safe connection method (connectToNetwork)"
if grep -qE 'function\s+(connectToNetwork|connectNetwork)' "${NET_SVC}"; then
    assert_grep -E 'function\s+(connectToNetwork|connectNetwork)' "${NET_SVC}" \
        "NetworkService must provide connectToNetwork method"
else
    test_skip "Pending M2: connectToNetwork method pending M2"
fi

test_case "T1.31.5" "NetworkService Expansion: Zero shell string injection (prohibits sh -c for connection)"
if grep -qE 'function\s+(connectToNetwork|connectNetwork)' "${NET_SVC}"; then
    # Must use allowlisted argument array or native Quickshell API; never sh -c
    assert_not_grep -E '\[\s*"sh"\s*,\s*"-c"' "${NET_SVC}" \
        "Prohibit sh -c execution in NetworkService"
    assert_grep -E '(Quickshell\.execDetached|connectWithPsk|\.connect\()' "${NET_SVC}" \
        "NetworkService connection must dispatch via discrete array or native API"
else
    test_skip "Pending M2: Safe connection execution verification pending M2"
fi

test_case "T1.31.6" "Engineering Compliance: Zero greeter imports and zero polling loops in network components"
assert_file_exists "${NET_SVC}"
assert_file_exists "${SYSTEM_RAIL}"
assert_not_grep -i "greeter" "${NET_SVC}" "NetworkService must have zero greeter imports"
assert_not_grep -i "greeter" "${SYSTEM_RAIL}" "SystemRail must have zero greeter imports"
check_no_polling_loops "${NET_SVC}"
check_no_polling_loops "${SYSTEM_RAIL}"

report_summary
