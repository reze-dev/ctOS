#!/usr/bin/env bash
# ==============================================================================
# Challenger M5-3: Boundary, Interleaved Interaction & Adversarial Stress Suite
# Covers: Outside backdrop clicks, rapid calendar toggles, volume clamping [0.0, 1.0],
# auto-unmute, reduced motion mode toggles, long media titles, text elision,
# and dynamic workspaces (1 to 10).
# ==============================================================================
set -u
set +e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../harness/mock_environment.sh"
source "${SCRIPT_DIR}/../harness/qml_runner.sh"

HARNESS_QML="${PROJECT_ROOT}/tests/e2e/harness/test_m5_challenger3_stress.qml"

test_case "CHAL.M5.3.RUN" "Empirical Challenger 3 Adversarial Stress Harness Execution"
if [[ -f "${HARNESS_QML}" ]]; then
    export CTOS_SESSION_DRY_RUN=1
    QT_QPA_PLATFORM=offscreen run_qml_test_harness "${HARNESS_QML}" "Challenger M5-3 Stress Harness" 15
else
    test_skip "test_m5_challenger3_stress.qml missing"
fi

report_summary
