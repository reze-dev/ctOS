#!/usr/bin/env bash
# ==============================================================================
# Tier 2 - Feature 2 Boundaries: Dynamic SVG Recoloring
# ==============================================================================
set -u
set +e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../harness/mock_environment.sh"
source "${SCRIPT_DIR}/../harness/qml_runner.sh"

THEME_FILE="${PROJECT_ROOT}/shell/desktop/core/Theme.qml"
ICON_ROUTER="${PROJECT_ROOT}/shell/desktop/surfaces/components/CtosIcon.qml"

test_case "T2.16.1" "Dynamic Recoloring Boundary: Acid green #1BFD9C matches uppercase hex format"
assert_file_exists "${THEME_FILE}"
assert_grep 'acidGreen:\s*"#1BFD9C"' "${THEME_FILE}" "Hex code must match standard #1BFD9C format"

test_case "T2.16.2" "Dynamic Recoloring Boundary: Warning red #FC3E38 matches uppercase hex format"
assert_grep 'warningRed:\s*"#FC3E38"' "${THEME_FILE}" "Hex code must match standard #FC3E38 format"

test_case "T2.16.3" "Dynamic Recoloring Boundary: Destructive state overrides active state in icon router"
if [[ -f "${ICON_ROUTER}" ]]; then
    # When destructive is true, it should take precedence over active
    assert_grep -E '(destructive\s*\?\s*Theme\.destructive|\(destructive\))' "${ICON_ROUTER}" \
        "Destructive state must take precedence over active state"
else
    test_skip "Pending M1: CtosIcon color precedence pending M1"
fi

test_case "T2.16.4" "Dynamic Recoloring Boundary: Neutral fallback color conforms to textPrimary"
if [[ -f "${ICON_ROUTER}" ]]; then
    assert_grep -E '(Theme\.textPrimary|color:\s*Theme\.textPrimary)' "${ICON_ROUTER}" \
        "Neutral state must fall back to Theme.textPrimary"
else
    test_skip "Pending M1: Neutral color fallback pending M1"
fi

test_case "T2.16.5" "Dynamic Recoloring Boundary: Color tokens are declared readonly"
assert_grep -E 'readonly\s+property\s+color\s+acidGreen' "${THEME_FILE}" "acidGreen must be readonly"
assert_grep -E 'readonly\s+property\s+color\s+destructive' "${THEME_FILE}" "destructive must be readonly"
assert_grep -E 'readonly\s+property\s+color\s+textPrimary' "${THEME_FILE}" "textPrimary must be readonly"

report_summary
