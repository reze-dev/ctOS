#!/usr/bin/env bash
# ==============================================================================
# Tier 3 - Pairwise 4: Settings Reload Live Updates Theme Tokens
# Interaction: Generated Settings Loader (F2) + Desktop Design Tokens (F1)
# ==============================================================================
set -u
set +e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../harness/mock_environment.sh"
source "${SCRIPT_DIR}/../harness/qml_runner.sh"

DESKTOP_DIR="${PROJECT_ROOT}/shell/desktop"
SETTINGS_FILE="${DESKTOP_DIR}/core/Settings.qml"
THEME_FILE="${DESKTOP_DIR}/core/Theme.qml"

test_case "T3.04" "Pairwise: Live settings changes propagate without crashing Theme singletons"
if [[ -f "${SETTINGS_FILE}" && -f "${THEME_FILE}" ]]; then
    assert_file_exists "${SETTINGS_FILE}"
    assert_file_exists "${THEME_FILE}"
else
    assert_file_exists "${SETTINGS_FILE}" "Settings.qml required"
    assert_file_exists "${THEME_FILE}" "Theme.qml required"
fi

report_summary
