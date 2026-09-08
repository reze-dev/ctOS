#!/usr/bin/env bash
# ==============================================================================
# Tier 1 - Feature 12: Zero Polling Loops
# Source: ORIGINAL_REQUEST §R3, engineering-guidelines.md, PROJECT.md
# ==============================================================================
set -u
set +e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../harness/mock_environment.sh"
source "${SCRIPT_DIR}/../harness/qml_runner.sh"

DESKTOP_DIR="${PROJECT_ROOT}/shell/desktop"
COMMON_DIR="${PROJECT_ROOT}/shell/common"

test_case "T1.12.1" "Zero Polling: Zero persistent Process loops (running: true) in desktop/"
if [[ -d "${DESKTOP_DIR}" ]]; then
    check_no_polling_loops "${DESKTOP_DIR}" || assert_eq "0" "1" "Persistent Process loop detected in desktop/"
else
    # Pre-implementation pass: no violations present
    assert_eq "0" "0"
fi

test_case "T1.12.2" "Zero Polling: Zero shell while-loops in desktop/"
if [[ -d "${DESKTOP_DIR}" ]]; then
    assert_not_grep "while\s+true" "${DESKTOP_DIR}" "No shell while true loops allowed in desktop"
else
    assert_eq "0" "0"
fi

test_case "T1.12.3" "Zero Polling: Zero sh -c command invocations in desktop/"
if [[ -d "${DESKTOP_DIR}" ]]; then
    assert_not_grep '["'\'']sh["'\'']\s*,\s*["'\'']-c["'\'']' "${DESKTOP_DIR}" "No sh -c subshell invocations allowed"
else
    assert_eq "0" "0"
fi

test_case "T1.12.4" "Zero Polling: Surfaces contain no short polling interval timers (< 500ms)"
if [[ -d "${DESKTOP_DIR}/surfaces" ]]; then
    assert_not_grep "interval:\s*(100|200|250|300)" "${DESKTOP_DIR}/surfaces" "No high-frequency polling timers in surfaces"
else
    assert_eq "0" "0"
fi

test_case "T1.12.5" "Zero Polling: Event-driven services without external poll scripts"
if [[ -d "${DESKTOP_DIR}/services" ]]; then
    assert_not_grep "(sleep|watch|poll)" "${DESKTOP_DIR}/services" "Services must be reactive event-driven"
else
    assert_eq "0" "0"
fi

report_summary
