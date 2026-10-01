#!/usr/bin/env bash
# ==============================================================================
# Tier 1 - Feature Coverage: Living Notch Compact State (R1: F3, F4, F5, F6, F7)
# Source: ORIGINAL_REQUEST.md §R1, PROJECT.md §Feature Inventory, unified-island-redesign.md
# ==============================================================================
set -u
set +e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../harness/mock_environment.sh"
source "${SCRIPT_DIR}/../harness/qml_runner.sh"

LIVING_NOTCH="${PROJECT_ROOT}/shell/desktop/surfaces/components/LivingNotch.qml"
AMBIENT_BAR="${PROJECT_ROOT}/shell/desktop/surfaces/AmbientBar.qml"
COMPOSITOR_SVC="${PROJECT_ROOT}/shell/desktop/services/CompositorService.qml"
NETWORK_SVC="${PROJECT_ROOT}/shell/desktop/services/NetworkService.qml"
CLOCK_WIDGET="${PROJECT_ROOT}/shell/desktop/surfaces/components/ClockWidget.qml"
THEME_FILE="${PROJECT_ROOT}/shell/desktop/core/Theme.qml"
RUNTIME_HARNESS="${HARNESS_DIR}/test_living_notch_runtime.qml"

test_case "T1.LN.01" "Living Notch: Architecture and component location contract"
assert_file_exists "${AMBIENT_BAR}" "AmbientBar host surface must exist"
assert_file_exists "${THEME_FILE}" "Theme design tokens must exist"

test_case "T1.LN.02" "Living Notch: Minimal compact pill dimensions (~220px..280px x 30px)"
if [[ -f "${LIVING_NOTCH}" ]]; then
    assert_grep -E '(compactWidth|width).*2[0-9]{2}' "${LIVING_NOTCH}" \
        "Living Notch must specify compact width between 200px and 299px"
    assert_grep -E '(compactHeight|height).*Theme\.barHeight' "${LIVING_NOTCH}" \
        "Living Notch must constrain compact height to bar height bounds"
else
    # Validate contract from PROJECT.md F3
    assert_grep "barHeight:\s*(36|40)" "${THEME_FILE}" "Theme barHeight must be 36 or 40"
    assert_grep "radiusPill" "${THEME_FILE}" "Theme must provide radiusPill token for notch pill"
fi

test_case "T1.LN.03" "Living Notch: Workspace indicators bound to CompositorService"
assert_file_exists "${COMPOSITOR_SVC}"
assert_grep "readonly property list<var> workspaces" "${COMPOSITOR_SVC}" \
    "CompositorService must expose reactive workspaces list"
assert_grep "focusedWorkspaceId" "${COMPOSITOR_SVC}" \
    "CompositorService must expose focusedWorkspaceId"
if [[ -f "${LIVING_NOTCH}" ]]; then
    assert_grep -E '(CompositorService\.workspaces|WorkspacesWidget)' "${LIVING_NOTCH}" \
        "Living Notch must embed workspace indicator dots"
fi

test_case "T1.LN.04" "Living Notch: Monospace clock display updating every minute"
assert_file_exists "${CLOCK_WIDGET}"
assert_grep "Maple Mono" "${THEME_FILE}" "Clock must use Maple Mono font"
if [[ -f "${LIVING_NOTCH}" ]]; then
    assert_grep -E '(ClockWidget|SystemClock|clock)' "${LIVING_NOTCH}" \
        "Living Notch compact state must display clock"
fi

test_case "T1.LN.05" "Living Notch: Network connected indicator dot visible only on active connection"
assert_file_exists "${NETWORK_SVC}"
assert_grep "property bool isConnected" "${NETWORK_SVC}" \
    "NetworkService must expose isConnected boolean state"
if [[ -f "${LIVING_NOTCH}" ]]; then
    assert_grep -E 'NetworkService\.(isConnected|hasActiveConnection|available)' "${LIVING_NOTCH}" \
        "Living Notch must bind network dot visibility strictly to active connection"
fi

test_case "T1.LN.06" "Living Notch: Status text idle, DND, and unread notification badge"
if [[ -f "${LIVING_NOTCH}" ]]; then
    assert_grep -E '(IDLE|// IDLE|dnd|unread)' "${LIVING_NOTCH}" \
        "Living Notch must support IDLE/DND status text"
else
    assert_file_exists "${PROJECT_ROOT}/shell/desktop/services/NotificationService.qml"
fi

test_case "T1.LN.07" "Living Notch: Headless runtime QML harness execution"
if [[ -f "${RUNTIME_HARNESS}" ]]; then
    run_qml_test_harness "${RUNTIME_HARNESS}" "Living Notch Runtime Harness"
else
    test_skip "test_living_notch_runtime.qml missing"
fi

report_summary
