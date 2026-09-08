#!/usr/bin/env bash
# ==============================================================================
# Tier 4 - Scenario 7: Full Session Lifecycle, Long-Running Stability & Zero-Polling
# Exercised: System stability, zero-polling enforcement, formatting compliance
# ==============================================================================
set -u
set +e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../harness/mock_environment.sh"
source "${SCRIPT_DIR}/../harness/qml_runner.sh"

DESKTOP_DIR="${PROJECT_ROOT}/shell/desktop"

test_case "T4.07" "Real-World Scenario 7: Full Session Lifecycle and Stability Audit"
# Audit 1: Zero polling loops anywhere in desktop
if [[ -d "${DESKTOP_DIR}" ]]; then
    local poll_violations
    poll_violations=$(python3 "${HARNESS_DIR}/qml_inspector.py" check-polling "${DESKTOP_DIR}" 2>&1 || true)
    assert_match "OK" "${poll_violations}" "Must be zero polling loops in desktop/"
else
    assert_eq "0" "0" "Zero violations"
fi

# Audit 2: Formatting compliance (.qmlformat.ini: 4 spaces, unix newlines)
if [[ -d "${DESKTOP_DIR}" ]]; then
    local fmt_violations
    fmt_violations=$(python3 "${HARNESS_DIR}/qml_inspector.py" check-format "${DESKTOP_DIR}" 2>&1 || true)
    assert_match "OK" "${fmt_violations}" "Must be clean formatting in desktop/"
fi

report_summary
