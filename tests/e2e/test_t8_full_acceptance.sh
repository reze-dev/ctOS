#!/usr/bin/env bash
# ==============================================================================
# test_t8_full_acceptance.sh - Master Unified Acceptance Test Suite for ctOS T8
# Covers all 13 Acceptance Criteria from ORIGINAL_REQUEST.md + Regression Suites
# ==============================================================================
set -u
set +e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/harness/mock_environment.sh"
source "${SCRIPT_DIR}/harness/qml_runner.sh"

echo "================================================================================"
echo "ctOS T8: Full Acceptance & Regression Master Suite"
echo "================================================================================"

# ==============================================================================
# SECTION 1: MASTER 13 ACCEPTANCE CRITERIA RUNTIME VERIFICATION
# ==============================================================================
test_case "T8.MASTER.01" "AC1: notify-send shows toast popup in top-right below bar"
test_case "T8.MASTER.02" "AC2: Toast auto-dismisses after ~5s (Normal urgency)"
test_case "T8.MASTER.03" "AC3: Critical urgency toasts show red accent and last 10s"
test_case "T8.MASTER.04" "AC4: Hovering a toast pauses its expiry timer"
test_case "T8.MASTER.05" "AC5: Dismissed/expired toasts appear in Event Log history"
test_case "T8.MASTER.06" "AC6: Opening Event Log shows scrollable history with urgency cards"
test_case "T8.MASTER.07" "AC7: DND toggle suppresses toasts but still records to history"
test_case "T8.MASTER.08" "AC8: [CLEAR ALL] empties the entire history"
test_case "T8.MASTER.09" "AC9: Individual [DISMISS] works per notification in Event Log"
test_case "T8.MASTER.10" "AC10: ESC closes the Event Log overlay"
test_case "T8.MASTER.11" "AC11: Toast popups do NOT steal keyboard focus from active window"
test_case "T8.MASTER.12" "AC12: Multiple toasts stack vertically (max 3 visible)"
test_case "T8.MASTER.13" "AC13: ctos-shell-msg toggleEventLog works via IPC"

MASTER_HARNESS="${HARNESS_DIR}/test_t8_acceptance_all.qml"
if [[ -f "${MASTER_HARNESS}" ]]; then
    harness_output=$(run_qml_test_harness "${MASTER_HARNESS}" "Master Acceptance Criteria Suite" 12)
    harness_ret=$?
    if [[ ${harness_ret} -ne 0 ]]; then
        CURRENT_TEST_FAILED=1
        CURRENT_TEST_REASON="Master Acceptance QML harness execution failed"
    fi
else
    CURRENT_TEST_FAILED=1
    CURRENT_TEST_REASON="Missing harness: ${MASTER_HARNESS}"
fi

test_case "T8.MASTER.EXEC" "Unified Master QML Runtime Harness Execution (All 13 ACs)"
if [[ "${harness_ret:-1}" -eq 0 ]] && echo "${harness_output:-}" | grep -q "PASS: ALL 13 ACCEPTANCE CRITERIA VERIFIED"; then
    echo "  Master Acceptance Criteria harness passed cleanly."
else
    CURRENT_TEST_FAILED=1
    CURRENT_TEST_REASON="Master harness did not verify all 13 ACs"
fi

# ==============================================================================
# SECTION 2: TIER 1 FEATURE TEST SUITES
# ==============================================================================
echo ""
echo "--- Running Tier 1 Feature Test Suites ---"

test_case "T8.SUITE.01" "Feature Suite: NotificationService Singleton (test_t8_notification_service.sh)"
if bash "${SCRIPT_DIR}/tier1_features/test_t8_notification_service.sh" >/dev/null 2>&1; then
    echo "  NotificationService feature suite passed."
else
    CURRENT_TEST_FAILED=1
    CURRENT_TEST_REASON="test_t8_notification_service.sh failed"
fi

test_case "T8.SUITE.02" "Feature Suite: EventLog Overlay Surface (test_t8_event_log.sh)"
if bash "${SCRIPT_DIR}/tier1_features/test_t8_event_log.sh" >/dev/null 2>&1; then
    echo "  EventLog feature suite passed."
