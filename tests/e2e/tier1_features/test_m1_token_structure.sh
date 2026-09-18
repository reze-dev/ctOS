#!/usr/bin/env bash
# ==============================================================================
# Tier 1 - Milestone 1: Token Structure, Bar Height & Legacy Cleanup
# Source: ORIGINAL_REQUEST §R1, §R2, §R8, PROJECT.md
# ==============================================================================
set -u
set +e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../harness/mock_environment.sh"
source "${SCRIPT_DIR}/../harness/qml_runner.sh"

THEME_FILE="${PROJECT_ROOT}/shell/desktop/core/Theme.qml"
LEGACY_BAR_QML="${PROJECT_ROOT}/shell/bar.qml"
LEGACY_BAR_DIR="${PROJECT_ROOT}/shell/bar"

test_case "T1.M1.1" "Theme: fontFamily token is Maple Mono"
assert_file_exists "${THEME_FILE}"
assert_grep 'readonly property string fontFamily: "Maple Mono"' "${THEME_FILE}" \
    "Theme.fontFamily must be 'Maple Mono'"

test_case "T1.M1.2" "Theme: fontFamilyMonospace token is Maple Mono"
assert_grep 'readonly property string fontFamilyMonospace: "Maple Mono"' "${THEME_FILE}" \
    "Theme.fontFamilyMonospace must be 'Maple Mono'"

test_case "T1.M1.3" "Theme: fontFamilies array starts with Maple Mono"
assert_grep 'readonly property var fontFamilies: \["Maple Mono"' "${THEME_FILE}" \
    "Theme.fontFamilies array must prioritize Maple Mono"

test_case "T1.M1.4" "Theme: barHeight token is 36 or 40"
assert_grep 'readonly property int barHeight: (36|40)' "${THEME_FILE}" \
    "Theme.barHeight must be 36 or 40"

test_case "T1.M1.5" "Legacy Cleanup: shell/bar.qml is deleted"
assert_file_not_exists "${LEGACY_BAR_QML}" "Legacy file shell/bar.qml must be deleted"

test_case "T1.M1.6" "Legacy Cleanup: shell/bar/ directory is deleted"
assert_file_not_exists "${LEGACY_BAR_DIR}" "Legacy directory shell/bar/ must be deleted"

test_case "T1.M1.7" "Runtime: Milestone 1 Challenger Verification QML harness"
run_qml_test_harness "${PROJECT_ROOT}/tests/e2e/harness/test_m1_challenger_verification.qml" "M1 Challenger Verification" 5

test_case "T1.M1.8" "Runtime: Milestone 1 Adversarial Stress QML harness"
run_qml_test_harness "${PROJECT_ROOT}/tests/e2e/harness/test_m1_adversarial_stress.qml" "M1 Adversarial Stress" 5

report_summary
