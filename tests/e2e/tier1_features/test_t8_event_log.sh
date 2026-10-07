#!/usr/bin/env bash
# ==============================================================================
# Tier 1 - Feature: T8 CommandCenter Overlay Surface
# Source: ORIGINAL_REQUEST §R2, PROJECT.md M2, DISPATCH.md
# ==============================================================================
set -u
set +e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../harness/mock_environment.sh"
source "${SCRIPT_DIR}/../harness/qml_runner.sh"

EVENT_LOG_QML="${PROJECT_ROOT}/shell/desktop/surfaces/CommandCenter.qml"
SURFACES_QMLDIR="${PROJECT_ROOT}/shell/desktop/surfaces/qmldir"
RUNTIME_HARNESS="${HARNESS_DIR}/test_t8_event_log_quickshell.qml"

test_case "T8.02.1" "CommandCenter: CommandCenter.qml exists in desktop/surfaces/"
assert_file_exists "${EVENT_LOG_QML}" "CommandCenter.qml must exist in desktop/surfaces/"

test_case "T8.02.2" "CommandCenter: Registered in surfaces/qmldir"
assert_file_exists "${SURFACES_QMLDIR}" "surfaces/qmldir must exist"
assert_grep "CommandCenter 1.0 CommandCenter.qml" "${SURFACES_QMLDIR}" "qmldir must register CommandCenter"

test_case "T8.02.3" "CommandCenter: Root component FocusScope with 360 width and focus: true"
assert_grep "FocusScope" "${EVENT_LOG_QML}" "Root must be FocusScope"
assert_grep "implicitWidth:\s*360" "${EVENT_LOG_QML}" "implicitWidth must be 360"
assert_grep "width:\s*360" "${EVENT_LOG_QML}" "width must be 360"
assert_grep "focus:\s*true" "${EVENT_LOG_QML}" "focus must be true"

test_case "T8.02.4" "CommandCenter: Background container handled by Dynamic Island"
# assert_grep "color:\s*Theme\.gray900" "${EVENT_LOG_QML}" "Background must be Theme.gray900"
# assert_grep "border\.color:\s*Theme\.borderMuted" "${EVENT_LOG_QML}" "Border must be Theme.borderMuted"
# assert_grep "border\.width:\s*Theme\.borderWidth" "${EVENT_LOG_QML}" "Border width must be Theme.borderWidth"

test_case "T8.02.5" "CommandCenter: Corner brackets decoration matching cyber aesthetic"
assert_grep "cornerBrackets" "${EVENT_LOG_QML}" "Corner brackets element must exist"
assert_grep "Theme\.cornerBracketMargin" "${EVENT_LOG_QML}" "Must use Theme.cornerBracketMargin"
assert_grep "Theme\.cornerBracketArmLength" "${EVENT_LOG_QML}" "Must use Theme.cornerBracketArmLength"
assert_grep "Theme\.cornerBracketThickness" "${EVENT_LOG_QML}" "Must use Theme.cornerBracketThickness"

test_case "T8.02.6" "CommandCenter: Inside click consumer MouseArea"
assert_grep "insideClickConsumer" "${EVENT_LOG_QML}" "Inside click consumer must exist"
assert_grep "preventStealing:\s*true" "${EVENT_LOG_QML}" "Must prevent event stealing"
assert_grep "mouse\.accepted\s*=\s*true" "${EVENT_LOG_QML}" "Must accept mouse clicks"

test_case "T8.02.7" "CommandCenter: Header with indicator dot, title, DND toggle, and close button"
assert_grep "// EVENT LOG" "${EVENT_LOG_QML}" "Header title must be // EVENT LOG"
assert_grep "NotificationService\.toggleDnd" "${EVENT_LOG_QML}" "DND toggle must call NotificationService.toggleDnd"
assert_grep "NotificationService\.doNotDisturb" "${EVENT_LOG_QML}" "DND toggle must bind to NotificationService.doNotDisturb"
assert_grep "OverlayController\.close" "${EVENT_LOG_QML}" "Close button must call OverlayController.close"

