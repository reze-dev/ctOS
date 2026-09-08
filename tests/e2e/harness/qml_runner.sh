#!/usr/bin/env bash
# ==============================================================================
# qml_runner.sh - QML Static and Runtime Execution Harness Helpers
# ==============================================================================
set -u

PROJECT_ROOT="${PROJECT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)}"
HARNESS_DIR="${PROJECT_ROOT}/tests/e2e/harness"
INSPECTOR="${HARNESS_DIR}/qml_inspector.py"

# Discover Quickshell binary
QUICKSHELL_BIN=""
if command -v qs >/dev/null 2>&1; then
    QUICKSHELL_BIN="$(command -v qs)"
elif command -v quickshell >/dev/null 2>&1; then
    QUICKSHELL_BIN="$(command -v quickshell)"
else
    for candidate in /nix/store/*quickshell*/bin/quickshell /nix/store/*quickshell*/bin/qs; do
        if [[ -x "${candidate}" ]]; then
            QUICKSHELL_BIN="${candidate}"
            break
        fi
    done
fi

# Discover qmllint / qmlformat binary
QMLLINT_BIN=""
QMLFORMAT_BIN=""
if command -v qmllint >/dev/null 2>&1; then
    QMLLINT_BIN="$(command -v qmllint)"
else
    for candidate in /nix/store/*qtdeclarative*/bin/qmllint; do
        if [[ -x "${candidate}" ]]; then
            QMLLINT_BIN="${candidate}"
            break
        fi
    done
fi

if command -v qmlformat >/dev/null 2>&1; then
    QMLFORMAT_BIN="$(command -v qmlformat)"
else
    for candidate in /nix/store/*qtdeclarative*/bin/qmlformat; do
        if [[ -x "${candidate}" ]]; then
            QMLFORMAT_BIN="${candidate}"
            break
        fi
    done
fi

# ------------------------------------------------------------------------------
# QML Contract Inspection Functions
# ------------------------------------------------------------------------------

check_qml_property() {
    local file_path="$1"
    local prop_name="$2"
    shift 2
    if ! python3 "${INSPECTOR}" has-property "${file_path}" "${prop_name}" "$@"; then
        CURRENT_TEST_FAILED=1
        CURRENT_TEST_REASON="Contract violation: property '${prop_name}' missing or invalid in ${file_path}"
        return 1
    fi
    return 0
}

check_qml_method() {
    local file_path="$1"
    local method_name="$2"
    if ! python3 "${INSPECTOR}" has-method "${file_path}" "${method_name}"; then
        CURRENT_TEST_FAILED=1
        CURRENT_TEST_REASON="Contract violation: method '${method_name}' missing in ${file_path}"
        return 1
    fi
    return 0
}

check_qml_signal() {
    local file_path="$1"
    local signal_name="$2"
    if ! python3 "${INSPECTOR}" has-signal "${file_path}" "${signal_name}"; then
        CURRENT_TEST_FAILED=1
        CURRENT_TEST_REASON="Contract violation: signal '${signal_name}' missing in ${file_path}"
        return 1
    fi
    return 0
}

check_no_greeter_imports() {
    local target_path="$1"
    if ! python3 "${INSPECTOR}" check-greeter "${target_path}"; then
        CURRENT_TEST_FAILED=1
        CURRENT_TEST_REASON="Greeter isolation violation in ${target_path}"
        return 1
    fi
    return 0
}

check_no_polling_loops() {
    local target_path="$1"
    if ! python3 "${INSPECTOR}" check-polling "${target_path}"; then
        CURRENT_TEST_FAILED=1
        CURRENT_TEST_REASON="Zero-polling policy violation in ${target_path}"
        return 1
    fi
    return 0
}

check_qml_format() {
    local target_path="$1"
    if ! python3 "${INSPECTOR}" check-format "${target_path}"; then
        CURRENT_TEST_FAILED=1
        CURRENT_TEST_REASON="QML formatting check failed for ${target_path}"
        return 1
    fi
    return 0
}

# ------------------------------------------------------------------------------
# Assertion Aliases (conforming to mock_environment.sh assert_* convention)
# ------------------------------------------------------------------------------
assert_qml_property() { check_qml_property "$@"; }
assert_qml_method()   { check_qml_method "$@"; }
assert_qml_signal()   { check_qml_signal "$@"; }

# ------------------------------------------------------------------------------
# QML Runtime Test Harness Execution
# ------------------------------------------------------------------------------
run_qml_test_harness() {
    local harness_path="$1"
    local desc="${2:-QML Runtime Harness}"
    local timeout_secs="${3:-8}"

    if [[ -z "${QUICKSHELL_BIN}" || ! -x "${QUICKSHELL_BIN}" ]]; then
        CURRENT_TEST_FAILED=1
        CURRENT_TEST_REASON="QUICKSHELL_BIN not found for ${desc}"
        echo "Error: QUICKSHELL_BIN not found for ${desc}"
        return 1
    fi

    local tmp_settings
    tmp_settings="$(mktemp /tmp/ctos_test_settings_XXXXXX.json)"

    local output
    output=$(CTOS_SETTINGS_PATH="${tmp_settings}" QML_IMPORT_PATH="${PROJECT_ROOT}/shell" timeout "${timeout_secs}" "${QUICKSHELL_BIN}" -p "${harness_path}" 2>&1)
    local ret=$?
    rm -f "${tmp_settings}"

    if [[ "${ret}" -ne 0 ]]; then
        CURRENT_TEST_FAILED=1
        CURRENT_TEST_REASON="Quickshell exited with code ${ret} for ${desc}"
        echo "${output}"
        return 1
    fi

    if echo "${output}" | grep -q "ASSERTION_FAILED"; then
        CURRENT_TEST_FAILED=1
        local reason
        reason=$(echo "${output}" | grep -m1 "ASSERTION_FAILED" | sed 's/.*ASSERTION_FAILED: //')
        CURRENT_TEST_REASON="QML Assertion Failed: ${reason}"
        echo "${output}"
        return 1
    fi

    if ! echo "${output}" | grep -qE "(PASS|SUCCESS)"; then
        CURRENT_TEST_FAILED=1
        CURRENT_TEST_REASON="QML harness did not output PASS/SUCCESS indicator for ${desc}"
        echo "${output}"
        return 1
    fi

    echo "${output}"
    return 0
}

# Run smoke execution of a QML file using Quickshell (if available) with timeout
run_qml_smoke() {
    local qml_path="$1"
    local timeout_secs="${2:-3}"

    if [[ -z "${QUICKSHELL_BIN}" ]]; then
        echo "Quickshell binary not found; skipping dynamic smoke"
        return 0
    fi

    # Launch with timeout and terminate
    timeout "${timeout_secs}" "${QUICKSHELL_BIN}" -p "${qml_path}" >/dev/null 2>&1 || {
        local exit_code=$?
        # Exit code 124 is timeout (which is expected for long-running UI)
        if [[ "${exit_code}" -eq 124 ]]; then
            return 0
        fi
        return "${exit_code}"
    }
    return 0
}
