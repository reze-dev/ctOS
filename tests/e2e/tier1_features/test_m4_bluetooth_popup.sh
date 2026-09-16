#!/usr/bin/env bash
# ==============================================================================
# Tier 1 - Milestone 4: Bluetooth Popup & Shell Wiring Acceptance (R3)
# ==============================================================================
set -u
set +e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../harness/mock_environment.sh"
source "${SCRIPT_DIR}/../harness/qml_runner.sh"

BLUETOOTH_POPUP="${PROJECT_ROOT}/shell/desktop/surfaces/components/BluetoothPopup.qml"
COMPONENTS_QMLDIR="${PROJECT_ROOT}/shell/desktop/surfaces/components/qmldir"
AMBIENT_BAR="${PROJECT_ROOT}/shell/desktop/surfaces/AmbientBar.qml"
SHELL_QML="${PROJECT_ROOT}/shell/shell.qml"
SYSTEM_RAIL="${PROJECT_ROOT}/shell/desktop/surfaces/SystemRail.qml"

POPUP_RUNTIME_HARNESS="${HARNESS_DIR}/test_m4_bluetooth_popup_runtime.qml"
SHELL_WIRING_HARNESS="${HARNESS_DIR}/test_m4_bluetooth_shell_wiring.qml"
AUDIT_SCRIPT="${PROJECT_ROOT}/tests/e2e/test_m4_bluetooth_popup_audit.py"

# ------------------------------------------------------------------------------
# 1. Component File Existence & Registration
# ------------------------------------------------------------------------------
test_case "T1.M4.BT.1" "BluetoothPopup: file exists in components/"
assert_file_exists "${BLUETOOTH_POPUP}"

test_case "T1.M4.BT.2" "BluetoothPopup: registered in components/qmldir"
assert_grep "BluetoothPopup\s+1\.0\s+BluetoothPopup\.qml" "${COMPONENTS_QMLDIR}" "BluetoothPopup must be registered in qmldir"

# ------------------------------------------------------------------------------
# 2. BluetoothPopup Theming, Dimensions & Styling Tokens
# ------------------------------------------------------------------------------
test_case "T1.M4.BT.3" "BluetoothPopup: width is 320px"
assert_grep "implicitWidth:\s*320" "${BLUETOOTH_POPUP}" "BluetoothPopup implicitWidth must be 320"
assert_grep "width:\s*320" "${BLUETOOTH_POPUP}" "BluetoothPopup width must be 320"

test_case "T1.M4.BT.4" "BluetoothPopup: Theme tokens used for surface & borders"
assert_grep "color:\s*Theme\.gray900" "${BLUETOOTH_POPUP}" "BluetoothPopup background must be Theme.gray900"
assert_grep "border\.color:\s*Theme\.borderMuted" "${BLUETOOTH_POPUP}" "BluetoothPopup border must be Theme.borderMuted"
assert_grep "radius:\s*Theme\.radiusSmall" "${BLUETOOTH_POPUP}" "BluetoothPopup radius must be Theme.radiusSmall"

test_case "T1.M4.BT.5" "BluetoothPopup: cyberpunk corner brackets with acidGreen"
assert_grep "cornerBrackets" "${BLUETOOTH_POPUP}" "BluetoothPopup must include corner brackets"
assert_grep "bracketColor:\s*Theme\.acidGreen" "${BLUETOOTH_POPUP}" "Corner brackets must use Theme.acidGreen"

test_case "T1.M4.BT.6" "BluetoothPopup: typography uses Theme.fontFamilyMonospace"
assert_grep "font\.family:\s*Theme\.fontFamilyMonospace" "${BLUETOOTH_POPUP}" "BluetoothPopup text must use Theme.fontFamilyMonospace"

test_case "T1.M4.BT.7" "BluetoothPopup: inside click consumer MouseArea"
assert_grep "preventStealing:\s*true" "${BLUETOOTH_POPUP}" "Inside click consumer must preventStealing"
assert_grep "mouse(?:\.accepted\s*=\s*true|\s*=>\s*mouse\.accepted\s*=\s*true)" "${BLUETOOTH_POPUP}" "Inside click consumer must accept mouse events"

