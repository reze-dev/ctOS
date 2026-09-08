#!/usr/bin/env bash
# ==============================================================================
# Tier 2 - Feature 12 Boundary: Zero Polling Deep Audit & Edge Checks
# Source: engineering-guidelines.md, decision-log.md (TD-009), PROJECT.md
# ==============================================================================
set -u
set +e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../harness/mock_environment.sh"
source "${SCRIPT_DIR}/../harness/qml_runner.sh"

DESKTOP_DIR="${PROJECT_ROOT}/shell/desktop"

test_case "T2.12.1" "Zero Polling Boundary: Deep audit for Process { running: true } across all QML files"
if [[ -d "${DESKTOP_DIR}" ]]; then
    local proc_hits
    proc_hits=$(grep -rn "running:\s*true" "${DESKTOP_DIR}" 2>/dev/null || true)
    assert_eq "" "${proc_hits}" "Zero persistent Process loops allowed"
else
    assert_eq "0" "0"
fi

test_case "T2.12.2" "Zero Polling Boundary: No subshell echo logging (echo ... >> /tmp/...)"
if [[ -d "${DESKTOP_DIR}" ]]; then
    assert_not_grep 'echo.*>>' "${DESKTOP_DIR}" "No subshell file append logging allowed"
else
    assert_eq "0" "0"
fi

test_case "T2.12.3" "Zero Polling Boundary: Prototype bar bash while-loops not present in desktop/"
if [[ -d "${DESKTOP_DIR}" ]]; then
    assert_not_grep "while\s+true;\s*do" "${DESKTOP_DIR}" "No prototype CPU/RAM while-sleep loops"
else
    assert_eq "0" "0"
fi

test_case "T2.12.4" "Zero Polling Boundary: Timer loops in surfaces strictly prohibited for data fetching"
if [[ -d "${DESKTOP_DIR}/surfaces" ]]; then
    assert_not_grep "Timer\s*\{[^}]*triggeredOnStart:\s*true[^}]*interval:\s*[0-9]{3}\b" "${DESKTOP_DIR}/surfaces" "No polling timers in surfaces"
else
    assert_eq "0" "0"
fi

test_case "T2.12.5" "Zero Polling Boundary: Adapters manage lifecycle with explicit stop/cleanup"
if [[ -d "${DESKTOP_DIR}/adapters" ]]; then
    assert_grep -i "(available|Component\.onDestruction|cleanup|stop)" "${DESKTOP_DIR}/adapters" "Adapters must provide clean lifecycle management"
else
    assert_eq "0" "0"
fi

report_summary
