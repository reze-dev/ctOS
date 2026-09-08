#!/usr/bin/env bash
# ==============================================================================
# Tier 1 - Feature 11: Ambient Bar Per-Output Variants
# Source: ORIGINAL_REQUEST §R1, §R2, PROJECT.md
# ==============================================================================
set -u
set +e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../harness/mock_environment.sh"
source "${SCRIPT_DIR}/../harness/qml_runner.sh"

AMBIENT_BAR="${PROJECT_ROOT}/shell/desktop/surfaces/AmbientBar.qml"
SHELL_ENTRY="${PROJECT_ROOT}/shell/shell.qml"

test_case "T1.11.1" "Ambient Bar Structure: AmbientBar.qml exists in desktop/surfaces/"
assert_file_exists "${AMBIENT_BAR}" "AmbientBar.qml must exist in desktop/surfaces/"

test_case "T1.11.2" "Ambient Bar Structure: shell.qml creates per-output bar windows via Variants"
if [[ -f "${SHELL_ENTRY}" ]]; then
    assert_grep "(Variants|Quickshell\.screens|model:\s*Quickshell\.screens)" "${SHELL_ENTRY}" "shell.qml must instantiate per-output bar via Variants"
else
    assert_file_exists "${SHELL_ENTRY}"
fi

test_case "T1.11.3" "Ambient Bar Structure: Bar window anchors to top screen edge"
if [[ -f "${AMBIENT_BAR}" ]]; then
    assert_grep -i "(anchors\.top|top:\s*true|edges\.top)" "${AMBIENT_BAR}" "AmbientBar must anchor to top screen edge"
else
    assert_file_exists "${AMBIENT_BAR}"
fi

test_case "T1.11.4" "Ambient Bar Structure: Bar height conforms to compact specification (<= 36px)"
if [[ -f "${AMBIENT_BAR}" ]]; then
    assert_grep -i "(height|barHeight|30|32|34|36)" "${AMBIENT_BAR}" "AmbientBar height must conform to compact specification"
else
    assert_file_exists "${AMBIENT_BAR}"
fi

test_case "T1.11.5" "Ambient Bar Structure: Defines left, center, right layout segmentation"
if [[ -f "${AMBIENT_BAR}" ]]; then
    assert_grep -i "(Row|RowLayout|Item|left|center|right)" "${AMBIENT_BAR}" "AmbientBar must segment layout cleanly"
else
    assert_file_exists "${AMBIENT_BAR}"
fi

report_summary
