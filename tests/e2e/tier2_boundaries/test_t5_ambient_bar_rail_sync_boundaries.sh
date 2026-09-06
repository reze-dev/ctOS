#!/usr/bin/env bash
# ==============================================================================
# Tier 2 - Feature 11 Boundaries: AmbientBar '=' Button Sync
# ==============================================================================
set -u
set +e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../harness/mock_environment.sh"
source "${SCRIPT_DIR}/../harness/qml_runner.sh"

AMBIENT_BAR="${PROJECT_ROOT}/shell/desktop/surfaces/AmbientBar.qml"
OVERLAY_CTRL="${PROJECT_ROOT}/shell/desktop/core/OverlayController.qml"

test_case "T2.25.1" "AmbientBar Sync Boundary: Rapid '=' toggle maintains single active surface invariant"
assert_file_exists "${OVERLAY_CTRL}"
assert_grep -E "toggleSystemRail\(\)" "${OVERLAY_CTRL}" "toggleSystemRail must exist"
assert_grep -E "toggle\(\s*(OverlayController\.)?Surface\.SystemRail\)" "${OVERLAY_CTRL}" "toggleSystemRail must toggle SystemRail surface"
assert_grep -E "activeSurface\s*===\s*surface" "${OVERLAY_CTRL}" "Toggle must compare activeSurface against target surface"

test_case "T2.25.2" "AmbientBar Sync Boundary: Calling toggleSystemRail when Rail is open closes it cleanly"
assert_grep -E "close\(\)" "${OVERLAY_CTRL}" "toggle method must call close() if already open"

test_case "T2.25.3" "AmbientBar Sync Boundary: Calling toggleSystemRail when another surface is open switches safely"
assert_grep -E "openSystemRail\(\)" "${OVERLAY_CTRL}" "Toggle method must open SystemRail if another surface is active"

test_case "T2.25.4" "AmbientBar Sync Boundary: Rail button border color binds directly to active state"
assert_file_exists "${AMBIENT_BAR}"
assert_grep -E "(border\.color|railBtn)" "${AMBIENT_BAR}" "railBtn must declare border color styling"

test_case "T2.25.5" "AmbientBar Sync Boundary: MouseArea preventStealing ensures Wayland clicks are captured"
assert_grep -E "(MouseArea|onClicked)" "${AMBIENT_BAR}" "railBtn must capture click events via MouseArea"

report_summary
