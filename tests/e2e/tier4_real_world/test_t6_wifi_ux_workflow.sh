#!/usr/bin/env bash
# ==============================================================================
# Tier 4 - Scenario 13: Full Wi-Fi UX Workflow (Discovery, Routing & Connection)
# Exercised: AmbientBar NetworkWidget -> OverlayController -> SystemRail Submenu
#            -> SSID Discovery -> Password Prompt -> Safe Connect -> Disable Radio
#            -> Escape Back & Dismissal
# ==============================================================================
set -u
set +e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../harness/mock_environment.sh"
source "${SCRIPT_DIR}/../harness/qml_runner.sh"

NET_WIDGET="${PROJECT_ROOT}/shell/desktop/surfaces/components/NetworkWidget.qml"
OVERLAY_CTRL="${PROJECT_ROOT}/shell/desktop/core/OverlayController.qml"
SYSTEM_RAIL="${PROJECT_ROOT}/shell/desktop/surfaces/SystemRail.qml"
NET_SVC="${PROJECT_ROOT}/shell/desktop/services/NetworkService.qml"
SHELL_QML="${PROJECT_ROOT}/shell/shell.qml"

test_case "T4.13" "Real-World Scenario 13: Full Wi-Fi UX Workflow (Ambient Bar -> Submenu -> Connect -> Disable -> Escape)"
assert_file_exists "${NET_WIDGET}"
assert_file_exists "${OVERLAY_CTRL}"
assert_file_exists "${SYSTEM_RAIL}"
assert_file_exists "${NET_SVC}"
assert_file_exists "${SHELL_QML}"

if grep -qE '(availableNetworks)' "${NET_SVC}" && grep -qE '(currentView|currentSubmenu)' "${SYSTEM_RAIL}"; then
    # Step 1: Ambient Bar NetworkWidget integration
    assert_grep -E 'OverlayController\.(openWifiSubmenu|openSystemRailWithSubmenu)' "${NET_WIDGET}" \
        "Step 1: NetworkWidget must route to Wi-Fi Submenu"

    # Step 2: OverlayController deep-linking API
    assert_grep -E 'function\s+(openWifiSubmenu|openSystemRailWithSubmenu)' "${OVERLAY_CTRL}" \
        "Step 2: OverlayController must declare deep-linking method"

    # Step 3: System Rail view state machine
    assert_grep -E '(currentView\s*=\s*"wifi"|currentSubmenu\s*=\s*"wifi")' "${SYSTEM_RAIL}" \
        "Step 3: SystemRail must transition to wifi submenu view"

    # Step 4: Discovered SSIDs list
    assert_grep -E 'NetworkService\.availableNetworks' "${SYSTEM_RAIL}" \
        "Step 4: Submenu must bind to availableNetworks"

    # Step 5: Inline Terminal Password Prompt (PASSWORD >_)
    assert_grep -E '(PASSWORD\s*>_|PASSWORD)' "${SYSTEM_RAIL}" \
        "Step 5: Unknown network selection must reveal PASSWORD >_ prompt"
    assert_grep -E '(TextInput|TextField)' "${SYSTEM_RAIL}" \
        "Step 5: Password prompt must host inline TextInput"

    # Step 6: Safe connection execution (zero shell injection)
    assert_not_grep -E '\[\s*"sh"\s*,\s*"-c"' "${NET_SVC}" \
        "Step 6: NetworkService must not use sh -c for connection"
    assert_grep -E '(connectToNetwork|connectNetwork|connectWithPsk)' "${NET_SVC}" \
        "Step 6: NetworkService must provide connection dispatcher"

    # Step 7: Dedicated [DISABLE WI-FI] button
    assert_grep -E '("DISABLE WI-FI"|"DISABLE"|btnDisableWifi)' "${SYSTEM_RAIL}" \
        "Step 7: Prominent [DISABLE WI-FI] button required"
    assert_grep -E '(NetworkService\.toggleWifi|NetworkService\.setWifiEnabled)' "${SYSTEM_RAIL}" \
        "Step 7: Button must toggle Wi-Fi radio"

    # Step 8: Escape key navigation hierarchy
    assert_grep -E 'Keys\.onEscapePressed' "${SYSTEM_RAIL}" \
        "Step 8: Escape keypress must unwind submenu navigation"

    # Step 9: Scrim backdrop dismissal
    assert_grep "scrimBackdrop" "${SHELL_QML}" \
        "Step 9: Scrim backdrop must be available in shell.qml"

    # Step 10: Engineering compliance audit
    assert_not_grep -i "greeter" "${NET_SVC}" "Step 10: Zero greeter in NetworkService"
    assert_not_grep -i "greeter" "${SYSTEM_RAIL}" "Step 10: Zero greeter in SystemRail"
    check_no_polling_loops "${NET_SVC}"
    check_no_polling_loops "${SYSTEM_RAIL}"
else
    test_skip "Pending M2: End-to-end Wi-Fi UX workflow pending M2 implementation"
fi

report_summary
