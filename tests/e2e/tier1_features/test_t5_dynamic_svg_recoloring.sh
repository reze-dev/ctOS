#!/usr/bin/env bash
# ==============================================================================
# Tier 1 - Feature 2: Dynamic SVG Recoloring
# Source: ORIGINAL_REQUEST §R1.1, TEST_INFRA.md §Feature 2, PROJECT.md
# ==============================================================================
set -u
set +e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../harness/mock_environment.sh"
source "${SCRIPT_DIR}/../harness/qml_runner.sh"

THEME_FILE="${PROJECT_ROOT}/shell/desktop/core/Theme.qml"
ICON_ROUTER="${PROJECT_ROOT}/shell/desktop/surfaces/components/CtosIcon.qml"

test_case "T1.16.1" "Dynamic SVG Recoloring: Theme.acidGreen is strictly #1BFD9C"
assert_file_exists "${THEME_FILE}" "Theme.qml must exist"
assert_grep 'acidGreen:\s*"#1BFD9C"' "${THEME_FILE}" "Theme.acidGreen must be #1BFD9C"

test_case "T1.16.2" "Dynamic SVG Recoloring: Theme.textPrimary is neutral white (#FFFFFF / gray50)"
assert_grep -E '(textPrimary:\s*(root\.)?gray50|textPrimary:\s*"#FFFFFF")' "${THEME_FILE}" "Theme.textPrimary must resolve to neutral white"

test_case "T1.16.3" "Dynamic SVG Recoloring: Theme.destructive is critical red #FC3E38"
assert_grep -E '(destructive:\s*(root\.)?warningRed|destructive:\s*"#FC3E38")' "${THEME_FILE}" "Theme.destructive must resolve to warning red"
assert_grep 'warningRed:\s*"#FC3E38"' "${THEME_FILE}" "Theme.warningRed must be #FC3E38"

test_case "T1.16.4" "Dynamic SVG Recoloring: Active state maps to acidGreen accent"
if [[ -f "${ICON_ROUTER}" ]]; then
    assert_grep -E '(active.*Theme\.acidGreen|active.*Theme\.accent)' "${ICON_ROUTER}" "Active state in CtosIcon must map to acidGreen"
else
    # Verify theme active token exists
    assert_grep -E '(active:\s*(root\.)?acidGreen|active:\s*"#1BFD9C")' "${THEME_FILE}" "Theme.active must map to acidGreen"
fi

test_case "T1.16.5" "Dynamic SVG Recoloring: Destructive / warning state maps to Theme.destructive"
if [[ -f "${ICON_ROUTER}" ]]; then
    assert_grep -E '(destructive.*Theme\.destructive|destructive.*Theme\.warningRed)' "${ICON_ROUTER}" "Destructive state in CtosIcon must map to Theme.destructive"
else
    # Verify Theme.destructive is declared readonly
    assert_grep -E 'readonly\s+property\s+color\s+destructive' "${THEME_FILE}" "Theme.destructive must be declared as a color token"
fi

report_summary
