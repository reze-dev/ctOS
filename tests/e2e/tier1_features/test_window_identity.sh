#!/usr/bin/env bash
# ==============================================================================
# Tier 1 - Feature 6: Active Window Identity
# Source: ORIGINAL_REQUEST §R2, interaction-spec.md, PROJECT.md
# ==============================================================================
set -u
set +e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../harness/mock_environment.sh"
source "${SCRIPT_DIR}/../harness/qml_runner.sh"

DESKTOP_DIR="${PROJECT_ROOT}/shell/desktop"
WINDOW_TITLE_WIDGET="${DESKTOP_DIR}/surfaces/components/WindowTitleWidget.qml"
COMPOSITOR_SVC="${DESKTOP_DIR}/services/CompositorService.qml"

test_case "T1.06.1" "Active Window Identity: CompositorService exposes activeWindowTitle"
if [[ -f "${COMPOSITOR_SVC}" ]]; then
    check_qml_property "${COMPOSITOR_SVC}" "activeWindowTitle" || \
    assert_grep "activeWindowTitle" "${COMPOSITOR_SVC}" "activeWindowTitle must be declared on CompositorService"
else
    assert_file_exists "${COMPOSITOR_SVC}"
fi

test_case "T1.06.2" "Active Window Identity: Window title widget exists in surfaces/components/"
if [[ -f "${WINDOW_TITLE_WIDGET}" ]]; then
    assert_file_exists "${WINDOW_TITLE_WIDGET}"
else
    # Allow alternative component naming if matching window title
    local found
    found=$(find "${DESKTOP_DIR}/surfaces" -name "*Window*.qml" 2>/dev/null | head -n 1)
    if [[ -n "${found}" ]]; then
        assert_file_exists "${found}"
    else
        assert_file_exists "${WINDOW_TITLE_WIDGET}" "WindowTitleWidget.qml must exist in surfaces/components/"
    fi
fi

test_case "T1.06.3" "Active Window Identity: Widget binds reactively to active window state"
if [[ -d "${DESKTOP_DIR}" ]]; then
    assert_grep -i "(activeWindowTitle|focusedWindow|activeWindowAddress)" "${DESKTOP_DIR}" "Active window binding must be wired reactively"
else
    assert_dir_exists "${DESKTOP_DIR}"
fi

test_case "T1.06.4" "Active Window Identity: Graceful fallback when no window focused (no undefined string)"
if [[ -d "${DESKTOP_DIR}" ]]; then
    # Must guard against undefined or empty string
    assert_grep -i "(activeWindowTitle\s*!==\s*[\"'][\"']|\?\?|undefined|\"\"|empty)" "${DESKTOP_DIR}" "Empty window state must have graceful fallback"
else
    assert_dir_exists "${DESKTOP_DIR}"
fi

test_case "T1.06.5" "Active Window Identity: Text elision configured for compact space"
if [[ -d "${DESKTOP_DIR}" ]]; then
    assert_grep -i "(elide|ElideRight|clip|maximumLineCount)" "${DESKTOP_DIR}" "Window title text must be elided/truncated"
else
    assert_dir_exists "${DESKTOP_DIR}"
fi

report_summary
