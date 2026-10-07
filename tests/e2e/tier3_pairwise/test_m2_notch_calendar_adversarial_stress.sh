#!/usr/bin/env bash
# ==============================================================================
# Tier 3 - Adversarial Stress & Pairwise Concurrency: Living Notch Calendar
# Source: ORIGINAL_REQUEST.md §R1 - §R5, PROJECT.md M2 & M5
# ==============================================================================
set -u
set +e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../harness/mock_environment.sh"
source "${SCRIPT_DIR}/../harness/qml_runner.sh"

HARNESS="${PROJECT_ROOT}/tests/e2e/harness/test_m2_notch_calendar_adversarial_stress.qml"

test_case "T3.LN.ADV.01" "Adversarial Runtime: Month Navigation, reducedMotion Physics & Pairwise Concurrency"
if [[ -f "${HARNESS}" ]]; then
    run_qml_test_harness "${HARNESS}" "M2 Notch Calendar Adversarial Stress Harness" 30
else
    test_skip "test_m2_notch_calendar_adversarial_stress.qml missing"
fi

report_summary