else
    CURRENT_TEST_FAILED=1
    CURRENT_TEST_REASON="test_t8_event_log.sh failed"
fi

test_case "T8.SUITE.03" "Feature Suite: NotificationToasts Surface (test_t8_notification_toasts.sh)"
if bash "${SCRIPT_DIR}/tier1_features/test_t8_notification_toasts.sh" >/dev/null 2>&1; then
    echo "  NotificationToasts feature suite passed."
else
    CURRENT_TEST_FAILED=1
    CURRENT_TEST_REASON="test_t8_notification_toasts.sh failed"
fi

test_case "T8.SUITE.04" "Feature Suite: Shell Wiring & IPC (test_t8_shell_wiring.sh)"
if bash "${SCRIPT_DIR}/tier1_features/test_t8_shell_wiring.sh" >/dev/null 2>&1; then
    echo "  Shell wiring feature suite passed."
else
    CURRENT_TEST_FAILED=1
    CURRENT_TEST_REASON="test_t8_shell_wiring.sh failed"
fi

# ==============================================================================
# SECTION 3: SHELL REGRESSION SUITES
# ==============================================================================
echo ""
echo "--- Running Shell Regression Test Suites ---"

test_case "T8.REGRESS.01" "Regression Suite: OverlayController (test_overlay_controller.sh)"
if bash "${SCRIPT_DIR}/tier1_features/test_overlay_controller.sh" >/dev/null 2>&1; then
    echo "  OverlayController regression suite passed."
else
    CURRENT_TEST_FAILED=1
    CURRENT_TEST_REASON="test_overlay_controller.sh failed"
fi

test_case "T8.REGRESS.02" "Regression Suite: Overlay Dismissal (test_overlay_dismissal.sh)"
if bash "${SCRIPT_DIR}/tier1_features/test_overlay_dismissal.sh" >/dev/null 2>&1; then
    echo "  Overlay dismissal regression suite passed."
else
    CURRENT_TEST_FAILED=1
    CURRENT_TEST_REASON="test_overlay_dismissal.sh failed"
fi

test_case "T8.REGRESS.03" "Regression Suite: Zero Polling Architecture (test_zero_polling.sh)"
if bash "${SCRIPT_DIR}/tier1_features/test_zero_polling.sh" >/dev/null 2>&1; then
    echo "  Zero polling regression suite passed."
else
    CURRENT_TEST_FAILED=1
    CURRENT_TEST_REASON="test_zero_polling.sh failed"
fi

# ==============================================================================
# SECTION 4: ADVERSARIAL STRESS SUITES
# ==============================================================================
echo ""
echo "--- Running Adversarial Stress Test Suites ---"

test_case "T8.ADV.01" "Adversarial Suite: NotificationService Stress (test_t8_notification_service_adversarial.sh)"
if bash "${SCRIPT_DIR}/tier1_features/test_t8_notification_service_adversarial.sh" >/dev/null 2>&1; then
    echo "  NotificationService adversarial suite passed."
else
    CURRENT_TEST_FAILED=1
    CURRENT_TEST_REASON="test_t8_notification_service_adversarial.sh failed"
fi

test_case "T8.ADV.02" "Adversarial Suite: Challenger M3 Stress (test_t8_challenger_m3_stress.qml)"
CHALLENGER_M3="${HARNESS_DIR}/test_t8_challenger_m3_stress.qml"
if [[ -f "${CHALLENGER_M3}" ]]; then
    if run_qml_test_harness "${CHALLENGER_M3}" "Challenger M3 Stress Harness" 12 >/dev/null 2>&1; then
        echo "  Challenger M3 stress harness passed."
    else
        CURRENT_TEST_FAILED=1
        CURRENT_TEST_REASON="test_t8_challenger_m3_stress.qml failed"
    fi
else
    CURRENT_TEST_FAILED=1
    CURRENT_TEST_REASON="Missing harness: ${CHALLENGER_M3}"
fi

echo ""
report_summary
