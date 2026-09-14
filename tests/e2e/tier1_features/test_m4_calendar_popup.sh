#!/usr/bin/env bash
# ==============================================================================
# Tier 1 - Milestone 4: Calendar Popup & Shell Wiring (R7)
# ==============================================================================
set -u
set +e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../harness/mock_environment.sh"
source "${SCRIPT_DIR}/../harness/qml_runner.sh"

CALENDAR_POPUP="${PROJECT_ROOT}/shell/desktop/surfaces/components/CalendarPopup.qml"
COMPONENTS_QMLDIR="${PROJECT_ROOT}/shell/desktop/surfaces/components/qmldir"
CLOCK_WIDGET="${PROJECT_ROOT}/shell/desktop/surfaces/components/ClockWidget.qml"
AMBIENT_BAR="${PROJECT_ROOT}/shell/desktop/surfaces/AmbientBar.qml"
SHELL_QML="${PROJECT_ROOT}/shell/shell.qml"

RUNTIME_HARNESS="${HARNESS_DIR}/test_m4_calendar_popup.qml"
WIRING_HARNESS="${HARNESS_DIR}/test_m4_shell_wiring.qml"

# ------------------------------------------------------------------------------
# 1. Component File Existence & Registration
# ------------------------------------------------------------------------------
test_case "T1.M4.1" "CalendarPopup: file exists in components/"
assert_file_exists "${CALENDAR_POPUP}"

test_case "T1.M4.2" "CalendarPopup: registered in components/qmldir"
assert_grep "CalendarPopup\s+1\.0\s+CalendarPopup\.qml" "${COMPONENTS_QMLDIR}" "CalendarPopup must be registered in qmldir"

# ------------------------------------------------------------------------------
# 2. CalendarPopup Theming, Dimensions & Styling Tokens
# ------------------------------------------------------------------------------
test_case "T1.M4.3" "CalendarPopup: width is 300px"
assert_grep "implicitWidth:\s*300" "${CALENDAR_POPUP}" "CalendarPopup implicitWidth must be 300"
assert_grep "width:\s*300" "${CALENDAR_POPUP}" "CalendarPopup width must be 300"

test_case "T1.M4.4" "CalendarPopup: Theme tokens used for surface & borders"
assert_grep "color:\s*Theme\.gray900" "${CALENDAR_POPUP}" "CalendarPopup background must be Theme.gray900"
assert_grep "border\.color:\s*Theme\.borderMuted" "${CALENDAR_POPUP}" "CalendarPopup border must be Theme.borderMuted"
assert_grep "radius:\s*Theme\.radiusSmall" "${CALENDAR_POPUP}" "CalendarPopup radius must be Theme.radiusSmall"

test_case "T1.M4.5" "CalendarPopup: cyberpunk corner brackets with acidGreen"
assert_grep "cornerBrackets" "${CALENDAR_POPUP}" "CalendarPopup must include corner brackets"
assert_grep "bracketColor:\s*Theme\.acidGreen" "${CALENDAR_POPUP}" "Corner brackets must use Theme.acidGreen"

test_case "T1.M4.6" "CalendarPopup: typography uses Theme.fontFamilyMonospace"
assert_grep "font\.family:\s*Theme\.fontFamilyMonospace" "${CALENDAR_POPUP}" "CalendarPopup text must use Theme.fontFamilyMonospace"

test_case "T1.M4.7" "CalendarPopup: inside click consumer MouseArea"
assert_grep "preventStealing:\s*true" "${CALENDAR_POPUP}" "Inside click consumer must preventStealing"
assert_grep "mouse\.accepted\s*=\s*true" "${CALENDAR_POPUP}" "Inside click consumer must accept mouse events"

test_case "T1.M4.8" "CalendarPopup: public closeRequested signal"
check_qml_signal "${CALENDAR_POPUP}" "closeRequested"

# ------------------------------------------------------------------------------
# 3. ClockWidget & AmbientBar Rerouting
# ------------------------------------------------------------------------------
test_case "T1.M4.9" "ClockWidget: declares toggleCalendar signal"
check_qml_signal "${CLOCK_WIDGET}" "toggleCalendar"

test_case "T1.M4.10" "ClockWidget: onClicked emits root.toggleCalendar()"
assert_grep "root\.toggleCalendar\(\)" "${CLOCK_WIDGET}" "ClockWidget click must emit root.toggleCalendar()"
assert_not_grep "OverlayController\.toggleEventLog\(\)" "${CLOCK_WIDGET}" "ClockWidget must no longer call toggleEventLog()"

