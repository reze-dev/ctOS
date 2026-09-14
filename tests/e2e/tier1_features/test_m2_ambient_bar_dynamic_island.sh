#!/usr/bin/env bash
# ==============================================================================
# Tier 1 - Milestone 2: AmbientBar Islands, Branding & Dynamic Island (R3, R4, R6)
# ==============================================================================
set -u
set +e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../harness/mock_environment.sh"
source "${SCRIPT_DIR}/../harness/qml_runner.sh"

AMBIENT_BAR="${PROJECT_ROOT}/shell/desktop/surfaces/AmbientBar.qml"
DYNAMIC_ISLAND="${PROJECT_ROOT}/shell/desktop/surfaces/components/DynamicIsland.qml"
COMPONENTS_QMLDIR="${PROJECT_ROOT}/shell/desktop/surfaces/components/qmldir"
OS_ICON="${PROJECT_ROOT}/shell/desktop/surfaces/components/os-icon.svg"
NOTIF_SERVICE="${PROJECT_ROOT}/shell/desktop/services/NotificationService.qml"
RUNTIME_HARNESS="${HARNESS_DIR}/test_m2_ambient_bar_dynamic_island.qml"

test_case "T1.M2.1" "AmbientBar: color is transparent"
assert_file_exists "${AMBIENT_BAR}"
assert_grep 'color:\s*"transparent"' "${AMBIENT_BAR}" "AmbientBar PanelWindow must have transparent color"

test_case "T1.M2.2" "AmbientBar: margins top is 3"
assert_grep "top:\s*3" "${AMBIENT_BAR}" "AmbientBar must have top margin of 3"

test_case "T1.M2.3" "AmbientBar: bottom border divider removed"
assert_not_grep "bottomBorder" "${AMBIENT_BAR}" "bottomBorder divider must be removed"

test_case "T1.M2.4" "AmbientBar: left island pill geometry"
assert_grep "radius:\s*Theme\.radiusPill" "${AMBIENT_BAR}" "Islands must use Theme.radiusPill"
assert_grep "height:\s*Theme\.barHeight\s*-\s*6" "${AMBIENT_BAR}" "Islands must have height Theme.barHeight - 6"

test_case "T1.M2.5" "AmbientBar: branding icon uses components/os-icon.svg without greeter references"
assert_grep 'source:\s*"components/os-icon\.svg"' "${AMBIENT_BAR}" "Branding icon must use components/os-icon.svg"
assert_not_grep "greeter/resources" "${AMBIENT_BAR}" "AmbientBar must not reference greeter/resources"

test_case "T1.M2.6" "AmbientBar: center island hosts DynamicIsland centered horizontally"
assert_grep "DynamicIsland\s*\{" "${AMBIENT_BAR}" "AmbientBar must host DynamicIsland"
assert_grep "anchors\.horizontalCenter:\s*parent\.horizontalCenter" "${AMBIENT_BAR}" "DynamicIsland must center horizontally"

test_case "T1.M2.7" "AmbientBar: right island hosts rail button with '='"
assert_grep 'text:\s*"="' "${AMBIENT_BAR}" "Rail button must have text '='"
assert_grep "OverlayController\.toggleSystemRail\(\)" "${AMBIENT_BAR}" "Rail button must toggle system rail"

test_case "T1.M2.8" "DynamicIsland: component exists in components/"
assert_file_exists "${DYNAMIC_ISLAND}"

test_case "T1.M2.9" "DynamicIsland: registered in components/qmldir"
assert_grep "DynamicIsland\s+1\.0\s+DynamicIsland\.qml" "${COMPONENTS_QMLDIR}" "DynamicIsland must be registered in qmldir"

test_case "T1.M2.10" "OS Icon: copied to components/os-icon.svg"
assert_file_exists "${OS_ICON}"

test_case "T1.M2.11" "NotificationService: declares notificationReceived signal"
check_qml_signal "${NOTIF_SERVICE}" "notificationReceived"

test_case "T1.M2.12" "NotificationService: emits notificationReceived in _handleNotification"
assert_grep "root\.notificationReceived\(" "${NOTIF_SERVICE}" "NotificationService must emit notificationReceived"

test_case "T1.M2.13" "Code formatting compliance"
check_qml_format "${AMBIENT_BAR}"
check_qml_format "${DYNAMIC_ISLAND}"
check_qml_format "${NOTIF_SERVICE}"

test_case "T1.M2.14" "Quickshell runtime verification of DynamicIsland"
if [[ -f "${RUNTIME_HARNESS}" ]]; then
    run_qml_test_harness "${RUNTIME_HARNESS}" "M2 AmbientBar Dynamic Island Runtime Harness"
else
    test_skip "Runtime harness file missing"
fi

report_summary
