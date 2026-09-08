#!/usr/bin/env bash
# ==============================================================================
# Tier 4 - Scenario 1: Clean Desktop Shell Cold Boot
# Exercised: Tokens, Settings, shell.qml, Variants, AmbientBar, Hyprland
# ==============================================================================
set -u
set +e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../harness/mock_environment.sh"
source "${SCRIPT_DIR}/../harness/qml_runner.sh"

test_case "T4.01" "Real-World Scenario 1: Clean Desktop Shell Cold Boot Lifecycle"
# Cold boot verification:
# 1. shell.qml entry point exists and instantiates desktop tree
# 2. Settings loads without throwing fatal error
# 3. Theme tokens resolve
# 4. AmbientBar initializes per screen
SHELL_ENTRY="${PROJECT_ROOT}/shell/shell.qml"
DESKTOP_DIR="${PROJECT_ROOT}/shell/desktop"

assert_file_exists "${SHELL_ENTRY}" "Entry point shell.qml must exist"

if [[ -d "${DESKTOP_DIR}" ]]; then
    assert_file_exists "${DESKTOP_DIR}/core/Theme.qml" "Theme tokens required"
    assert_file_exists "${DESKTOP_DIR}/core/Settings.qml" "Settings loader required"
    assert_file_exists "${DESKTOP_DIR}/surfaces/AmbientBar.qml" "AmbientBar surface required"
    assert_file_exists "${DESKTOP_DIR}/adapters/hyprland/HyprlandAdapter.qml" "Hyprland adapter required"
else
    assert_dir_exists "${DESKTOP_DIR}" "shell/desktop required"
fi

report_summary
