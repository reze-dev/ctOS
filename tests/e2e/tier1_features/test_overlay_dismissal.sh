#!/usr/bin/env bash
# ==============================================================================
# Tier 1 - Feature 4: Overlay Dismissal & Focus
# Source: ORIGINAL_REQUEST §R1, interaction-spec.md, PROJECT.md
# ==============================================================================
set -u
set +e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../harness/mock_environment.sh"
source "${SCRIPT_DIR}/../harness/qml_runner.sh"

DESKTOP_DIR="${PROJECT_ROOT}/shell/desktop"
OVERLAY_CTRL="${DESKTOP_DIR}/core/OverlayController.qml"
SHELL_ENTRY="${PROJECT_ROOT}/shell/shell.qml"

test_case "T1.04.1" "Overlay Dismissal: Escape key dismisses active primary overlay"
if [[ -d "${DESKTOP_DIR}" ]]; then
    assert_grep -i "(Key_Escape|escape|onEscapePressed)" "${DESKTOP_DIR}" "Escape key handler must be implemented for overlay dismissal"
else
    assert_dir_exists "${DESKTOP_DIR}"
fi

test_case "T1.04.2" "Overlay Dismissal: Background scrim click dismisses overlay"
if [[ -d "${DESKTOP_DIR}" ]]; then
    assert_grep -i "(scrim|backdrop|outside|onClicked.*close)" "${DESKTOP_DIR}" "Backdrop / outside-click dismissal must be implemented"
else
    assert_dir_exists "${DESKTOP_DIR}"
fi

test_case "T1.04.3" "Overlay Dismissal: Primary overlay mutual exclusion enforced"
if [[ -f "${OVERLAY_CTRL}" ]]; then
    # Opening one must close or override previous
    assert_grep "(activeSurface\s*=\s*|close\(\))" "${OVERLAY_CTRL}" "Mutual exclusion must update activeSurface atomically"
else
    assert_file_exists "${OVERLAY_CTRL}"
fi

test_case "T1.04.4" "Overlay Dismissal: Keyboard focus routed to active overlay on summon"
if [[ -d "${DESKTOP_DIR}" ]]; then
    assert_grep -i "(forceActiveFocus|focus\s*:\s*true|focusManager)" "${DESKTOP_DIR}" "Focus handoff must route focus to active overlay"
else
    assert_dir_exists "${DESKTOP_DIR}"
fi

test_case "T1.04.5" "Overlay Dismissal: Overlay close releases keyboard focus cleanly"
if [[ -d "${DESKTOP_DIR}" ]]; then
    assert_grep -i "(focus\s*:\s*false|close\(\)|isOverlayActive)" "${DESKTOP_DIR}" "Overlay close releases focus state"
else
    assert_dir_exists "${DESKTOP_DIR}"
fi

report_summary
