#!/usr/bin/env bash
# ==============================================================================
# Tier 1 - Feature: T8 Challenger M5 Ultimate Adversarial Stress Suite
# Source: DISPATCH.md, ORIGINAL_REQUEST, PROJECT.md M5
# ==============================================================================
set -u
set +e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../harness/mock_environment.sh"
source "${SCRIPT_DIR}/../harness/qml_runner.sh"

HARNESS="${HARNESS_DIR}/test_t8_challenger_m5_stress.qml"

test_case "T8.CHALLENGE.1" "Challenger M5 Adversarial Stress Harness Exists"
assert_file_exists "${HARNESS}" "Harness file must exist"

test_case "T8.CHALLENGE.2" "Challenger M5 Adversarial Stress Execution"
if [[ -f "${HARNESS}" ]]; then
    tmp_settings="$(mktemp /tmp/ctos_test_settings_XXXXXX.json)"
    output=$(CTOS_SETTINGS_PATH="${tmp_settings}" QML_IMPORT_PATH="${PROJECT_ROOT}/shell" timeout 10 "${QUICKSHELL_BIN}" -p "${HARNESS}" 2>&1)
    ret=$?
    rm -f "${tmp_settings}"
    echo "${output}"

    if [[ "${ret}" -ne 0 ]]; then
        CURRENT_TEST_FAILED=1
        CURRENT_TEST_REASON="Quickshell exited with code ${ret}"
    elif echo "${output}" | grep -q "CHALLENGER_FAIL"; then
        CURRENT_TEST_FAILED=1
        CURRENT_TEST_REASON="Empirical Challenger detected defects in adversarial stress run"
    elif ! echo "${output}" | grep -q "CHALLENGER_M5_FINAL_VERDICT: ALL SUITES PASSED"; then
        CURRENT_TEST_FAILED=1
        CURRENT_TEST_REASON="Challenger M5 did not approve final verdict"
    fi
else
    test_skip "Harness missing"
fi

report_summary
