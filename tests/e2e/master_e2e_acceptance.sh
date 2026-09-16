#!/usr/bin/env bash
# ==============================================================================
# master_e2e_acceptance.sh - Master Consolidated E2E Acceptance Test Suite
# Validates all 8 Quality-of-Life Requirements (R1–R8) and System Contracts
#
# Requirements Covered:
#   R1: Font Swap to Maple Mono (Theme.qml)
#   R2: Bar Height 36px (Theme.qml)
#   R3: 3-Island Bar Layout with rounded corners (AmbientBar.qml)
#   R4: OS Icon Branding Button (components/os-icon.svg in AmbientBar.qml)
#   R5: WiFi Disconnect & Forget with Inline Confirmation (SystemRail.qml)
#   R6: Dynamic Island Center Element (DynamicIsland.qml & AmbientBar.qml)
#   R7: Monospace Calendar Popup & Dual-Window Shell Wiring (CalendarPopup.qml, shell.qml)
#   R8: Legacy Prototype Directory & File Cleanup (shell/bar.qml & shell/bar/)
# ==============================================================================
set -u
set +e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
source "${SCRIPT_DIR}/harness/mock_environment.sh"
source "${SCRIPT_DIR}/harness/qml_runner.sh"

echo "======================================================================"
echo "ctOS Master End-to-End Acceptance Suite (R1–R8 Full Verification)"
echo "======================================================================"

THEME_FILE="${PROJECT_ROOT}/shell/desktop/core/Theme.qml"
AMBIENT_BAR="${PROJECT_ROOT}/shell/desktop/surfaces/AmbientBar.qml"
OS_ICON="${PROJECT_ROOT}/shell/desktop/surfaces/components/os-icon.svg"
SYSTEM_RAIL="${PROJECT_ROOT}/shell/desktop/surfaces/SystemRail.qml"
DYNAMIC_ISLAND="${PROJECT_ROOT}/shell/desktop/surfaces/components/DynamicIsland.qml"
CALENDAR_POPUP="${PROJECT_ROOT}/shell/desktop/surfaces/components/CalendarPopup.qml"
CLOCK_WIDGET="${PROJECT_ROOT}/shell/desktop/surfaces/components/ClockWidget.qml"
SHELL_FILE="${PROJECT_ROOT}/shell/shell.qml"
NOTIFICATION_SVC="${PROJECT_ROOT}/shell/desktop/services/NotificationService.qml"
NETWORK_SVC="${PROJECT_ROOT}/shell/desktop/services/NetworkService.qml"
LEGACY_BAR="${PROJECT_ROOT}/shell/bar.qml"
LEGACY_DIR="${PROJECT_ROOT}/shell/bar"

# ------------------------------------------------------------------------------
# R1: Font Swap to Maple Mono
# ------------------------------------------------------------------------------
test_case "R1.1" "Theme: fontFamily is Maple Mono"
assert_file_exists "${THEME_FILE}"
assert_grep 'readonly property string fontFamily: "Maple Mono"' "${THEME_FILE}" \
    "Theme.fontFamily must be 'Maple Mono'"

test_case "R1.2" "Theme: fontFamilyMonospace is Maple Mono"
assert_grep 'readonly property string fontFamilyMonospace: "Maple Mono"' "${THEME_FILE}" \
    "Theme.fontFamilyMonospace must be 'Maple Mono'"

test_case "R1.3" "Theme: fontFamilies fallback array prioritizes Maple Mono"
assert_grep 'readonly property var fontFamilies: \["Maple Mono"' "${THEME_FILE}" \
    "Theme.fontFamilies array must prioritize Maple Mono"

# ------------------------------------------------------------------------------
# R2: Bar Height Increase to 36px
# ------------------------------------------------------------------------------
test_case "R2.1" "Theme: barHeight token is 36"
assert_grep 'readonly property int barHeight: 36' "${THEME_FILE}" \
    "Theme.barHeight must be 36"

# ------------------------------------------------------------------------------
# R3: 3-Island Bar Layout
# ------------------------------------------------------------------------------
test_case "R3.1" "AmbientBar: PanelWindow has transparent background"
assert_file_exists "${AMBIENT_BAR}"
assert_grep 'color: "transparent"' "${AMBIENT_BAR}" \
    "AmbientBar PanelWindow must be transparent"

test_case "R3.2" "AmbientBar: PanelWindow anchors define top margin of 3"
assert_grep 'top: 3' "${AMBIENT_BAR}" \
    "AmbientBar PanelWindow must have top margin 3"

test_case "R3.3" "AmbientBar: Left island pill container with Theme.radiusPill and barHeight - 6"
assert_grep 'id: leftIsland' "${AMBIENT_BAR}"
assert_grep 'radius: Theme\.radiusPill' "${AMBIENT_BAR}"
assert_grep 'height: Theme\.barHeight - 6' "${AMBIENT_BAR}"

test_case "R3.4" "AmbientBar: Right island pill container with Theme.radiusPill and barHeight - 6"
assert_grep 'id: rightIsland' "${AMBIENT_BAR}"