test_case "T1.M4.BT.8" "BluetoothPopup: public closeRequested signal"
check_qml_signal "${BLUETOOTH_POPUP}" "closeRequested"

# ------------------------------------------------------------------------------
# 3. AmbientBar Bluetooth Integration & Mouse Action
# ------------------------------------------------------------------------------
test_case "T1.M4.BT.9" "AmbientBar: declares toggleBluetooth signal"
check_qml_signal "${AMBIENT_BAR}" "toggleBluetooth"

test_case "T1.M4.BT.10" "AmbientBar: bluetoothMouseArea dual left/right click action"
assert_grep "acceptedButtons:\s*Qt\.LeftButton\s*\|\s*Qt\.RightButton" "${AMBIENT_BAR}" "AmbientBar must accept Left and Right mouse buttons"
assert_grep "BluetoothService\.togglePower\(\)" "${AMBIENT_BAR}" "AmbientBar must call BluetoothService.togglePower() on right click"
assert_grep "root\.toggleBluetooth\(\)" "${AMBIENT_BAR}" "AmbientBar must call root.toggleBluetooth() on left click"

test_case "T1.M4.BT.11" "AmbientBar: slot order preserved between battery and clock"
python3 -c "
import sys, re
with open('${AMBIENT_BAR}', 'r') as f:
    sys.exit(0 if re.search(r'id:\s*batterySection[\s\S]*?id:\s*bluetoothSection[\s\S]*?id:\s*clockSection', f.read()) else 1)
"
if [[ $? -ne 0 ]]; then
    CURRENT_TEST_FAILED=1
    CURRENT_TEST_REASON="bluetoothSection must be between battery and clock"
fi

# ------------------------------------------------------------------------------
# 4. Shell.qml State, IPC, and PanelWindows
# ------------------------------------------------------------------------------
test_case "T1.M4.BT.12" "shell.qml: imports desktop/surfaces/components"
assert_grep 'import\s+"desktop/surfaces/components"' "${SHELL_QML}" "shell.qml must import components"

test_case "T1.M4.BT.13" "shell.qml: declares bluetoothVisible property"
check_qml_property "${SHELL_QML}" "bluetoothVisible" --type bool

test_case "T1.M4.BT.14" "shell.qml: declares toggleBluetooth method"
check_qml_method "${SHELL_QML}" "toggleBluetooth"

test_case "T1.M4.BT.15" "shell.qml: declares closeBluetooth method"
check_qml_method "${SHELL_QML}" "closeBluetooth"

test_case "T1.M4.BT.16" "shell.qml: IpcHandler has toggleBluetooth"
assert_grep "function\s+toggleBluetooth\(\):\s*void" "${SHELL_QML}" "IpcHandler must expose toggleBluetooth"

test_case "T1.M4.BT.17" "shell.qml: barVariants delegates forward onToggleBluetooth"
assert_grep "onToggleBluetooth:\s*root\.toggleBluetooth\(modelData\)" "${SHELL_QML}" "barVariants must pass modelData to toggleBluetooth"

test_case "T1.M4.BT.18" "shell.qml: mutual exclusivity between popups"
assert_grep "root\.closeCalendar\(\)" "${SHELL_QML}" "toggleBluetooth must close Calendar"
assert_grep "root\.closeBluetooth\(\)" "${SHELL_QML}" "toggleCalendar must close Bluetooth"

test_case "T1.M4.BT.19" "shell.qml: closes bluetooth on overlay opened"
assert_grep "root\.closeBluetooth\(\)" "${SHELL_QML}" "shell.qml must close bluetooth on overlay open or disconnect"

test_case "T1.M4.BT.20" "shell.qml: bluetoothBackdropHost defines non-focus dismiss backdrop"
assert_grep "bluetoothBackdropHost" "${SHELL_QML}" "bluetoothBackdropHost must exist in shell.qml"
assert_grep "WlrLayershell\.layer:\s*WlrLayer\.Top" "${SHELL_QML}" "bluetoothBackdropHost must be on WlrLayer.Top"
assert_grep "WlrLayershell\.keyboardFocus:\s*WlrKeyboardFocus\.None" "${SHELL_QML}" "bluetoothBackdropHost must have KeyboardFocus.None"
assert_grep 'namespace:\s*"ctos-bluetooth-backdrop"' "${SHELL_QML}" "bluetoothBackdropHost must have ctos-bluetooth-backdrop namespace"

