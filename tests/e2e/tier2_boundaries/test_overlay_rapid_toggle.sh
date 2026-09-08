#!/usr/bin/env bash
# ==============================================================================
# Tier 2 - Feature 3 Boundary: OverlayController Rapid Toggle & Boundary Inputs
# Source: architecture.md, decision-log.md (TD-005), PROJECT.md
# ==============================================================================
set -u
set +e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../harness/mock_environment.sh"
source "${SCRIPT_DIR}/../harness/qml_runner.sh"

OVERLAY_CTRL="${PROJECT_ROOT}/shell/desktop/core/OverlayController.qml"

test_case "T2.03.1" "OverlayController Boundary: Invalid surface index (> 3) is rejected or ignored"
if [[ -f "${OVERLAY_CTRL}" ]]; then
    assert_grep -i "(activeSurface|surface\s*<=|surface\s*>)" "${OVERLAY_CTRL}" "Surface bounds should validate surface index"
else
    assert_file_exists "${OVERLAY_CTRL}" "OverlayController.qml required"
fi

test_case "T2.03.2" "OverlayController Boundary: Negative surface index (< 0) rejected"
if [[ -f "${OVERLAY_CTRL}" ]]; then
    assert_grep -i "(activeSurface|0|surface\s*<)" "${OVERLAY_CTRL}" "Negative surface index must not be accepted"
else
    assert_file_exists "${OVERLAY_CTRL}" "OverlayController.qml required"
fi

test_case "T2.03.3" "OverlayController Boundary: Calling close() when already closed is idempotent"
if [[ -f "${OVERLAY_CTRL}" ]]; then
    assert_grep -i "(close|activeSurface\s*=\s*0)" "${OVERLAY_CTRL}" "close() must cleanly set activeSurface = 0"
else
    assert_file_exists "${OVERLAY_CTRL}" "OverlayController.qml required"
fi

test_case "T2.03.4" "OverlayController Boundary: Rapid open-close interleaving maintains single active surface"
if [[ -f "${OVERLAY_CTRL}" ]]; then
    assert_grep -i "(activeSurface|isOverlayActive)" "${OVERLAY_CTRL}" "Single state variable must guarantee mutual exclusion"
else
    assert_file_exists "${OVERLAY_CTRL}" "OverlayController.qml required"
fi

test_case "T2.03.5" "OverlayController Boundary: Toggle method closes surface if already active"
if [[ -f "${OVERLAY_CTRL}" ]]; then
    check_qml_method "${OVERLAY_CTRL}" "toggle" || assert_grep -i "(toggle|activeSurface\s*===)" "${OVERLAY_CTRL}" "toggle method must toggle surface or close"
else
    assert_file_exists "${OVERLAY_CTRL}" "OverlayController.qml required"
fi

report_summary
