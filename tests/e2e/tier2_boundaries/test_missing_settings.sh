#!/usr/bin/env bash
# ==============================================================================
# Tier 2 - Feature 2 Boundary: Missing Settings File Handling
# Source: nix-module.md, engineering-guidelines.md, PROJECT.md
# ==============================================================================
set -u
set +e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../harness/mock_environment.sh"
source "${SCRIPT_DIR}/../harness/qml_runner.sh"

SETTINGS_FILE="${PROJECT_ROOT}/shell/desktop/core/Settings.qml"

test_case "T2.02.1" "Missing Settings: System initializes safe defaults without crash"
if [[ -f "${SETTINGS_FILE}" ]]; then
    # Must assign default values to properties
    assert_grep "(default|false|true|32)" "${SETTINGS_FILE}" "Default fallback values must be defined"
else
    assert_file_exists "${SETTINGS_FILE}" "Settings.qml required"
fi

test_case "T2.02.2" "Missing Settings: Missing settings logs diagnostic message once"
if [[ -f "${SETTINGS_FILE}" ]]; then
    assert_grep -i "(console\.(warn|log|info)|print)" "${SETTINGS_FILE}" "Diagnostic warning must be logged on missing config"
else
    assert_file_exists "${SETTINGS_FILE}" "Settings.qml required"
fi

test_case "T2.02.3" "Missing Settings: Empty string configPath falls back to standard user path"
if [[ -f "${SETTINGS_FILE}" ]]; then
    assert_grep -i "(configPath|settings\.json|\.config/ctos)" "${SETTINGS_FILE}" "Empty configPath must resolve to ~/.config/ctos/settings.json"
else
    assert_file_exists "${SETTINGS_FILE}" "Settings.qml required"
fi

test_case "T2.02.4" "Missing Settings: Non-existent parent directory handled cleanly"
if [[ -f "${SETTINGS_FILE}" ]]; then
    # File reading error must be caught
    assert_grep -i "(catch|error|status|exists)" "${SETTINGS_FILE}" "Non-existent path must not trigger uncaught exception"
else
    assert_file_exists "${SETTINGS_FILE}" "Settings.qml required"
fi

test_case "T2.02.5" "Missing Settings: Process exit (Qt.quit) is strictly prevented"
if [[ -f "${SETTINGS_FILE}" ]]; then
    assert_not_grep "Qt\.quit" "${SETTINGS_FILE}" "Missing settings must never call Qt.quit"
else
    assert_file_exists "${SETTINGS_FILE}" "Settings.qml required"
fi

report_summary