# ------------------------------------------------------------------------------
# R4: OS Icon Branding Button
# ------------------------------------------------------------------------------
test_case "R4.1" "Branding: components/os-icon.svg exists"
assert_file_exists "${OS_ICON}" "components/os-icon.svg must exist"

test_case "R4.2" "AmbientBar: Replaces text ctOS with os-icon.svg Image"
assert_grep 'source: "components/os-icon\.svg"' "${AMBIENT_BAR}" \
    "AmbientBar branding button must use os-icon.svg"

test_case "R4.3" "AmbientBar: OS icon button routes click to OverlayController.openCommandDeck()"
assert_grep 'OverlayController\.openCommandDeck\(\)' "${AMBIENT_BAR}" \
    "OS icon button click must open Command Deck"

# ------------------------------------------------------------------------------
# R5: WiFi Disconnect & Forget Management
# ------------------------------------------------------------------------------
test_case "R5.1" "SystemRail: Declares confirmingForgetSsid state property"
assert_file_exists "${SYSTEM_RAIL}"
assert_grep 'property string confirmingForgetSsid: ""' "${SYSTEM_RAIL}" \
    "SystemRail must declare confirmingForgetSsid initialized to empty string"

test_case "R5.2" "SystemRail: Connected network shows [DISCONNECT] invoking disconnectCurrentNetwork()"
assert_grep 'NetworkService\.disconnectCurrentNetwork\(\)' "${SYSTEM_RAIL}" \
    "SystemRail must invoke NetworkService.disconnectCurrentNetwork()"

test_case "R5.3" "SystemRail: Saved network shows [CONNECT] and [FORGET]"
assert_grep 'NetworkService\.connectToNetwork\(itemSsid\)' "${SYSTEM_RAIL}" \
    "SystemRail must support connecting to saved network"
assert_grep 'root\.confirmingForgetSsid = itemSsid' "${SYSTEM_RAIL}" \
    "Clicking FORGET must initiate confirmation state"

test_case "R5.4" "SystemRail: Inline confirmation prompt FORGET <SSID>? [YES] [NO]"
assert_grep '"FORGET " \+ itemSsid \+ "\?"' "${SYSTEM_RAIL}" \
    "SystemRail must render inline confirmation prompt"
assert_grep 'NetworkService\.forgetNetwork\(itemSsid\)' "${SYSTEM_RAIL}" \
    "Confirming forget must invoke NetworkService.forgetNetwork()"

test_case "R5.5" "SystemRail: Tiered ESC priority clears confirmingForgetSsid first"
assert_grep 'root\.confirmingForgetSsid !== ""' "${SYSTEM_RAIL}" \
    "Tiered ESC must prioritize clearing confirmingForgetSsid"

# ------------------------------------------------------------------------------
# R6: Dynamic Island Center Element
# ------------------------------------------------------------------------------
test_case "R6.1" "DynamicIsland: Component file exists in components/"
assert_file_exists "${DYNAMIC_ISLAND}"

test_case "R6.2" "DynamicIsland: Declares compact (120px) and expanded (300px) width states"
assert_grep 'compactWidth: 120' "${DYNAMIC_ISLAND}" \
    "DynamicIsland must declare compactWidth: 120"
assert_grep 'expandedWidth: 300' "${DYNAMIC_ISLAND}" \
    "DynamicIsland must declare expandedWidth: 300"
assert_grep 'width: isExpanded \? expandedWidth : compactWidth' "${DYNAMIC_ISLAND}" \
    "DynamicIsland root width must switch between expandedWidth and compactWidth"

test_case "R6.3" "DynamicIsland: Smooth width animation using Theme.durationSlow and Easing.InOutQuad"
assert_grep 'Theme\.durationSlow' "${DYNAMIC_ISLAND}"
assert_grep 'easing\.type: Easing\.InOutQuad' "${DYNAMIC_ISLAND}"

test_case "R6.4" "DynamicIsland: Auto-collapses after 4000ms timer interval"
assert_grep 'interval: 4000' "${DYNAMIC_ISLAND}"
assert_grep 'root\.isExpanded = false' "${DYNAMIC_ISLAND}"

test_case "R6.5" "DynamicIsland: Click routes to Event Log overlay"
assert_grep 'OverlayController\.(toggleEventLog|openEventLog)' "${DYNAMIC_ISLAND}" \
    "DynamicIsland click must open or toggle Event Log"

test_case "R6.6" "AmbientBar: Hosts DynamicIsland in center section"
assert_grep 'DynamicIsland' "${AMBIENT_BAR}" \
    "AmbientBar must host DynamicIsland in center"

# ------------------------------------------------------------------------------
# R7: Calendar Popup & Shell Wiring
# ------------------------------------------------------------------------------
test_case "R7.1" "CalendarPopup: Component file exists in components/"
assert_file_exists "${CALENDAR_POPUP}"

test_case "R7.2" "CalendarPopup: Registered in components/qmldir"
assert_grep 'CalendarPopup 1\.0 CalendarPopup\.qml' "${PROJECT_ROOT}/shell/desktop/surfaces/components/qmldir"

