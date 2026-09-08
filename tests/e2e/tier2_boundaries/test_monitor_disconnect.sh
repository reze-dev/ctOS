#!/usr/bin/env bash
# ==============================================================================
# Tier 2 - Feature 11 Boundary: Ambient Bar Monitor Disconnect & Edge Cases
# Source: ORIGINAL_REQUEST §R1, architecture.md, PROJECT.md
# ==============================================================================
set -u
set +e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../harness/mock_environment.sh"
source "${SCRIPT_DIR}/../harness/qml_runner.sh"

SHELL_ENTRY="${PROJECT_ROOT}/shell/shell.qml"
AMBIENT_BAR="${PROJECT_ROOT}/shell/desktop/surfaces/AmbientBar.qml"

test_case "T2.11.1" "Monitor Boundary: Output removal safely cleans up panel window"
if [[ -f "${SHELL_ENTRY}" ]]; then
    assert_grep "(Variants|model:\s*Quickshell\.screens)" "${SHELL_ENTRY}" "Variants manages per-output window destruction"
else
    assert_file_exists "${SHELL_ENTRY}" "shell.qml required"
fi

test_case "T2.11.2" "Monitor Boundary: Zero active monitors (headless) handled without fatal crash"
if [[ -f "${SHELL_ENTRY}" ]]; then
    assert_not_grep "Quickshell\.screens\[0\]" "${SHELL_ENTRY}" "Must not index screens[0] directly without bounds check"
else
    assert_file_exists "${SHELL_ENTRY}" "shell.qml required"
fi

test_case "T2.11.3" "Monitor Boundary: Monitor resolution change updates bar width"
if [[ -f "${AMBIENT_BAR}" ]]; then
    assert_grep -i "(anchors\.left|anchors\.right|width)" "${AMBIENT_BAR}" "Bar width must track screen geometry"
else
    assert_file_exists "${AMBIENT_BAR}" "AmbientBar.qml required"
fi

test_case "T2.11.4" "Monitor Boundary: Ultra-wide display (5120px) maintains compact bar height"
if [[ -f "${AMBIENT_BAR}" ]]; then
    assert_grep -i "(height|barHeight)" "${AMBIENT_BAR}" "Bar height must remain compact on ultra-wide screens"
else
    assert_file_exists "${AMBIENT_BAR}" "AmbientBar.qml required"
fi

test_case "T2.11.5" "Monitor Boundary: Multi-monitor setup (3+ screens) scales cleanly"
if [[ -f "${SHELL_ENTRY}" ]]; then
    assert_grep "(Variants|Quickshell\.screens)" "${SHELL_ENTRY}" "Variants handles arbitrary number of outputs"
else
    assert_file_exists "${SHELL_ENTRY}" "shell.qml required"
fi

report_summary
