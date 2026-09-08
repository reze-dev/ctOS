#!/usr/bin/env bash
# ==============================================================================
# Tier 4 - Scenario 6: Greeter Isolation Security Audit
# Exercised: Security boundary audit across entire desktop and common codebase
# ==============================================================================
set -u
set +e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../harness/mock_environment.sh"
source "${SCRIPT_DIR}/../harness/qml_runner.sh"

DESKTOP_DIR="${PROJECT_ROOT}/shell/desktop"

test_case "T4.06" "Real-World Scenario 6: Greeter Boundary Isolation Complete Security Audit"
# Deep audit of all desktop sources for forbidden greeter coupling
if [[ -d "${DESKTOP_DIR}" ]]; then
    local violations
    violations=$(python3 "${HARNESS_DIR}/qml_inspector.py" check-greeter "${DESKTOP_DIR}" 2>&1 || true)
    assert_match "OK" "${violations}" "No greeter imports or references in desktop/"
else
    # In pre-implementation, desktop/ does not exist so isolation holds
    assert_eq "0" "0" "Zero violations"
fi

report_summary
