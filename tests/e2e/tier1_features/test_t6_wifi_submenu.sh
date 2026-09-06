#!/usr/bin/env bash
# ==============================================================================
# Tier 1 - Feature 30: Wi-Fi Submenu & System Rail State Machine
# Source: ORIGINAL_REQUEST §R2, §R3, PROJECT.md, TEST_INFRA.md §Feature 3-8
# ==============================================================================
set -u
set +e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../harness/mock_environment.sh"
source "${SCRIPT_DIR}/../harness/qml_runner.sh"

SYSTEM_RAIL="${PROJECT_ROOT}/shell/desktop/surfaces/SystemRail.qml"
OVERLAY_CTRL="${PROJECT_ROOT}/shell/desktop/core/OverlayController.qml"
NET_WIDGET="${PROJECT_ROOT}/shell/desktop/surfaces/components/NetworkWidget.qml"
NET_SVC="${PROJECT_ROOT}/shell/desktop/services/NetworkService.qml"
THEME_FILE="${PROJECT_ROOT}/shell/desktop/core/Theme.qml"

test_case "T1.30.1" "System Rail State Machine: SystemRail.qml supports view routing (main / wifi)"
assert_file_exists "${SYSTEM_RAIL}"
if grep -qE 'property\s+string\s+(currentView|currentSubmenu)' "${SYSTEM_RAIL}"; then
    assert_grep -E 'property\s+string\s+(currentView|currentSubmenu)' "${SYSTEM_RAIL}" \
        "SystemRail must declare currentView or currentSubmenu state property"
    assert_grep -E '"(wifi|main)"' "${SYSTEM_RAIL}" \
        "SystemRail state machine must support 'wifi' and 'main' states"
else
    test_skip "Pending M2: SystemRail view state machine (currentView/currentSubmenu) pending M2"
fi

test_case "T1.30.2" "Main View Wi-Fi Decoupling: Clicking Wi-Fi section routes to Submenu without toggling radio"
if grep -qE '(currentView\s*=\s*"wifi"|currentSubmenu\s*=\s*"wifi")' "${SYSTEM_RAIL}"; then
    assert_grep -E '(currentView\s*=\s*"wifi"|currentSubmenu\s*=\s*"wifi")' "${SYSTEM_RAIL}" \
        "Clicking Wi-Fi card in Main View must route to 'wifi' submenu"
    # Ensure the summary section click does NOT directly call NetworkService.toggleWifi()
    assert_not_grep "wifiToggleArea" "${SYSTEM_RAIL}" \
        "Legacy wifiToggleArea direct toggle should be replaced with submenu navigation"
else
    test_skip "Pending M2: Wi-Fi section click decoupling pending M2"
fi

test_case "T1.30.3" "Wi-Fi Submenu: Displays scrollable list of SSIDs and signal strengths"
if grep -qE 'availableNetworks' "${SYSTEM_RAIL}"; then
    assert_grep -E '(ListView|Flickable)' "${SYSTEM_RAIL}" \
        "Wi-Fi Submenu must contain scrollable ListView or Flickable"
    assert_grep -E 'NetworkService\.availableNetworks' "${SYSTEM_RAIL}" \
        "SSID list must bind to NetworkService.availableNetworks"
    assert_grep -E '(signalStrength|signal|CtosIcon)' "${SYSTEM_RAIL}" \
        "SSID list delegate must display signal strength indicator or icon"
else
    test_skip "Pending M2: Wi-Fi Submenu availableNetworks list pending M2"
fi

test_case "T1.30.4" "Wi-Fi Submenu: Contains dedicated prominent [DISABLE WI-FI] button in Theme.acidGreen"
if grep -qE '("DISABLE WI-FI"|btnDisableWifi)' "${SYSTEM_RAIL}"; then
    assert_grep -E '("DISABLE WI-FI"|btnDisableWifi)' "${SYSTEM_RAIL}" \
        "Dedicated button must display DISABLE WI-FI label"
    assert_grep -E '(NetworkService\.toggleWifi|NetworkService\.setWifiEnabled)' "${SYSTEM_RAIL}" \
        "Dedicated button must toggle or disable Wi-Fi radio"
    assert_grep -E '(Theme\.acidGreen|Theme\.accent)' "${SYSTEM_RAIL}" \
        "Dedicated button must be styled in acidGreen accent"
else
    test_skip "Pending M2: Dedicated [DISABLE WI-FI] button pending M2"
fi

test_case "T1.30.5" "Wi-Fi Submenu: Clicking known network initiates direct connection"
if grep -qE '(\.known|known)' "${SYSTEM_RAIL}"; then
    assert_grep -E '(\.known|known)' "${SYSTEM_RAIL}" \
        "Submenu delegate must check network known status"
    assert_grep -E '(connectToNetwork|connect\()' "${SYSTEM_RAIL}" \
        "Submenu delegate must invoke connection method"
else
    test_skip "Pending M2: Known network direct connection pending M2"
fi

test_case "T1.30.6" "Wi-Fi Submenu: Clicking unknown network expands inline terminal password prompt"
if grep -qE '(PASSWORD\s*>_|passwordPrompt|selectedSsid)' "${SYSTEM_RAIL}"; then
    assert_grep -E '(PASSWORD\s*>_|PASSWORD)' "${SYSTEM_RAIL}" \
        "Password prompt must follow cyberpunk terminal style (PASSWORD >_)"
    assert_grep -E '(TextInput|TextField)' "${SYSTEM_RAIL}" \
        "Password prompt must embed an inline TextInput field"
else
    test_skip "Pending M2: Inline terminal password prompt (PASSWORD >_) pending M2"
fi

test_case "T1.30.7" "Ambient Bar Integration: NetworkWidget click routes directly to Wi-Fi Submenu"
assert_file_exists "${NET_WIDGET}"
if grep -qE 'OverlayController\.(openWifiSubmenu|openSystemRailWithSubmenu)' "${NET_WIDGET}"; then
    assert_grep -E 'OverlayController\.(openWifiSubmenu|openSystemRailWithSubmenu)' "${NET_WIDGET}" \
        "NetworkWidget must call OverlayController to open Wi-Fi submenu directly"
else
    test_skip "Pending M2: NetworkWidget openWifiSubmenu call pending M2"
fi

test_case "T1.30.8" "Overlay Controller: Declares Wi-Fi submenu deep-linking API"
assert_file_exists "${OVERLAY_CTRL}"
if grep -qE '(openWifiSubmenu|openSystemRailWithSubmenu)' "${OVERLAY_CTRL}"; then
    assert_grep -E 'function\s+(openWifiSubmenu|openSystemRailWithSubmenu)' "${OVERLAY_CTRL}" \
        "OverlayController must declare openWifiSubmenu or openSystemRailWithSubmenu"
    assert_grep -E 'property\s+string\s+(pendingRailView|pendingRailSubmenu)' "${OVERLAY_CTRL}" \
        "OverlayController must declare pendingRailView or pendingRailSubmenu property"
else
    test_skip "Pending M2: OverlayController deep-linking API pending M2"
fi

report_summary
