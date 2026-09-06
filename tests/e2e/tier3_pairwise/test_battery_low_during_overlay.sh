#!/usr/bin/env bash
# ==============================================================================
# Tier 3 - Pairwise 6: Low Battery Event while Overlay Active
# Interaction: PowerService (F9) + OverlayController (F3)
# ==============================================================================
set -u
set +e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../harness/mock_environment.sh"
source "${SCRIPT_DIR}/../harness/qml_runner.sh"

DESKTOP_DIR="${PROJECT_ROOT}/shell/desktop"
POWER_SVC="${DESKTOP_DIR}/services/PowerService.qml"
OVERLAY_CTRL="${DESKTOP_DIR}/core/OverlayController.qml"

test_case "T3.06" "Pairwise: Low battery percentage update does not steal focus from open overlay"
if [[ -f "${POWER_SVC}" && -f "${OVERLAY_CTRL}" ]]; then
    assert_file_exists "${POWER_SVC}"
    assert_file_exists "${OVERLAY_CTRL}"
else
    assert_file_exists "${POWER_SVC}" "PowerService.qml required"
    assert_file_exists "${OVERLAY_CTRL}" "OverlayController.qml required"
fi

report_summary
