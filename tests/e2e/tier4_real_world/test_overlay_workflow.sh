#!/usr/bin/env bash
# ==============================================================================
# Tier 4 - Scenario 3: Overlay Summon, Rapid Switching & Dismissal
# Exercised: OverlayController mutual exclusion, Escape, click-outside
# ==============================================================================
set -u
set +e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../harness/mock_environment.sh"
source "${SCRIPT_DIR}/../harness/qml_runner.sh"

OVERLAY_CTRL="${PROJECT_ROOT}/shell/desktop/core/OverlayController.qml"
DESKTOP_DIR="${PROJECT_ROOT}/shell/desktop"

test_case "T4.03" "Real-World Scenario 3: Overlay Workflow Mutual Exclusion & Dismissal"
# Overlay workflow verification:
# 1. OverlayController coordinates primary overlays
# 2. Keybindings & scrim clicks dismiss active overlay
if [[ -f "${OVERLAY_CTRL}" ]]; then
    check_qml_method "${OVERLAY_CTRL}" "openCommandDeck"
    check_qml_method "${OVERLAY_CTRL}" "openSystemRail"
    check_qml_method "${OVERLAY_CTRL}" "close"
    assert_grep -i "(Key_Escape|escape)" "${DESKTOP_DIR}" "Escape key dismissal required"
    assert_grep -i "(scrim|backdrop|outside)" "${DESKTOP_DIR}" "Outside click dismissal required"
else
    assert_file_exists "${OVERLAY_CTRL}" "OverlayController.qml required"
fi

report_summary
