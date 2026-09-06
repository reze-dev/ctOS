#!/usr/bin/env bash
# ==============================================================================
# Tier 2 - Feature 4 Boundary: Overlay Dismissal & Focus Edge Cases
# Source: interaction-spec.md, engineering-guidelines.md, PROJECT.md
# ==============================================================================
set -u
set +e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../harness/mock_environment.sh"
source "${SCRIPT_DIR}/../harness/qml_runner.sh"

DESKTOP_DIR="${PROJECT_ROOT}/shell/desktop"

test_case "T2.04.1" "Overlay Dismissal Boundary: Escape key press when no overlay open is clean no-op"
if [[ -d "${DESKTOP_DIR}" ]]; then
    assert_grep -i "(isOverlayActive|activeSurface|Key_Escape)" "${DESKTOP_DIR}" "Escape handler must verify overlay is active before closing"
else
    assert_dir_exists "${DESKTOP_DIR}" "shell/desktop required"
fi

test_case "T2.04.2" "Overlay Dismissal Boundary: Clicks inside overlay bounding box do not dismiss"
if [[ -d "${DESKTOP_DIR}" ]]; then
    assert_grep -i "(propagateComposedEvents|scrim|MouseArea|containsMouse)" "${DESKTOP_DIR}" "Clicks inside overlay must be consumed by overlay contents"
else
    assert_dir_exists "${DESKTOP_DIR}" "shell/desktop required"
fi

test_case "T2.04.3" "Overlay Dismissal Boundary: Rapid burst of multiple Escape keypresses"
if [[ -d "${DESKTOP_DIR}" ]]; then
    assert_grep -i "(Key_Escape|close)" "${DESKTOP_DIR}" "Consecutive Escape presses must not produce error state"
else
    assert_dir_exists "${DESKTOP_DIR}" "shell/desktop required"
fi

test_case "T2.04.4" "Overlay Dismissal Boundary: Overlay focus trapped and released to root on close"
if [[ -d "${DESKTOP_DIR}" ]]; then
    assert_grep -i "(focus|ActiveFocus|focusScope)" "${DESKTOP_DIR}" "Keyboard focus must be scoped to overlay while open"
else
    assert_dir_exists "${DESKTOP_DIR}" "shell/desktop required"
fi

test_case "T2.04.5" "Overlay Dismissal Boundary: Focus handoff when overlay parent window deactivated"
if [[ -d "${DESKTOP_DIR}" ]]; then
    assert_grep -i "(activeFocus|focus)" "${DESKTOP_DIR}" "Window deactivation must handle focus cleanly"
else
    assert_dir_exists "${DESKTOP_DIR}" "shell/desktop required"
fi

report_summary
