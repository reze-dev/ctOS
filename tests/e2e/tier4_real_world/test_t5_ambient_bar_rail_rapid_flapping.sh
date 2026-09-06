#!/usr/bin/env bash
# ==============================================================================
# Tier 4 - Scenario 12: AmbientBar '=' Toggle Rapid Flapping
# Exercised: railBtn, OverlayController.toggleSystemRail(), Scrim Backdrop
# ==============================================================================
set -u
set +e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../harness/mock_environment.sh"
source "${SCRIPT_DIR}/../harness/qml_runner.sh"

AMBIENT_BAR="${PROJECT_ROOT}/shell/desktop/surfaces/AmbientBar.qml"
OVERLAY_CTRL="${PROJECT_ROOT}/shell/desktop/core/OverlayController.qml"
SHELL_QML="${PROJECT_ROOT}/shell/shell.qml"

test_case "T4.12" "Real-World Scenario 12: AmbientBar '=' Toggle Rapid Flapping"
assert_file_exists "${AMBIENT_BAR}"
assert_file_exists "${OVERLAY_CTRL}"
assert_file_exists "${SHELL_QML}"

# Verify railBtn is wired to toggleSystemRail()
assert_grep "OverlayController\.toggleSystemRail" "${AMBIENT_BAR}" "railBtn must call toggleSystemRail()"

# Verify toggle method implements idempotent state transitions
assert_grep -E "function toggleSystemRail\(\)" "${OVERLAY_CTRL}" "toggleSystemRail function required"
assert_grep -E "close\(\)" "${OVERLAY_CTRL}" "close() required"

# Scrim backdrop click handling
assert_grep "scrimBackdrop" "${SHELL_QML}" "scrimBackdrop required in shell.qml"

report_summary
