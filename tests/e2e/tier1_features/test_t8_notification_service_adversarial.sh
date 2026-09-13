#!/usr/bin/env bash
# ==============================================================================
# Tier 1 - Adversarial Stress Suite: T8 NotificationService
# Author: Milestone 1 Challenger
# ==============================================================================
set -u
set +e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../harness/mock_environment.sh"
source "${SCRIPT_DIR}/../harness/qml_runner.sh"

HARNESS="${PROJECT_ROOT}/tests/e2e/harness/test_t8_notification_service_adversarial.qml"

test_case "T8.ADV.1" "Adversarial Stress Suite Execution"
if [[ -f "${HARNESS}" ]]; then
    run_qml_test_harness "${HARNESS}" "T8 NotificationService Adversarial Suite" 10
else
    test_fail "Adversarial harness file missing: ${HARNESS}"
fi

report_summary
