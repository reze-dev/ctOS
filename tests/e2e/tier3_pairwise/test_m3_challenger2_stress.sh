#!/usr/bin/env bash
# ==============================================================================
# Tier 3 - Challenger 2: Milestone 3 AmbientBar & Living Notch Empirical Stress Suite
# ==============================================================================
set -u
set +e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../harness/mock_environment.sh"
source "${SCRIPT_DIR}/../harness/qml_runner.sh"

HARNESS="${PROJECT_ROOT}/tests/e2e/harness/test_m3_challenger2_stress.qml"

test_case "T3.CHAL.M3.2.01" "Adversarial Runtime: Rapid State Switching, Layer Shell & Notch Lifecycle Invariants"
if [[ -f "${HARNESS}" ]]; then
    run_qml_test_harness "${HARNESS}" "M3 Challenger 2 Stress Harness" 20
else
    test_skip "test_m3_challenger2_stress.qml missing"
fi

report_summary
