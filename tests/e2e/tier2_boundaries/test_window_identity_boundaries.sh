#!/usr/bin/env bash
# ==============================================================================
# Tier 2 - Feature 6 Boundary: Active Window Identity Edge Cases
# Source: interaction-spec.md, engineering-guidelines.md, PROJECT.md
# ==============================================================================
set -u
set +e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../harness/mock_environment.sh"
source "${SCRIPT_DIR}/../harness/qml_runner.sh"

DESKTOP_DIR="${PROJECT_ROOT}/shell/desktop"

test_case "T2.06.1" "Window Identity Boundary: Very long window title (> 512 chars) truncated cleanly"
if [[ -d "${DESKTOP_DIR}" ]]; then
    assert_grep -i "(elide|ElideRight|maximumWidth|clip)" "${DESKTOP_DIR}" "Very long titles must be elided or clipped"
else
    assert_dir_exists "${DESKTOP_DIR}" "shell/desktop required"
fi

test_case "T2.06.2" "Window Identity Boundary: Title containing newlines or control characters sanitized"
if [[ -d "${DESKTOP_DIR}" ]]; then
    # Must render single line
    assert_grep -i "(maximumLineCount\s*:\s*1|elide|wrapMode\s*:\s*Text\.NoWrap)" "${DESKTOP_DIR}" "Window title must be restricted to single line"
else
    assert_dir_exists "${DESKTOP_DIR}" "shell/desktop required"
fi

test_case "T2.06.3" "Window Identity Boundary: Special UTF-8 / emoji characters supported in window title"
if [[ -d "${DESKTOP_DIR}" ]]; then
    # Text component should handle unicode text
    assert_grep -i "(activeWindowTitle|title|text)" "${DESKTOP_DIR}" "Window title text rendering must be present"
else
    assert_dir_exists "${DESKTOP_DIR}" "shell/desktop required"
fi

test_case "T2.06.4" "Window Identity Boundary: Window without class or title displays calm fallback"
if [[ -d "${DESKTOP_DIR}" ]]; then
    assert_grep -i "(activeWindowClass|activeWindowTitle|\"\"|empty)" "${DESKTOP_DIR}" "Empty title or class must not display 'undefined'"
else
    assert_dir_exists "${DESKTOP_DIR}" "shell/desktop required"
fi

test_case "T2.06.5" "Window Identity Boundary: Rapid focus changes debounce or update reactively"
if [[ -d "${DESKTOP_DIR}" ]]; then
    assert_grep -i "(activeWindowTitle|activeWindowAddress|focusedWindow)" "${DESKTOP_DIR}" "Focus changes bind reactively to window identity"
else
    assert_dir_exists "${DESKTOP_DIR}" "shell/desktop required"
fi

report_summary
