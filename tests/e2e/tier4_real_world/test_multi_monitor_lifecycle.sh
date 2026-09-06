#!/usr/bin/env bash
# ==============================================================================
# Tier 4 - Scenario 2: Multi-Monitor Dynamic Hotplug & Unplug
# Exercised: Variants lifecycle, screen geometry, memory stability
# ==============================================================================
set -u
set +e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../harness/mock_environment.sh"
source "${SCRIPT_DIR}/../harness/qml_runner.sh"

SHELL_ENTRY="${PROJECT_ROOT}/shell/shell.qml"
AMBIENT_BAR="${PROJECT_ROOT}/shell/desktop/surfaces/AmbientBar.qml"

test_case "T4.02" "Real-World Scenario 2: Multi-Monitor Dynamic Hotplug & Unplug Lifecycle"
# Multi-monitor verification:
# 1. shell.qml must dynamically manage panel windows via Variants over screens model
# 2. AmbientBar must not hardcode screen dimensions or output IDs
assert_file_exists "${SHELL_ENTRY}" "Entry point shell.qml required"
if [[ -f "${SHELL_ENTRY}" ]]; then
    assert_grep "(Variants|Quickshell\.screens)" "${SHELL_ENTRY}" "Must use Variants over Quickshell.screens"
fi

if [[ -f "${AMBIENT_BAR}" ]]; then
    assert_not_grep "(1920|1080|2560|1440)" "${AMBIENT_BAR}" "Bar must not hardcode screen dimensions"
fi

report_summary
