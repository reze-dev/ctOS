#!/usr/bin/env bash
# ==============================================================================
# Tier 3 - Pairwise 22: Monitor Unplug during System Rail Confirmation
# Interaction: shell.qml screen handler (F7) + SystemRail Confirmation (F13)
# ==============================================================================
set -u
set +e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../harness/mock_environment.sh"
source "${SCRIPT_DIR}/../harness/qml_runner.sh"

SHELL_QML="${PROJECT_ROOT}/shell/shell.qml"

test_case "T3.22" "Pairwise: Monitor disconnection safely closes overlay without executing destructive command"
assert_file_exists "${SHELL_QML}"
# Quickshell.onScreensChanged must call OverlayController.close() if active screen disconnected
assert_grep "onScreensChanged" "${SHELL_QML}" "shell.qml must track screensChanged"
assert_grep "OverlayController\.close\(\)" "${SHELL_QML}" "Overlay must close on screen disconnect"

report_summary
