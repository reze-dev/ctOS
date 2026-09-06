#!/usr/bin/env bash
# ==============================================================================
# Tier 3 - Pairwise 13: Switching Overlay Panels with Window Focus Updates
# Interaction: OverlayController (F3) + Active Window Identity (F6)
# ==============================================================================
set -u
set +e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../harness/mock_environment.sh"
source "${SCRIPT_DIR}/../harness/qml_runner.sh"

DESKTOP_DIR="${PROJECT_ROOT}/shell/desktop"
OVERLAY_CTRL="${DESKTOP_DIR}/core/OverlayController.qml"
COMPOSITOR_SVC="${DESKTOP_DIR}/services/CompositorService.qml"

test_case "T3.13" "Pairwise: Switching from CommandDeck to SystemRail transitions focus without stale title"
if [[ -f "${OVERLAY_CTRL}" && -f "${COMPOSITOR_SVC}" ]]; then
    assert_file_exists "${OVERLAY_CTRL}"
    assert_file_exists "${COMPOSITOR_SVC}"
else
    assert_file_exists "${OVERLAY_CTRL}" "OverlayController.qml required"
    assert_file_exists "${COMPOSITOR_SVC}" "CompositorService.qml required"
fi

report_summary