test_case "R7.3" "CalendarPopup: Width conforms to 300px compact specification"
assert_grep 'width: 300' "${CALENDAR_POPUP}"

test_case "R7.4" "CalendarPopup: Declares public closeRequested signal"
check_qml_signal "${CALENDAR_POPUP}" "closeRequested"

test_case "R7.5" "ClockWidget: Declares toggleCalendar signal and onClicked emits it"
assert_file_exists "${CLOCK_WIDGET}"
check_qml_signal "${CLOCK_WIDGET}" "toggleCalendar"
assert_grep 'root\.toggleCalendar\(\)' "${CLOCK_WIDGET}"

test_case "R7.6" "AmbientBar: Forwards ClockWidget onToggleCalendar"
check_qml_signal "${AMBIENT_BAR}" "toggleCalendar"
assert_grep 'onToggleCalendar: root\.toggleCalendar\(\)' "${AMBIENT_BAR}"

test_case "R7.7" "shell.qml: Hosts calendarBackdropHost and calendarPopupHost PanelWindows"
assert_file_exists "${SHELL_FILE}"
assert_grep 'id: calendarBackdropHost' "${SHELL_FILE}"
assert_grep 'id: calendarPopupHost' "${SHELL_FILE}"

test_case "R7.8" "shell.qml: Calendar window uses WlrKeyboardFocus.None (non-stealing)"
assert_grep 'WlrLayershell\.keyboardFocus: WlrKeyboardFocus\.None' "${SHELL_FILE}"

test_case "R7.9" "shell.qml: IpcHandler defines toggleCalendar IPC method"
assert_grep 'function toggleCalendar\(\): void' "${SHELL_FILE}"

# ------------------------------------------------------------------------------
# R8: Legacy Prototype Cleanup
# ------------------------------------------------------------------------------
test_case "R8.1" "Legacy: shell/bar.qml is purged"
assert_file_not_exists "${LEGACY_BAR}" "shell/bar.qml must not exist"

test_case "R8.2" "Legacy: shell/bar/ directory is purged"
assert_file_not_exists "${LEGACY_DIR}" "shell/bar/ directory must not exist"

# ------------------------------------------------------------------------------
# Static Inspections: Formatting, Greeter Isolation & Zero Polling
# ------------------------------------------------------------------------------
test_case "STATIC.1" "Static: Formatting compliance across all touched files"
for target in "${THEME_FILE}" "${AMBIENT_BAR}" "${SYSTEM_RAIL}" "${DYNAMIC_ISLAND}" \
              "${CALENDAR_POPUP}" "${CLOCK_WIDGET}" "${NOTIFICATION_SVC}" "${SHELL_FILE}"; do
    check_qml_format "${target}"
done

test_case "STATIC.2" "Static: Greeter isolation strictly preserved in shell/desktop/ and shell.qml"
check_no_greeter_imports "${PROJECT_ROOT}/shell/desktop"
check_no_greeter_imports "${SHELL_FILE}"

test_case "STATIC.3" "Static: Zero polling policy strictly maintained"
check_no_polling_loops "${PROJECT_ROOT}/shell/desktop"
check_no_polling_loops "${SHELL_FILE}"

# ------------------------------------------------------------------------------
# Empirical Runtime QML Harnesses
# ------------------------------------------------------------------------------
test_case "RUNTIME.M1" "Empirical Runtime: M1 Token & Bar Height Harness"
run_qml_test_harness "${PROJECT_ROOT}/tests/e2e/harness/test_m1_challenger_verification.qml" "M1 Challenger Verification" 5

test_case "RUNTIME.M2" "Empirical Runtime: M2 Dynamic Island & Ambient Bar Harness"
run_qml_test_harness "${PROJECT_ROOT}/tests/e2e/harness/test_m2_ambient_bar_dynamic_island.qml" "M2 Dynamic Island" 8

test_case "RUNTIME.M3" "Empirical Runtime: M3 WiFi Submenu & Action State Machine Harness"
run_qml_test_harness "${PROJECT_ROOT}/tests/e2e/harness/test_t6_wifi_quickshell.qml" "M3 WiFi Quickshell" 5

test_case "RUNTIME.M4.1" "Empirical Runtime: M4 Calendar Popup Grid & Date Math Harness"
run_qml_test_harness "${PROJECT_ROOT}/tests/e2e/harness/test_m4_calendar_popup.qml" "M4 Calendar Popup" 8

test_case "RUNTIME.M4.2" "Empirical Runtime: M4 Shell Wiring & Multi-Monitor Switching Harness"
run_qml_test_harness "${PROJECT_ROOT}/tests/e2e/harness/test_m4_shell_wiring.qml" "M4 Shell Wiring" 8

test_case "RUNTIME.M4.3" "Empirical Runtime: M4 Challenger Concurrency & Preemption Stress Harness"
run_qml_test_harness "${PROJECT_ROOT}/tests/e2e/harness/test_m4_challenger_stress.qml" "M4 Challenger Stress" 8

echo ""
report_summary