test_case "T1.M4.11" "AmbientBar: declares toggleCalendar signal"
check_qml_signal "${AMBIENT_BAR}" "toggleCalendar"

test_case "T1.M4.12" "AmbientBar: forwards clockWidget onToggleCalendar"
assert_grep "onToggleCalendar:\s*root\.toggleCalendar\(\)" "${AMBIENT_BAR}" "AmbientBar must forward clockWidget.onToggleCalendar"

# ------------------------------------------------------------------------------
# 4. Shell.qml State, IPC, and PanelWindows
# ------------------------------------------------------------------------------
test_case "T1.M4.13" "shell.qml: imports desktop/surfaces/components"
assert_grep 'import\s+"desktop/surfaces/components"' "${SHELL_QML}" "shell.qml must import components"

test_case "T1.M4.14" "shell.qml: declares calendarVisible property"
check_qml_property "${SHELL_QML}" "calendarVisible" --type bool

test_case "T1.M4.15" "shell.qml: declares toggleCalendar method"
check_qml_method "${SHELL_QML}" "toggleCalendar"

test_case "T1.M4.16" "shell.qml: declares closeCalendar method"
check_qml_method "${SHELL_QML}" "closeCalendar"

test_case "T1.M4.17" "shell.qml: IpcHandler has toggleCalendar"
assert_grep "function\s+toggleCalendar\(\):\s*void" "${SHELL_QML}" "IpcHandler must expose toggleCalendar"

test_case "T1.M4.18" "shell.qml: barVariants delegates forward onToggleCalendar"
assert_grep "onToggleCalendar:\s*root\.toggleCalendar\(modelData\)" "${SHELL_QML}" "barVariants must pass modelData to toggleCalendar"

test_case "T1.M4.19" "shell.qml: closes calendar on overlay opened"
assert_grep "root\.closeCalendar\(\)" "${SHELL_QML}" "shell.qml must close calendar on overlay open or disconnect"

test_case "T1.M4.20" "shell.qml: calendarBackdropHost defines non-focus dismiss backdrop"
assert_grep "calendarBackdropHost" "${SHELL_QML}" "calendarBackdropHost must exist in shell.qml"
assert_grep "WlrLayershell\.layer:\s*WlrLayer\.Top" "${SHELL_QML}" "calendarBackdropHost must be on WlrLayer.Top"
assert_grep "WlrLayershell\.keyboardFocus:\s*WlrKeyboardFocus\.None" "${SHELL_QML}" "calendarBackdropHost must have KeyboardFocus.None"

test_case "T1.M4.21" "shell.qml: calendarPopupHost defines overlay PanelWindow hosting CalendarPopup"
assert_grep "calendarPopupHost" "${SHELL_QML}" "calendarPopupHost must exist in shell.qml"
assert_grep "CalendarPopup\s*\{" "${SHELL_QML}" "calendarPopupHost must instantiate CalendarPopup"
assert_grep "onCloseRequested:\s*root\.closeCalendar\(\)" "${SHELL_QML}" "CalendarPopup closeRequested must close calendar"

# ------------------------------------------------------------------------------
# 5. Format & Isolation Compliance
# ------------------------------------------------------------------------------
test_case "T1.M4.22" "Code formatting compliance"
check_qml_format "${CALENDAR_POPUP}"
check_qml_format "${CLOCK_WIDGET}"
check_qml_format "${AMBIENT_BAR}"
check_qml_format "${SHELL_QML}"

test_case "T1.M4.23" "Greeter isolation & zero-polling compliance"
check_no_greeter_imports "${PROJECT_ROOT}/shell/desktop"
check_no_greeter_imports "${SHELL_QML}"
check_no_polling_loops "${PROJECT_ROOT}/shell/desktop"
check_no_polling_loops "${SHELL_QML}"

# ------------------------------------------------------------------------------
# 6. Empirical Runtime Test Execution
# ------------------------------------------------------------------------------
test_case "T1.M4.24" "Quickshell runtime verification of CalendarPopup"
if [[ -f "${RUNTIME_HARNESS}" ]]; then
    run_qml_test_harness "${RUNTIME_HARNESS}" "Milestone 4 Calendar Runtime Harness"
else
    test_skip "Runtime harness file missing"
fi

test_case "T1.M4.25" "Quickshell runtime verification of Shell Wiring & Multi-Monitor"
if [[ -f "${WIRING_HARNESS}" ]]; then
    run_qml_test_harness "${WIRING_HARNESS}" "Milestone 4 Shell Wiring Harness"
else
    test_skip "Wiring harness file missing"
fi

report_summary