test_case "T1.M4.BT.21" "shell.qml: bluetoothPopupHost defines overlay PanelWindow hosting BluetoothPopup"
assert_grep "bluetoothPopupHost" "${SHELL_QML}" "bluetoothPopupHost must exist in shell.qml"
assert_grep "WlrLayershell\.layer:\s*WlrLayer\.Overlay" "${SHELL_QML}" "bluetoothPopupHost must be on WlrLayer.Overlay"
assert_grep "BluetoothPopup\s*\{" "${SHELL_QML}" "bluetoothPopupHost must instantiate BluetoothPopup"
assert_grep "onCloseRequested:\s*root\.closeBluetooth\(\)" "${SHELL_QML}" "BluetoothPopup closeRequested must close bluetooth"

# ------------------------------------------------------------------------------
# 5. System Rail Session Actions Verification
# ------------------------------------------------------------------------------
test_case "T1.M4.BT.22" "SystemRail: declarative Process session nodes"
assert_grep "id:\s*lockProcess" "${SYSTEM_RAIL}" "lockProcess must be declared in SystemRail"
assert_grep "id:\s*logoutProcess" "${SYSTEM_RAIL}" "logoutProcess must be declared in SystemRail"
assert_grep "id:\s*rebootProcess" "${SYSTEM_RAIL}" "rebootProcess must be declared in SystemRail"
assert_grep "id:\s*poweroffProcess" "${SYSTEM_RAIL}" "poweroffProcess must be declared in SystemRail"
assert_not_grep "running:\s*true" "${SYSTEM_RAIL}" "SystemRail must not contain static running: true"

# ------------------------------------------------------------------------------
# 6. Format & Isolation Compliance
# ------------------------------------------------------------------------------
test_case "T1.M4.BT.23" "Code formatting compliance"
check_qml_format "${BLUETOOTH_POPUP}"
check_qml_format "${AMBIENT_BAR}"
check_qml_format "${SHELL_QML}"
check_qml_format "${SYSTEM_RAIL}"

test_case "T1.M4.BT.24" "Greeter isolation & zero-polling compliance"
check_no_greeter_imports "${PROJECT_ROOT}/shell/desktop"
check_no_greeter_imports "${SHELL_QML}"
check_no_polling_loops "${PROJECT_ROOT}/shell/desktop"
check_no_polling_loops "${SHELL_QML}"

# ------------------------------------------------------------------------------
# 7. Static AST & Token Audit Suite
# ------------------------------------------------------------------------------
test_case "T1.M4.BT.25" "Static AST & Token Audit (test_m4_bluetooth_popup_audit.py)"
if [[ -f "${AUDIT_SCRIPT}" ]]; then
    python3 "${AUDIT_SCRIPT}" >/dev/null 2>&1
    local_audit_ret=$?
    if [[ "${local_audit_ret}" -ne 0 ]]; then
        CURRENT_TEST_FAILED=1
        CURRENT_TEST_REASON="test_m4_bluetooth_popup_audit.py exited with code ${local_audit_ret}"
    fi
else
    test_skip "Audit script missing"
fi

# ------------------------------------------------------------------------------
# 8. Empirical Runtime Test Execution
# ------------------------------------------------------------------------------
test_case "T1.M4.BT.26" "Quickshell runtime verification of BluetoothPopup"
if [[ -f "${POPUP_RUNTIME_HARNESS}" ]]; then
    run_qml_test_harness "${POPUP_RUNTIME_HARNESS}" "Milestone 4 Bluetooth Popup Runtime Harness"
else
    test_skip "Popup runtime harness file missing"
fi

test_case "T1.M4.BT.27" "Quickshell runtime verification of Shell Wiring & Multi-Monitor"
if [[ -f "${SHELL_WIRING_HARNESS}" ]]; then
    run_qml_test_harness "${SHELL_WIRING_HARNESS}" "Milestone 4 Bluetooth Shell Wiring Harness"
else
    test_skip "Shell wiring harness file missing"
fi

report_summary
