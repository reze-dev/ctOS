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
    python3 "${INSPECTOR}" has-property "${file_path}" "${prop_name}" "$@"
}

check_qml_method() {
    local file_path="$1"
    local method_name="$2"
    python3 "${INSPECTOR}" has-method "${file_path}" "${method_name}"
}

check_qml_signal() {
    local file_path="$1"
    local signal_name="$2"
    python3 "${INSPECTOR}" has-signal "${file_path}" "${signal_name}"
}

check_no_greeter_imports() {
    local target_path="$1"
    python3 "${INSPECTOR}" check-greeter "${target_path}"
}

check_no_polling_loops() {
    local target_path="$1"
    python3 "${INSPECTOR}" check-polling "${target_path}"
}

check_qml_format() {
    local target_path="$1"
    python3 "${INSPECTOR}" check-format "${target_path}"
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