test_case "T8.02.8" "CommandCenter: Body ListView bound to NotificationService.history with clip: true"
assert_grep "ListView" "${EVENT_LOG_QML}" "Body must contain ListView"
assert_grep "NotificationService\.history" "${EVENT_LOG_QML}" "ListView must bind to NotificationService.history"
assert_grep "clip:\s*true" "${EVENT_LOG_QML}" "ListView must have clip: true"

test_case "T8.02.9" "CommandCenter: Card urgency styling, summary, body, and dismiss button"
assert_grep "Theme\.warningRed" "${EVENT_LOG_QML}" "Card must support Critical urgency Theme.warningRed"
assert_grep "Theme\.acidGreen" "${EVENT_LOG_QML}" "Card must support Normal urgency Theme.acidGreen"
assert_grep "Theme\.textMuted" "${EVENT_LOG_QML}" "Card must support Low urgency Theme.textMuted"
assert_grep "NotificationService\.dismissHistoryItem" "${EVENT_LOG_QML}" "Card must invoke NotificationService.dismissHistoryItem"

test_case "T8.02.10" "CommandCenter: Empty state standby message"
assert_grep "NO NOTIFICATIONS // STANDBY" "${EVENT_LOG_QML}" "Must show NO NOTIFICATIONS // STANDBY when empty"
assert_grep "NotificationService\.history\.count\s*===?\s*0" "${EVENT_LOG_QML}" "Empty state must bind to history count"

test_case "T8.02.11" "CommandCenter: Footer with CLEAR ALL button"
assert_grep "\[CLEAR ALL\]" "${EVENT_LOG_QML}" "Footer must contain [CLEAR ALL] button"
assert_grep "NotificationService\.clearAll" "${EVENT_LOG_QML}" "Footer must call NotificationService.clearAll"

test_case "T8.02.12" "CommandCenter: Tiered ESC handling"
assert_grep "Keys\.onEscapePressed" "${EVENT_LOG_QML}" "ESC handling required"

test_case "T8.02.13" "CommandCenter: Strict Theme token compliance (no raw hex colors)"
raw_hex_matches=$(grep -nE "#[0-9a-fA-F]{3,8}" "${EVENT_LOG_QML}" || true)
if [[ -n "${raw_hex_matches}" ]]; then
    CURRENT_TEST_FAILED=1
    CURRENT_TEST_REASON="Raw hex colors found in CommandCenter.qml: ${raw_hex_matches}"
fi

test_case "T8.02.14" "CommandCenter: Code formatting compliance (LF, 4-space indent, no tabs)"
check_qml_format "${EVENT_LOG_QML}"

test_case "T8.02.15" "CommandCenter: Zero polling loops or persistent shell processes"
check_no_polling_loops "${EVENT_LOG_QML}"

test_case "T8.02.16" "CommandCenter: Greeter isolation verified"
check_no_greeter_imports "${EVENT_LOG_QML}"

ADVERSARIAL_HARNESS="${HARNESS_DIR}/test_t8_event_log_adversarial.qml"

test_case "T8.02.17" "CommandCenter: Quickshell runtime verification"
if [[ -f "${RUNTIME_HARNESS}" ]]; then
    run_qml_test_harness "${RUNTIME_HARNESS}" "T8 CommandCenter Quickshell Runtime Harness"
else
    test_skip "Runtime harness file missing"
fi

test_case "T8.02.18" "CommandCenter: Quickshell adversarial stress verification"
if [[ -f "${ADVERSARIAL_HARNESS}" ]]; then
    run_qml_test_harness "${ADVERSARIAL_HARNESS}" "T8 CommandCenter Quickshell Adversarial Harness"
else
    test_skip "Adversarial harness file missing"
fi

report_summary
