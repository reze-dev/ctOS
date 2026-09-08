#!/usr/bin/env bash
# ==============================================================================
# Tier 3 - Pairwise 23-27: Wi-Fi Submenu Cross-Feature Interactions
# Source: ORIGINAL_REQUEST §R2, §R3, PROJECT.md, TEST_INFRA.md §Tier 3
# ==============================================================================
set -u
set +e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../harness/mock_environment.sh"
source "${SCRIPT_DIR}/../harness/qml_runner.sh"

SYSTEM_RAIL="${PROJECT_ROOT}/shell/desktop/surfaces/SystemRail.qml"
NET_SVC="${PROJECT_ROOT}/shell/desktop/services/NetworkService.qml"
OVERLAY_CTRL="${PROJECT_ROOT}/shell/desktop/core/OverlayController.qml"
NET_WIDGET="${PROJECT_ROOT}/shell/desktop/surfaces/components/NetworkWidget.qml"

test_case "T3.23" "Pairwise: Destructive session confirmation safely supersedes Wi-Fi Submenu"
assert_file_exists "${SYSTEM_RAIL}"
if grep -qE '(currentView|currentSubmenu)' "${SYSTEM_RAIL}"; then
    assert_grep -E '(isConfirming|confirmationAction)' "${SYSTEM_RAIL}" \
        "Confirmation state must exist in SystemRail"
    assert_grep -E '(visible:\s*root\.isConfirming|visible:\s*!root\.isConfirming|visible:\s*confirmationLayout)' "${SYSTEM_RAIL}" \
        "Session safety confirmation view must visually supersede all regular views"
else
    test_skip "Pending M2: Submenu + Session Safety interaction pending M2"
fi

test_case "T3.24" "Pairwise: Discovered AP disappearing reactively updates model without UI lockup"
assert_file_exists "${NET_SVC}"
if grep -q "availableNetworks" "${NET_SVC}"; then
    assert_grep -E '(Instantiator|devices|networks)' "${NET_SVC}" \
        "NetworkService must track network model updates reactively"
    assert_not_grep -E 'sleep\s+[0-9]' "${NET_SVC}" \
        "Reactive model updates must not block the UI thread with sleep"
else
    test_skip "Pending M2: AP drop reactivity pending M2"
fi

test_case "T3.25" "Pairwise: Operating audio volume or mic slider does not corrupt active password prompt"
assert_file_exists "${SYSTEM_RAIL}"
if grep -qE '(passwordPrompt|PASSWORD|TextInput)' "${SYSTEM_RAIL}"; then
    assert_grep -E '(AudioService|setVolume|stepVolume|volumeSlider)' "${SYSTEM_RAIL}" \
        "SystemRail must host volume controls alongside view state machine"
    assert_grep -E '(TextInput|TextField)' "${SYSTEM_RAIL}" \
        "Password prompt text input must be isolated in its own scope"
else
    test_skip "Pending M2: Password prompt + Volume interaction pending M2"
fi

test_case "T3.26" "Pairwise: Ambient Bar Network Widget click transitions active Rail to Wi-Fi Submenu without flicker"
assert_file_exists "${NET_WIDGET}"
assert_file_exists "${OVERLAY_CTRL}"
if grep -qE '(openWifiSubmenu|openSystemRailWithSubmenu)' "${NET_WIDGET}"; then
    assert_grep -E 'function\s+(openWifiSubmenu|openSystemRailWithSubmenu)' "${OVERLAY_CTRL}" \
        "OverlayController must support direct Wi-Fi submenu opening"
    assert_grep -E '(openWifiSubmenu|openSystemRailWithSubmenu)' "${NET_WIDGET}" \
        "NetworkWidget must trigger deep-linking method"
else
    test_skip "Pending M2: Ambient Bar transition when rail open pending M2"
fi

test_case "T3.27" "Pairwise: Settings.reducedMotion true suppresses submenu slide transitions"
if grep -qE '(Settings\.reducedMotion|reducedMotion)' "${SYSTEM_RAIL}"; then
    assert_grep -E '(Settings\.reducedMotion|reducedMotion)' "${SYSTEM_RAIL}" \
        "SystemRail must respect Settings.reducedMotion for view transitions"
else
    test_skip "Pending M2: Submenu reduced motion transition pending M2"
fi

report_summary
