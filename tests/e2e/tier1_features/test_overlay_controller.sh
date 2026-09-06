#!/usr/bin/env bash
# ==============================================================================
# Tier 1 - Feature 3: OverlayController
# Source: ORIGINAL_REQUEST §R1, architecture.md, PROJECT.md
# ==============================================================================
set -u
set +e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../harness/mock_environment.sh"
source "${SCRIPT_DIR}/../harness/qml_runner.sh"

OVERLAY_CTRL="${PROJECT_ROOT}/shell/desktop/core/OverlayController.qml"

test_case "T1.03.1" "OverlayController: File exists in desktop/core/"
assert_file_exists "${OVERLAY_CTRL}" "OverlayController.qml must exist in desktop/core"

test_case "T1.03.2" "OverlayController: Exposes activeSurface and isOverlayActive properties"
if [[ -f "${OVERLAY_CTRL}" ]]; then
    check_qml_property "${OVERLAY_CTRL}" "activeSurface" || \
    assert_grep "activeSurface" "${OVERLAY_CTRL}" "activeSurface property must be declared"
    check_qml_property "${OVERLAY_CTRL}" "isOverlayActive" || \
    assert_grep "isOverlayActive" "${OVERLAY_CTRL}" "isOverlayActive property must be declared"
else
    assert_file_exists "${OVERLAY_CTRL}"
fi

test_case "T1.03.3" "OverlayController: Exposes openCommandDeck() operation"
if [[ -f "${OVERLAY_CTRL}" ]]; then
    check_qml_method "${OVERLAY_CTRL}" "openCommandDeck" || \
    assert_grep "openCommandDeck" "${OVERLAY_CTRL}" "openCommandDeck method must be declared"
else
    assert_file_exists "${OVERLAY_CTRL}"
fi

test_case "T1.03.4" "OverlayController: Exposes openSystemRail() and openEventLog() operations"
if [[ -f "${OVERLAY_CTRL}" ]]; then
    check_qml_method "${OVERLAY_CTRL}" "openSystemRail" || \
    assert_grep "openSystemRail" "${OVERLAY_CTRL}" "openSystemRail method must be declared"
    check_qml_method "${OVERLAY_CTRL}" "openEventLog" || \
    assert_grep "openEventLog" "${OVERLAY_CTRL}" "openEventLog method must be declared"
else
    assert_file_exists "${OVERLAY_CTRL}"
fi

test_case "T1.03.5" "OverlayController: Exposes close() and overlayChanged signal"
if [[ -f "${OVERLAY_CTRL}" ]]; then
    check_qml_method "${OVERLAY_CTRL}" "close" || \
    assert_grep "close" "${OVERLAY_CTRL}" "close method must be declared"
    check_qml_signal "${OVERLAY_CTRL}" "overlayChanged" || \
    assert_grep "overlayChanged" "${OVERLAY_CTRL}" "overlayChanged signal must be declared"
else
    assert_file_exists "${OVERLAY_CTRL}"
fi

report_summary
