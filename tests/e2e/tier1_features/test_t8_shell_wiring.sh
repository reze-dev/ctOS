#!/usr/bin/env bash
# ==============================================================================
# Tier 1 - Feature: T8 Shell Wiring & IPC Integration
# Source: ORIGINAL_REQUEST §R4, PROJECT.md M4, DISPATCH.md
# ==============================================================================
set -u
set +e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../harness/mock_environment.sh"
source "${SCRIPT_DIR}/../harness/qml_runner.sh"

SHELL_QML="${PROJECT_ROOT}/shell/shell.qml"
RUNTIME_HARNESS="${HARNESS_DIR}/test_t8_shell_wiring_quickshell.qml"
ADVERSARIAL_HARNESS="${HARNESS_DIR}/test_t8_shell_wiring_adversarial.qml"

test_case "T8.04.1" "ShellWiring: shell/shell.qml exists"
assert_file_exists "${SHELL_QML}" "shell/shell.qml must exist"

test_case "T8.04.2" "ShellWiring: IpcHandler contains toggleEventLog method routing to OverlayController"
assert_grep "function\s+toggleEventLog\s*\(\)\s*:\s*void" "${SHELL_QML}" "IpcHandler must declare toggleEventLog(): void"
assert_grep "OverlayController\.toggleEventLog\(\)" "${SHELL_QML}" "toggleEventLog must invoke OverlayController.toggleEventLog()"

test_case "T8.04.3" "ShellWiring: eventLogLoader has source desktop/surfaces/EventLog.qml"
assert_grep "id:\s*eventLogLoader" "${SHELL_QML}" "Loader with id eventLogLoader must exist"
assert_grep 'source:\s*"desktop/surfaces/EventLog\.qml"' "${SHELL_QML}" "eventLogLoader source must be desktop/surfaces/EventLog.qml"

test_case "T8.04.4" "ShellWiring: eventLogLoader visibility bound to OverlayController.Surface.EventLog"
assert_grep "visible:\s*OverlayController\.activeSurface\s*===\s*OverlayController\.Surface\.EventLog" "${SHELL_QML}" "eventLogLoader visible condition must check Surface.EventLog"
assert_grep "asynchronous:\s*false" "${SHELL_QML}" "eventLogLoader must be synchronous (asynchronous: false)"

test_case "T8.04.5" "ShellWiring: notificationToastHost PanelWindow declared with target screen"
assert_grep "id:\s*notificationToastHost" "${SHELL_QML}" "PanelWindow notificationToastHost must exist"
assert_grep "screen:\s*root\.resolveTargetScreen\(\)" "${SHELL_QML}" "notificationToastHost must target resolved screen"
assert_grep 'color:\s*"transparent"' "${SHELL_QML}" "notificationToastHost background color must be transparent"

test_case "T8.04.6" "ShellWiring: notificationToastHost visibility bound to active toasts count"
assert_grep "visible:\s*NotificationService\.activeToasts\.count\s*>\s*0" "${SHELL_QML}" "notificationToastHost visible must check activeToasts.count > 0"
assert_grep "exclusionMode:\s*ExclusionMode\.Ignore" "${SHELL_QML}" "notificationToastHost exclusionMode must be ExclusionMode.Ignore"

test_case "T8.04.7" "ShellWiring: notificationToastHost LayerShell properties (Overlay layer, None focus, namespace)"
assert_grep "WlrLayershell\.layer:\s*WlrLayer\.Overlay" "${SHELL_QML}" "Layer must be WlrLayer.Overlay"
assert_grep "WlrLayershell\.keyboardFocus:\s*WlrKeyboardFocus\.None" "${SHELL_QML}" "keyboardFocus must be WlrKeyboardFocus.None"
assert_grep 'WlrLayershell\.namespace:\s*"ctos-notifications"' "${SHELL_QML}" 'namespace must be "ctos-notifications"'

test_case "T8.04.8" "ShellWiring: notificationToastHost anchors and margins below bar"
assert_grep "top:\s*Settings\.barHeight\s*\+\s*Theme\.spacingMedium" "${SHELL_QML}" "Top margin must be Settings.barHeight + Theme.spacingMedium"
assert_grep "right:\s*Theme\.spacingMedium" "${SHELL_QML}" "Right margin must be Theme.spacingMedium"

test_case "T8.04.9" "ShellWiring: notificationToastHost dimensions bound to toastStack"
assert_grep "implicitWidth:\s*360" "${SHELL_QML}" "notificationToastHost implicitWidth must be 360"
assert_grep "implicitHeight:\s*toastStack\.implicitHeight" "${SHELL_QML}" "notificationToastHost implicitHeight must bind to toastStack.implicitHeight"

test_case "T8.04.10" "ShellWiring: notificationToastHost hosts NotificationToasts component"
assert_grep "NotificationToasts\s*\{" "${SHELL_QML}" "notificationToastHost must instantiate NotificationToasts"
assert_grep "id:\s*toastStack" "${SHELL_QML}" "NotificationToasts instance must have id: toastStack"
assert_grep "width:\s*340" "${SHELL_QML}" "toastStack width must be 340"
assert_grep "anchors\.horizontalCenter:\s*parent\.horizontalCenter" "${SHELL_QML}" "toastStack must center horizontally"

test_case "T8.04.11" "ShellWiring: Code formatting compliance (LF, 4-space indent, no tabs)"
check_qml_format "${SHELL_QML}"

test_case "T8.04.12" "ShellWiring: Zero polling loops or persistent shell processes"
check_no_polling_loops "${SHELL_QML}"

test_case "T8.04.13" "ShellWiring: Greeter isolation verified"
check_no_greeter_imports "${SHELL_QML}"

test_case "T8.04.14" "ShellWiring: Quickshell runtime verification"
if [[ -f "${RUNTIME_HARNESS}" ]]; then
    run_qml_test_harness "${RUNTIME_HARNESS}" "T8 Shell Wiring Quickshell Runtime Harness"
else
    test_skip "Runtime harness file missing"
fi

test_case "T8.04.15" "ShellWiring: Quickshell adversarial stress verification"
if [[ -f "${ADVERSARIAL_HARNESS}" ]]; then
    run_qml_test_harness "${ADVERSARIAL_HARNESS}" "T8 Shell Wiring Quickshell Adversarial Harness"
else
    test_skip "Adversarial harness file missing"
fi

report_summary
