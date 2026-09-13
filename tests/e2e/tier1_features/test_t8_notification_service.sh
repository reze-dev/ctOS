#!/usr/bin/env bash
# ==============================================================================
# Tier 1 - Feature: T8 NotificationService Singleton
# Source: ORIGINAL_REQUEST §R1, PROJECT.md M1, DISPATCH.md
# ==============================================================================
set -u
set +e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../harness/mock_environment.sh"
source "${SCRIPT_DIR}/../harness/qml_runner.sh"

NOTIF_SVC="${PROJECT_ROOT}/shell/desktop/services/NotificationService.qml"
SERVICES_QMLDIR="${PROJECT_ROOT}/shell/desktop/services/qmldir"
RUNTIME_HARNESS="${HARNESS_DIR}/test_t8_notification_service_quickshell.qml"

test_case "T8.01.1" "Notification Service: NotificationService.qml exists in desktop/services/"
assert_file_exists "${NOTIF_SVC}" "NotificationService.qml must exist in desktop/services/"

test_case "T8.01.2" "Notification Service: Registered as singleton in services/qmldir"
assert_file_exists "${SERVICES_QMLDIR}" "services/qmldir must exist"
assert_grep "singleton NotificationService 1.0 NotificationService.qml" "${SERVICES_QMLDIR}" "qmldir must register NotificationService singleton"

test_case "T8.01.3" "Notification Service: Exposes available, doNotDisturb, unreadCount, history, activeToasts properties"
if [[ -f "${NOTIF_SVC}" ]]; then
    check_qml_property "${NOTIF_SVC}" "available" || assert_grep "available" "${NOTIF_SVC}" "available property required"
    check_qml_property "${NOTIF_SVC}" "doNotDisturb" || assert_grep "doNotDisturb" "${NOTIF_SVC}" "doNotDisturb property required"
    check_qml_property "${NOTIF_SVC}" "unreadCount" --readonly || assert_grep "unreadCount" "${NOTIF_SVC}" "unreadCount property required"
    check_qml_property "${NOTIF_SVC}" "history" --readonly || assert_grep "history" "${NOTIF_SVC}" "history property required"
    check_qml_property "${NOTIF_SVC}" "activeToasts" --readonly || assert_grep "activeToasts" "${NOTIF_SVC}" "activeToasts property required"
else
    assert_file_exists "${NOTIF_SVC}"
fi

test_case "T8.01.4" "Notification Service: Exposes required methods"
if [[ -f "${NOTIF_SVC}" ]]; then
    check_qml_method "${NOTIF_SVC}" "toggleDnd" || assert_grep "toggleDnd" "${NOTIF_SVC}" "toggleDnd method required"
    check_qml_method "${NOTIF_SVC}" "dismissToast" || assert_grep "dismissToast" "${NOTIF_SVC}" "dismissToast method required"
    check_qml_method "${NOTIF_SVC}" "dismissHistoryItem" || assert_grep "dismissHistoryItem" "${NOTIF_SVC}" "dismissHistoryItem method required"
    check_qml_method "${NOTIF_SVC}" "clearAll" || assert_grep "clearAll" "${NOTIF_SVC}" "clearAll method required"
    check_qml_method "${NOTIF_SVC}" "pauseToastTimer" || assert_grep "pauseToastTimer" "${NOTIF_SVC}" "pauseToastTimer method required"
    check_qml_method "${NOTIF_SVC}" "resumeToastTimer" || assert_grep "resumeToastTimer" "${NOTIF_SVC}" "resumeToastTimer method required"
else
    assert_file_exists "${NOTIF_SVC}"
fi

test_case "T8.01.5" "Notification Service: Code formatting compliance (LF, 4-space indent, no tabs)"
check_qml_format "${NOTIF_SVC}"

test_case "T8.01.6" "Notification Service: Zero polling loops or persistent shell processes"
check_no_polling_loops "${NOTIF_SVC}"

test_case "T8.01.7" "Notification Service: Greeter isolation verified"
check_no_greeter_imports "${NOTIF_SVC}"

test_case "T8.01.8" "Notification Service: Quickshell runtime verification"
if [[ -f "${RUNTIME_HARNESS}" ]]; then
    run_qml_test_harness "${RUNTIME_HARNESS}" "T8 NotificationService Quickshell Runtime Harness"
else
    test_skip "Runtime harness file missing"
fi

report_summary
