#!/usr/bin/env bash
# ==============================================================================
# Tier 1 - Feature 2: Generated Settings Loader
# Source: ORIGINAL_REQUEST §R1, nix-module.md, PROJECT.md
# ==============================================================================
set -u
set +e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../harness/mock_environment.sh"
source "${SCRIPT_DIR}/../harness/qml_runner.sh"

SETTINGS_FILE="${PROJECT_ROOT}/shell/desktop/core/Settings.qml"

test_case "T1.02.1" "Generated Settings: Settings.qml exists in desktop/core/"
assert_file_exists "${SETTINGS_FILE}" "Settings.qml must exist in desktop/core"

test_case "T1.02.2" "Generated Settings: Config path is configurable without hardcoded /etc/ctos"
if [[ -f "${SETTINGS_FILE}" ]]; then
    check_qml_property "${SETTINGS_FILE}" "configPath" || \
    assert_grep -i "(configPath|settingsPath|settings\.json)" "${SETTINGS_FILE}" "Settings must expose configurable path"
    assert_not_grep "/etc/ctos/settings" "${SETTINGS_FILE}" "Settings must not hardcode /etc/ctos for desktop features"
else
    assert_file_exists "${SETTINGS_FILE}"
fi

test_case "T1.02.3" "Generated Settings: Feature flag toggles declared"
if [[ -f "${SETTINGS_FILE}" ]]; then
    assert_grep -i "(commandDeck|features|featuresCommandDeck)" "${SETTINGS_FILE}" "Features flags must be declared"
else
    assert_file_exists "${SETTINGS_FILE}"
fi

test_case "T1.02.4" "Generated Settings: reducedMotion toggle property declared"
if [[ -f "${SETTINGS_FILE}" ]]; then
    check_qml_property "${SETTINGS_FILE}" "reducedMotion" --type bool || \
    assert_grep -i "reducedMotion" "${SETTINGS_FILE}" "reducedMotion boolean property must be declared"
else
    assert_file_exists "${SETTINGS_FILE}"
fi

test_case "T1.02.5" "Generated Settings: Safe fallback logic without calling Qt.quit()"
if [[ -f "${SETTINGS_FILE}" ]]; then
    assert_not_grep "Qt\.quit\(\)" "${SETTINGS_FILE}" "Settings must never call Qt.quit() on missing configuration"
else
    assert_file_exists "${SETTINGS_FILE}"
fi

report_summary
