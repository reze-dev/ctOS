#!/usr/bin/env bash
# ==============================================================================
# Tier 1 - Feature 28: Headless SessionService & Compositor Integration
# Source: ORIGINAL_REQUEST §R2, §R3, §R4, PROJECT.md, TEST_INFRA.md
# ==============================================================================
set -u
set +e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../harness/mock_environment.sh"
source "${SCRIPT_DIR}/../harness/qml_runner.sh"

SESSION_SVC="${PROJECT_ROOT}/shell/desktop/services/SessionService.qml"
COMPOSITOR_SVC="${PROJECT_ROOT}/shell/desktop/services/CompositorService.qml"
QMLDIR="${PROJECT_ROOT}/shell/desktop/services/qmldir"
SYSTEM_RAIL="${PROJECT_ROOT}/shell/desktop/surfaces/SystemRail.qml"
ACTION_REG="${PROJECT_ROOT}/shell/desktop/core/ActionRegistry.qml"
RUNTIME_HARNESS="${PROJECT_ROOT}/tests/e2e/harness/test_session_service_runtime.qml"
ADVERSARIAL_PY="${PROJECT_ROOT}/tests/e2e/test_session_service_adversarial.py"

# Setup isolated mock environment for safe command interception
MOCK_BIN_DIR=$(mktemp -d "/tmp/ctos-t5-mock-XXXXXX")
for b in loginctl hyprctl niri systemctl hyprlock; do
    cat << 'EOF' > "${MOCK_BIN_DIR}/${b}"
#!/bin/sh
exit 0
EOF
    chmod +x "${MOCK_BIN_DIR}/${b}"
done

cleanup_mock_bins() {
    if [[ -d "${MOCK_BIN_DIR}" ]]; then
        rm -rf "${MOCK_BIN_DIR}"
    fi
}
trap 'cleanup_mock_bins; cleanup_harness' EXIT INT TERM
export PATH="${MOCK_BIN_DIR}:${PATH}"

# ------------------------------------------------------------------------------
# Test Cases
# ------------------------------------------------------------------------------

test_case "T1.28.1" "SessionService: Interface file and singleton registration exist"
assert_file_exists "${SESSION_SVC}" "SessionService.qml must exist in desktop/services/"
assert_grep "pragma\s+Singleton" "${SESSION_SVC}" "SessionService must declare pragma Singleton"
assert_grep "singleton\s+SessionService\s+1\.0\s+SessionService\.qml" "${QMLDIR}" \
    "SessionService must be registered in desktop/services/qmldir"

test_case "T1.28.2" "SessionService: Exposes reactive process status properties"
check_qml_property "${SESSION_SVC}" "isLocking"
check_qml_property "${SESSION_SVC}" "isLoggingOut"
check_qml_property "${SESSION_SVC}" "isRebooting"
check_qml_property "${SESSION_SVC}" "isPoweringOff"
check_qml_property "${SESSION_SVC}" "isBusy"

test_case "T1.28.3" "SessionService: Exposes public session action methods"
check_qml_method "${SESSION_SVC}" "lock"
check_qml_method "${SESSION_SVC}" "logout"
check_qml_method "${SESSION_SVC}" "reboot"
check_qml_method "${SESSION_SVC}" "poweroff"
check_qml_method "${SESSION_SVC}" "executeAction"

test_case "T1.28.4" "SessionService: Exposes lifecycle signals"
check_qml_signal "${SESSION_SVC}" "sessionActionTriggered"
check_qml_signal "${SESSION_SVC}" "sessionActionFinished"

test_case "T1.28.5" "SessionService: Compositor detection and dynamic logout routing"
check_qml_property "${SESSION_SVC}" "isNiri"
check_qml_property "${SESSION_SVC}" "isHyprland"
check_qml_property "${SESSION_SVC}" "logoutCommand"
assert_grep '\[\s*"niri"\s*,\s*"msg"\s*,\s*"action"\s*,\s*"quit"\s*\]' "${SESSION_SVC}" \
    "SessionService must route Niri logout to ['niri', 'msg', 'action', 'quit']"
assert_grep '\[\s*"hyprctl"\s*,\s*"dispatch"\s*,\s*"exit"\s*\]' "${SESSION_SVC}" \
    "SessionService must route Hyprland logout to ['hyprctl', 'dispatch', 'exit']"

test_case "T1.28.6" "SessionService: Zero polling loops and absence of Timer"
check_no_polling_loops "${SESSION_SVC}"
assert_not_grep "Timer\s*\{" "${SESSION_SVC}" "SessionService must not contain Timer elements"

test_case "T1.28.7" "SessionService: Greeter isolation verified"
check_no_greeter_imports "${PROJECT_ROOT}/shell/desktop"

test_case "T1.28.8" "SessionService: UI wiring integration in SystemRail and ActionRegistry"
assert_grep "SessionService\.lock\(\)" "${ACTION_REG}" "ActionRegistry must route action-lock to SessionService.lock()"
assert_grep "SessionService\.lock\(\)" "${SYSTEM_RAIL}" "SystemRail must route lock to SessionService.lock()"
assert_grep "SessionService\.logout\(\)" "${SYSTEM_RAIL}" "SystemRail must route logout to SessionService.logout()"
assert_grep "SessionService\.reboot\(\)" "${SYSTEM_RAIL}" "SystemRail must route reboot to SessionService.reboot()"
assert_grep "SessionService\.poweroff\(\)" "${SYSTEM_RAIL}" "SystemRail must route poweroff to SessionService.poweroff()"

test_case "T1.28.9" "SessionService: Headless Quickshell runtime harness & UI destruction survival"
assert_file_exists "${RUNTIME_HARNESS}" "test_session_service_runtime.qml must exist"
run_qml_test_harness "${RUNTIME_HARNESS}" "SessionService Headless Runtime & UI Destruction Survival" 15

test_case "T1.28.10" "SessionService: Adversarial Python stress suite execution"
assert_file_exists "${ADVERSARIAL_PY}" "test_session_service_adversarial.py must exist"
set +e
python3 "${ADVERSARIAL_PY}" >/dev/null 2>&1
adv_rc=$?
set -u
assert_eq 0 "${adv_rc}" "Adversarial stress suite must exit with code 0"

report_summary
