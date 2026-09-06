#!/usr/bin/env bash
# ==============================================================================
# Tier 1 - Feature 1: Desktop Design Tokens
# Source: ORIGINAL_REQUEST §R1, vision.md, PROJECT.md
# ==============================================================================
set -u
set +e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../harness/mock_environment.sh"
source "${SCRIPT_DIR}/../harness/qml_runner.sh"

THEME_FILE="${PROJECT_ROOT}/shell/desktop/core/Theme.qml"

test_case "T1.01.1" "Desktop Design Tokens: Theme.qml exists in desktop/core/"
assert_file_exists "${THEME_FILE}" "Theme.qml must exist in desktop/core"

test_case "T1.01.2" "Desktop Design Tokens: Near-black surface color token declared"
if [[ -f "${THEME_FILE}" ]]; then
    check_qml_property "${THEME_FILE}" "background" || \
    check_qml_property "${THEME_FILE}" "surfaceBackground" || \
    assert_grep -i "(background|surface|#0D0F12|#0E0E0E|#14171C)" "${THEME_FILE}" "Near-black background token must be declared"
else
    assert_file_exists "${THEME_FILE}"
fi

test_case "T1.01.3" "Desktop Design Tokens: Acid green accent token #1BFD9C declared"
if [[ -f "${THEME_FILE}" ]]; then
    assert_grep -i "(#1BFD9C|accentGreen|acidGreen)" "${THEME_FILE}" "Acid green accent #1BFD9C must be defined"
else
    assert_file_exists "${THEME_FILE}"
fi

test_case "T1.01.4" "Desktop Design Tokens: Monospace typography font token declared"
if [[ -f "${THEME_FILE}" ]]; then
    check_qml_property "${THEME_FILE}" "fontFamily" || \
    assert_grep -i "(monospace|JetBrainsMono|monoFont)" "${THEME_FILE}" "Monospace font family token must be defined"
else
    assert_file_exists "${THEME_FILE}"
fi

test_case "T1.01.5" "Desktop Design Tokens: Zero greeter imports or dependencies"
if [[ -f "${THEME_FILE}" ]]; then
    assert_not_grep "import.*greeter" "${THEME_FILE}" "Theme.qml must never import greeter"
else
    assert_file_exists "${THEME_FILE}"
fi

report_summary
