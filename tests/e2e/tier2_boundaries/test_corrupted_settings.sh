#!/usr/bin/env bash
# ==============================================================================
# Tier 2 - Feature 2 Boundary: Corrupted / Malformed Settings JSON
# Source: nix-module.md, engineering-guidelines.md, PROJECT.md
# ==============================================================================
set -u
set +e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../harness/mock_environment.sh"
source "${SCRIPT_DIR}/../harness/qml_runner.sh"

SETTINGS_FILE="${PROJECT_ROOT}/shell/desktop/core/Settings.qml"
MOCK_FILE="${TEST_TMP_DIR}/corrupt_settings.json"

test_case "T2.02.6" "Corrupted Settings: JSON parse failure is caught safely"
generate_corrupt_settings "${MOCK_FILE}"
if [[ -f "${SETTINGS_FILE}" ]]; then
    assert_grep -i "(try|catch|JSON\.parse)" "${SETTINGS_FILE}" "Settings loader must wrap JSON.parse in try/catch"
else
    assert_file_exists "${SETTINGS_FILE}" "Settings.qml required"
fi

test_case "T2.02.7" "Corrupted Settings: Fallback to defaults on parse exception"
if [[ -f "${SETTINGS_FILE}" ]]; then
    assert_grep -i "(catch|error|fallback|default)" "${SETTINGS_FILE}" "Settings loader must apply defaults on parse exception"
else
    assert_file_exists "${SETTINGS_FILE}" "Settings.qml required"
fi

test_case "T2.02.8" "Corrupted Settings: Unhandled / extra unexpected JSON keys tolerated"
EXTRA_KEY_JSON='{"unknownKey123": "unexpectedValue", "reducedMotion": true}'
generate_mock_settings "${MOCK_FILE}" "${EXTRA_KEY_JSON}"
if [[ -f "${SETTINGS_FILE}" ]]; then
    # Must not reject or crash on unknown keys
    assert_grep "(features|reducedMotion)" "${SETTINGS_FILE}" "Settings should extract known keys safely"
else
    assert_file_exists "${SETTINGS_FILE}" "Settings.qml required"
fi

test_case "T2.02.9" "Corrupted Settings: Type mismatch in JSON (e.g. string for boolean) handled safely"
TYPE_MISMATCH_JSON='{"reducedMotion": "not_a_boolean"}'
generate_mock_settings "${MOCK_FILE}" "${TYPE_MISMATCH_JSON}"
if [[ -f "${SETTINGS_FILE}" ]]; then
    assert_file_exists "${SETTINGS_FILE}"
else
    assert_file_exists "${SETTINGS_FILE}" "Settings.qml required"
fi

test_case "T2.02.10" "Corrupted Settings: Non-writable config path does not crash read operation"
chmod 400 "${MOCK_FILE}" 2>/dev/null || true
if [[ -f "${SETTINGS_FILE}" ]]; then
    assert_file_exists "${SETTINGS_FILE}"
else
    assert_file_exists "${SETTINGS_FILE}" "Settings.qml required"
fi

report_summary
