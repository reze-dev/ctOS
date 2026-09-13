#!/usr/bin/env bash
# ==============================================================================
# Tier 1 - Feature: T8 NotificationToasts Popup Surface
# Source: ORIGINAL_REQUEST §R3, PROJECT.md M3, DISPATCH.md
# ==============================================================================
set -u
set +e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../harness/mock_environment.sh"
source "${SCRIPT_DIR}/../harness/qml_runner.sh"

TOASTS_QML="${PROJECT_ROOT}/shell/desktop/surfaces/NotificationToasts.qml"
SURFACES_QMLDIR="${PROJECT_ROOT}/shell/desktop/surfaces/qmldir"
RUNTIME_HARNESS="${HARNESS_DIR}/test_t8_notification_toasts_quickshell.qml"
ADVERSARIAL_HARNESS="${HARNESS_DIR}/test_t8_notification_toasts_adversarial.qml"

test_case "T8.03.1" "NotificationToasts: NotificationToasts.qml exists in desktop/surfaces/"
assert_file_exists "${TOASTS_QML}" "NotificationToasts.qml must exist in desktop/surfaces/"

test_case "T8.03.2" "NotificationToasts: Registered in surfaces/qmldir"
assert_file_exists "${SURFACES_QMLDIR}" "surfaces/qmldir must exist"
assert_grep "NotificationToasts 1.0 NotificationToasts.qml" "${SURFACES_QMLDIR}" "qmldir must register NotificationToasts"

test_case "T8.03.3" "NotificationToasts: Root component Item/Column with 340 width and implicit dimensions"
assert_grep "(Column|Item)" "${TOASTS_QML}" "Root must be Item or Column"
assert_grep "implicitWidth:\s*340" "${TOASTS_QML}" "implicitWidth must be 340"
assert_grep "width:\s*340" "${TOASTS_QML}" "width must be 340"
assert_grep "implicitHeight:" "${TOASTS_QML}" "implicitHeight must be declared"

test_case "T8.03.4" "NotificationToasts: Bound to NotificationService.activeToasts model"
assert_grep "NotificationService\.activeToasts" "${TOASTS_QML}" "Must bind to NotificationService.activeToasts"

test_case "T8.03.5" "NotificationToasts: Background container with Theme.gray900 and Theme.borderWidth"
assert_grep "Theme\.gray900" "${TOASTS_QML}" "Background must use Theme.gray900"
assert_grep "Theme\.borderWidth" "${TOASTS_QML}" "Border width must use Theme.borderWidth"

test_case "T8.03.6" "NotificationToasts: Urgency border colors (Critical, Normal, Low)"
assert_grep "Theme\.warningRed" "${TOASTS_QML}" "Must support Critical urgency Theme.warningRed"
assert_grep "Theme\.acidGreen" "${TOASTS_QML}" "Must support Normal urgency Theme.acidGreen"
assert_grep "Theme\.textMuted" "${TOASTS_QML}" "Must support Low urgency Theme.textMuted"

test_case "T8.03.7" "NotificationToasts: Header line with app name and timestamp"
assert_grep "Theme\.fontSizeCaption" "${TOASTS_QML}" "Header must use Theme.fontSizeCaption"
assert_grep "Theme\.textSecondary" "${TOASTS_QML}" "Header app name must use Theme.textSecondary"
assert_grep "Theme\.textMuted" "${TOASTS_QML}" "Header timestamp must use Theme.textMuted"

test_case "T8.03.8" "NotificationToasts: Summary text (bold, small font, textPrimary)"
assert_grep "Theme\.fontSizeSmall" "${TOASTS_QML}" "Summary must use Theme.fontSizeSmall"
assert_grep "Theme\.textPrimary" "${TOASTS_QML}" "Summary must use Theme.textPrimary"
assert_grep "(Theme\.fontWeightBold|font\.bold)" "${TOASTS_QML}" "Summary must be bold"

test_case "T8.03.9" "NotificationToasts: Body text (fontSizeCaption, textSecondary, word wrap, max 3 lines, elide)"
assert_grep "Theme\.fontSizeCaption" "${TOASTS_QML}" "Body must use Theme.fontSizeCaption"
assert_grep "Theme\.textSecondary" "${TOASTS_QML}" "Body must use Theme.textSecondary"
assert_grep "maximumLineCount:\s*3" "${TOASTS_QML}" "Body must have max 3 lines"
assert_grep "Text\.WordWrap" "${TOASTS_QML}" "Body must wrap words"
assert_grep "Text\.ElideRight" "${TOASTS_QML}" "Body must elide text"

test_case "T8.03.10" "NotificationToasts: Action buttons rendered and invoking action"
assert_grep "cardItem\.actions" "${TOASTS_QML}" "Must check cardItem.actions"
assert_grep "invoke" "${TOASTS_QML}" "Action button must call invoke"

test_case "T8.03.11" "NotificationToasts: Auto-fade out transition on expiry"
assert_grep "(Behavior on opacity|NumberAnimation)" "${TOASTS_QML}" "Must define opacity transition/animation"

test_case "T8.03.12" "NotificationToasts: Hover behavior pauses and resumes toast timer"
assert_grep "NotificationService\.pauseToastTimer" "${TOASTS_QML}" "Must call NotificationService.pauseToastTimer on hover"
assert_grep "NotificationService\.resumeToastTimer" "${TOASTS_QML}" "Must call NotificationService.resumeToastTimer on exit"

test_case "T8.03.13" "NotificationToasts: Clicking toast dismisses it"
assert_grep "NotificationService\.dismissToast" "${TOASTS_QML}" "Must call NotificationService.dismissToast on click"

test_case "T8.03.14" "NotificationToasts: Pulsing red border animation for critical urgency"
assert_grep "SequentialAnimation" "${TOASTS_QML}" "Must use SequentialAnimation for pulse"
assert_grep "Animation\.Infinite" "${TOASTS_QML}" "Pulse must loop infinitely"
assert_grep "Theme\.warningRed" "${TOASTS_QML}" "Pulse must use Theme.warningRed"

test_case "T8.03.15" "NotificationToasts: Strict Theme token compliance (no raw hex colors)"
raw_hex_matches=$(grep -nE "#[0-9a-fA-F]{3,8}" "${TOASTS_QML}" || true)
if [[ -n "${raw_hex_matches}" ]]; then
    CURRENT_TEST_FAILED=1
    CURRENT_TEST_REASON="Raw hex colors found in NotificationToasts.qml: ${raw_hex_matches}"
fi

test_case "T8.03.16" "NotificationToasts: Code formatting compliance (LF, 4-space indent, no tabs)"
check_qml_format "${TOASTS_QML}"

test_case "T8.03.17" "NotificationToasts: Zero polling loops or persistent shell processes"
check_no_polling_loops "${TOASTS_QML}"

test_case "T8.03.18" "NotificationToasts: Greeter isolation verified"
check_no_greeter_imports "${TOASTS_QML}"

test_case "T8.03.19" "NotificationToasts: Quickshell runtime verification"
if [[ -f "${RUNTIME_HARNESS}" ]]; then
    run_qml_test_harness "${RUNTIME_HARNESS}" "T8 NotificationToasts Quickshell Runtime Harness"
else
    test_skip "Runtime harness file missing"
fi

test_case "T8.03.20" "NotificationToasts: Quickshell adversarial stress verification"
if [[ -f "${ADVERSARIAL_HARNESS}" ]]; then
    run_qml_test_harness "${ADVERSARIAL_HARNESS}" "T8 NotificationToasts Quickshell Adversarial Harness"
else
    test_skip "Adversarial harness file missing"
fi

report_summary
