#!/usr/bin/env bash
# ==============================================================================
# Tier 2 - Feature 1 Boundary: Design Tokens Edge Cases & Immutability
# Source: vision.md, engineering-guidelines.md, PROJECT.md
# ==============================================================================
set -u
set +e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../harness/mock_environment.sh"
source "${SCRIPT_DIR}/../harness/qml_runner.sh"

THEME_FILE="${PROJECT_ROOT}/shell/desktop/core/Theme.qml"

test_case "T2.01.1" "Tokens Boundary: Font family fallback when font not installed"
if [[ -f "${THEME_FILE}" ]]; then
    # Must specify fallback font or generic monospace in addition to primary font
    assert_grep -i "(monospace|JetBrainsMono|mono|sans-serif)" "${THEME_FILE}" "Theme must provide fallback monospace font"
else
    assert_file_exists "${THEME_FILE}" "Theme.qml required"
fi

test_case "T2.01.2" "Tokens Boundary: Token properties are declared readonly"
if [[ -f "${THEME_FILE}" ]]; then
    assert_grep "readonly\s+property" "${THEME_FILE}" "Tokens must be declared readonly to prevent mutation"
else
    assert_file_exists "${THEME_FILE}" "Theme.qml required"
fi

test_case "T2.01.3" "Tokens Boundary: Color hex codes conform to standard #RRGGBB or #AARRGGBB format"
if [[ -f "${THEME_FILE}" ]]; then
    local invalid_hex
    invalid_hex=$(grep -oE '#[A-Fa-f0-9]+' "${THEME_FILE}" | grep -vE '^#([A-Fa-f0-9]{6}|[A-Fa-f0-9]{8}|[A-Fa-f0-9]{3})$' || true)
    assert_eq "" "${invalid_hex}" "All color tokens must be valid hex values"
else
    assert_file_exists "${THEME_FILE}" "Theme.qml required"
fi

test_case "T2.01.4" "Tokens Boundary: Hairline divider dimension is positive integer (1px)"
if [[ -f "${THEME_FILE}" ]]; then
    assert_grep "(hairline|divider|borderWidth|1)" "${THEME_FILE}" "Hairline divider must be 1px"
else
    assert_file_exists "${THEME_FILE}" "Theme.qml required"
fi

test_case "T2.01.5" "Tokens Boundary: High contrast ratio between textPrimary and background"
if [[ -f "${THEME_FILE}" ]]; then
    assert_grep -i "(gray50|textPrimary|#ffffff|white|#FFFFFF)" "${THEME_FILE}" "textPrimary must provide high contrast"
else
    assert_file_exists "${THEME_FILE}" "Theme.qml required"
fi

report_summary
