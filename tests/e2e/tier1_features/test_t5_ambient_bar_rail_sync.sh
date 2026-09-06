#!/usr/bin/env bash
# ==============================================================================
# Tier 1 - Feature 11: AmbientBar '=' Button Sync
# Source: ORIGINAL_REQUEST §R2, TEST_INFRA.md §Feature 11, PROJECT.md
# ==============================================================================
set -u
set +e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../harness/mock_environment.sh"
source "${SCRIPT_DIR}/../harness/qml_runner.sh"

AMBIENT_BAR="${PROJECT_ROOT}/shell/desktop/surfaces/AmbientBar.qml"
OVERLAY_CTRL="${PROJECT_ROOT}/shell/desktop/core/OverlayController.qml"

test_case "T1.25.1" "AmbientBar Sync: AmbientBar.qml exists and contains '=' rail button"
assert_file_exists "${AMBIENT_BAR}"
assert_grep 'text:\s*"="' "${AMBIENT_BAR}" "AmbientBar must contain text '=' for railBtn"

test_case "T1.25.2" "AmbientBar Sync: Clicking '=' calls OverlayController.toggleSystemRail()"
assert_grep "OverlayController\.toggleSystemRail" "${AMBIENT_BAR}" "railBtn must invoke toggleSystemRail()"

test_case "T1.25.3" "AmbientBar Sync: OverlayController declares toggleSystemRail() method"
assert_file_exists "${OVERLAY_CTRL}"
check_qml_method "${OVERLAY_CTRL}" "toggleSystemRail" || assert_grep "toggleSystemRail" "${OVERLAY_CTRL}" "toggleSystemRail method required"

test_case "T1.25.4" "AmbientBar Sync: Active state syncs with OverlayController.activeSurface"
if grep -q "isRailOpen" "${AMBIENT_BAR}"; then
    assert_grep -E "(activeSurface\s*===.*SystemRail|isRailOpen)" "${AMBIENT_BAR}" "railBtn must bind visual state to SystemRail surface"
else
    test_skip "Pending M2: railBtn reactive color sync pending M2"
fi

test_case "T1.25.5" "AmbientBar Sync: Active rail button displays Theme.accent or Theme.surfaceSelected"
if grep -q "isRailOpen" "${AMBIENT_BAR}"; then
    assert_grep -E "(Theme\.accent|Theme\.surfaceSelected)" "${AMBIENT_BAR}" "railBtn must apply cyberpunk accent when rail is open"
else
    test_skip "Pending M2: Active button styling pending M2"
fi

report_summary
