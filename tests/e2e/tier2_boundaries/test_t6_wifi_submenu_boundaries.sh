#!/usr/bin/env bash
# ==============================================================================
# Tier 2 - Feature 30 Boundaries: Wi-Fi Submenu & Password Prompts
# Source: ORIGINAL_REQUEST §R1, §R2, PROJECT.md, TEST_INFRA.md §Tier 2
# ==============================================================================
set -u
set +e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../harness/mock_environment.sh"
source "${SCRIPT_DIR}/../harness/qml_runner.sh"

SYSTEM_RAIL="${PROJECT_ROOT}/shell/desktop/surfaces/SystemRail.qml"
NET_SVC="${PROJECT_ROOT}/shell/desktop/services/NetworkService.qml"
SHELL_QML="${PROJECT_ROOT}/shell/shell.qml"

test_case "T2.30.1" "Wi-Fi Submenu Boundary: Empty networks list renders calm fallback notice"
assert_file_exists "${SYSTEM_RAIL}"
if grep -qE '(availableNetworks|wifiSubmenu)' "${SYSTEM_RAIL}"; then
    assert_grep -E '("NO ACCESS POINTS FOUND"|"NO NETWORKS FOUND"|"SCANNING"|availableNetworks\.length\s*===?\s*0)' "${SYSTEM_RAIL}" \
        "Wi-Fi Submenu must display calm empty/scanning state fallback notice"
else
    test_skip "Pending M2: Empty networks list fallback pending M2"
fi

test_case "T2.30.2" "Wi-Fi Submenu Boundary: Disabled Wi-Fi adapter state alters button to [ENABLE WI-FI]"
if grep -qE '("ENABLE WI-FI"|btnEnableWifi)' "${SYSTEM_RAIL}"; then
    assert_grep -E '("ENABLE WI-FI"|btnEnableWifi)' "${SYSTEM_RAIL}" \
        "Dedicated toggle button must change to ENABLE WI-FI when radio is off"
else
    test_skip "Pending M2: Disabled Wi-Fi button toggle boundary pending M2"
fi

test_case "T2.30.3" "Wi-Fi Submenu Boundary: Long SSIDs elided with Text.ElideRight within 360px panel"
if grep -qE '(availableNetworks|wifiSubmenu)' "${SYSTEM_RAIL}"; then
    assert_grep -E 'elide:\s*Text\.ElideRight' "${SYSTEM_RAIL}" \
        "SSID delegate text must enforce Text.ElideRight to prevent overflow"
    assert_grep -E '(width:\s*360|implicitWidth:\s*360)' "${SYSTEM_RAIL}" \
        "SystemRail width must remain strictly 360px invariant"
else
    test_skip "Pending M2: Long SSID elision boundary pending M2"
fi

test_case "T2.30.4" "Wi-Fi Submenu Boundary: Empty password submission rejected safely"
if grep -qE '(passwordPrompt|PASSWORD|TextInput)' "${SYSTEM_RAIL}"; then
    # Must guard against empty strings (trim / length check)
    assert_grep -E '(\.text\.trim\(\)|\.text\.length\s*>\s*0|\.text\.length\s*===?\s*0|trim\(\))' "${SYSTEM_RAIL}" \
        "Must check for empty or whitespace-only password before connecting"
    assert_not_grep -E 'execDetached\s*\(\s*\[\s*"sh"' "${SYSTEM_RAIL}" \
        "Must not dispatch shell subshell on password submission"
else
    test_skip "Pending M2: Empty password submission boundary pending M2"
fi

test_case "T2.30.5" "Wi-Fi Submenu Boundary: Escape key hierarchy unwinds submenu state before panel dismissal"
if grep -qE '(currentView|currentSubmenu)' "${SYSTEM_RAIL}"; then
    assert_grep -E 'Keys\.onEscapePressed' "${SYSTEM_RAIL}" \
        "SystemRail must handle Keys.onEscapePressed"
    assert_grep -E '(currentView\s*=\s*"main"|currentSubmenu\s*=\s*""|currentView\s*=\s*""|passwordPrompt|selectedSsid\s*=\s*"")' "${SYSTEM_RAIL}" \
        "Escape in submenu must unwind submenu/prompt state before closing panel"
else
    test_skip "Pending M2: Escape key hierarchy pending M2"
fi

test_case "T2.30.6" "Wi-Fi Submenu Boundary: Panel dismissal resets submenu state and clears password buffer"
if grep -qE '(currentView|currentSubmenu)' "${SYSTEM_RAIL}"; then
    assert_grep -E 'onOverlayClosed' "${SYSTEM_RAIL}" \
        "SystemRail must hook onOverlayClosed"
    assert_grep -E '(currentSubmenu\s*=\s*""|currentView\s*=\s*"main"|currentView\s*=\s*""|password\s*=\s*""|text\s*=\s*"")' "${SYSTEM_RAIL}" \
        "onOverlayClosed must reset view state and clear secrets"
else
    test_skip "Pending M2: Overlay dismissal hygiene pending M2"
fi

report_summary
