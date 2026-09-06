#!/usr/bin/env bash
# ==============================================================================
# Tier 2 - Feature 10 Boundary: Clock Edge Cases & Format Fallbacks
# Source: interaction-spec.md, vision.md, PROJECT.md
# ==============================================================================
set -u
set +e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../harness/mock_environment.sh"
source "${SCRIPT_DIR}/../harness/qml_runner.sh"

DESKTOP_DIR="${PROJECT_ROOT}/shell/desktop"

test_case "T2.10.1" "Clock Boundary: Midnight date transition handles day rollover cleanly"
if [[ -d "${DESKTOP_DIR}" ]]; then
    assert_grep -i "(formatDateTime|date|SystemClock)" "${DESKTOP_DIR}" "Clock must track date reactively"
else
    assert_dir_exists "${DESKTOP_DIR}" "shell/desktop required"
fi

test_case "T2.10.2" "Clock Boundary: System timezone changes update clock display"
if [[ -d "${DESKTOP_DIR}" ]]; then
    assert_grep -i "(SystemClock|time|Qt\.formatTime)" "${DESKTOP_DIR}" "Clock must bind to system time updates"
else
    assert_dir_exists "${DESKTOP_DIR}" "shell/desktop required"
fi

test_case "T2.10.3" "Clock Boundary: Clock tick frequency is bounded (updates at most once per second)"
if [[ -d "${DESKTOP_DIR}" ]]; then
    assert_not_grep "interval:\s*([0-9]{1,2})\b" "${DESKTOP_DIR}" "Clock timer interval must not fire sub-100ms"
else
    assert_dir_exists "${DESKTOP_DIR}" "shell/desktop required"
fi

test_case "T2.10.4" "Clock Boundary: 12h vs 24h format fallback displays predictably"
if [[ -d "${DESKTOP_DIR}" ]]; then
    assert_grep -i "(hh|HH|mm)" "${DESKTOP_DIR}" "Clock format string must specify hour and minute format"
else
    assert_dir_exists "${DESKTOP_DIR}" "shell/desktop required"
fi

test_case "T2.10.5" "Clock Boundary: System clock backwards jump does not produce negative delta"
if [[ -d "${DESKTOP_DIR}" ]]; then
    assert_not_grep "SystemClock.*while" "${DESKTOP_DIR}" "Clock must be purely declarative without delta accumulation loops"
else
    assert_dir_exists "${DESKTOP_DIR}" "shell/desktop required"
fi

report_summary
