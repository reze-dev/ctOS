#!/usr/bin/env bash
# ==============================================================================
# mock_environment.sh - E2E Test Mock Environment and Assertions Library
# ==============================================================================
set -u
set +e

# Ensure project root is known
PROJECT_ROOT="${PROJECT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)}"
HARNESS_DIR="${PROJECT_ROOT}/tests/e2e/harness"

# Colors
COLOR_RESET="\033[0m"
COLOR_BOLD="\033[1m"
COLOR_GREEN="\033[0;32m"
COLOR_RED="\033[0;31m"
COLOR_YELLOW="\033[0;33m"
COLOR_CYAN="\033[0;36m"
COLOR_GRAY="\033[0;90m"

# State counters
CURRENT_TEST_ID=""
CURRENT_TEST_NAME=""
CURRENT_TEST_FAILED=0
CURRENT_TEST_REASON=""

TEST_COUNT_TOTAL=0
TEST_COUNT_PASS=0
TEST_COUNT_FAIL=0
TEST_COUNT_SKIP=0

VERBOSE="${VERBOSE:-0}"
JSON_REPORT_FILE="${JSON_REPORT_FILE:-}"

# Create isolated test scratch directory
TEST_TMP_DIR=$(mktemp -d "/tmp/ctos-e2e-XXXXXX")
cleanup_harness() {
    if [[ -d "${TEST_TMP_DIR}" ]]; then
        rm -rf "${TEST_TMP_DIR}"
    fi
}
trap cleanup_harness EXIT INT TERM

# ------------------------------------------------------------------------------
# Test Lifecycle Functions
# ------------------------------------------------------------------------------

test_case() {
    # If previous test didn't finalize, finalize it
    if [[ -n "${CURRENT_TEST_ID}" ]]; then
        finalize_test
    fi

    CURRENT_TEST_ID="$1"
    CURRENT_TEST_NAME="$2"
    CURRENT_TEST_FAILED=0
    CURRENT_TEST_REASON=""
    TEST_COUNT_TOTAL=$((TEST_COUNT_TOTAL + 1))

    if [[ "${VERBOSE}" -eq 1 ]]; then
        echo -e "${COLOR_GRAY}[RUN ] ${CURRENT_TEST_ID}: ${CURRENT_TEST_NAME}${COLOR_RESET}"
    fi
}

finalize_test() {
    if [[ -z "${CURRENT_TEST_ID}" ]]; then
        return
    fi

    if [[ "${CURRENT_TEST_FAILED}" -eq 0 ]]; then
        TEST_COUNT_PASS=$((TEST_COUNT_PASS + 1))
        echo -e "${COLOR_GREEN}[PASS]${COLOR_RESET} ${CURRENT_TEST_ID}: ${CURRENT_TEST_NAME}"
        record_json_result "${CURRENT_TEST_ID}" "${CURRENT_TEST_NAME}" "PASS" ""
    else
        TEST_COUNT_FAIL=$((TEST_COUNT_FAIL + 1))
        echo -e "${COLOR_RED}[FAIL]${COLOR_RESET} ${CURRENT_TEST_ID}: ${CURRENT_TEST_NAME}"
        if [[ -n "${CURRENT_TEST_REASON}" ]]; then
            echo -e "       ${COLOR_RED}Reason: ${CURRENT_TEST_REASON}${COLOR_RESET}"
        fi
        record_json_result "${CURRENT_TEST_ID}" "${CURRENT_TEST_NAME}" "FAIL" "${CURRENT_TEST_REASON}"
    fi

    CURRENT_TEST_ID=""
    CURRENT_TEST_NAME=""
}

test_skip() {
    local reason="${1:-Skipped}"
    CURRENT_TEST_FAILED=0
    TEST_COUNT_SKIP=$((TEST_COUNT_SKIP + 1))
    echo -e "${COLOR_YELLOW}[SKIP]${COLOR_RESET} ${CURRENT_TEST_ID}: ${CURRENT_TEST_NAME} (${reason})"
    record_json_result "${CURRENT_TEST_ID}" "${CURRENT_TEST_NAME}" "SKIP" "${reason}"
    CURRENT_TEST_ID=""
    CURRENT_TEST_NAME=""
}

# ------------------------------------------------------------------------------
# Assertion Functions
# ------------------------------------------------------------------------------

assert_eq() {
    local expected="$1"
    local actual="$2"
    local msg="${3:-Assertion failed}"

    if [[ "${expected}" != "${actual}" ]]; then
        CURRENT_TEST_FAILED=1
        CURRENT_TEST_REASON="${msg} (expected '${expected}', got '${actual}')"
        return 1
    fi
    return 0
}

assert_neq() {
    local unexpected="$1"
    local actual="$2"
    local msg="${3:-Assertion failed}"

    if [[ "${unexpected}" == "${actual}" ]]; then
        CURRENT_TEST_FAILED=1
        CURRENT_TEST_REASON="${msg} (expected value != '${unexpected}')"
        return 1
    fi
    return 0
}

assert_match() {
    local pattern="$1"
    local actual="$2"
    local msg="${3:-Regex match assertion failed}"

    if ! [[ "${actual}" =~ ${pattern} ]]; then
        CURRENT_TEST_FAILED=1
        CURRENT_TEST_REASON="${msg} (pattern '${pattern}' not found in '${actual}')"
        return 1
    fi
    return 0
}

assert_not_match() {
    local pattern="$1"
    local actual="$2"
    local msg="${3:-Negative regex match assertion failed}"

    if [[ "${actual}" =~ ${pattern} ]]; then
        CURRENT_TEST_FAILED=1
        CURRENT_TEST_REASON="${msg} (unexpected pattern '${pattern}' matched in '${actual}')"
        return 1
    fi
    return 0
}

assert_file_exists() {
    local file_path="$1"
    local msg="${2:-Required file does not exist}"

    if [[ ! -f "${file_path}" ]]; then
        CURRENT_TEST_FAILED=1
        CURRENT_TEST_REASON="${msg} (missing file: ${file_path})"
        return 1
    fi
    return 0
}

assert_file_not_exists() {
    local file_path="$1"
    local msg="${2:-Forbidden file exists}"

    if [[ -e "${file_path}" ]]; then
        CURRENT_TEST_FAILED=1
        CURRENT_TEST_REASON="${msg} (file should not exist: ${file_path})"
        return 1
    fi
    return 0
}

assert_dir_exists() {
    local dir_path="$1"
    local msg="${2:-Required directory does not exist}"

    if [[ ! -d "${dir_path}" ]]; then
        CURRENT_TEST_FAILED=1
        CURRENT_TEST_REASON="${msg} (missing directory: ${dir_path})"
        return 1
    fi
    return 0
}

assert_grep() {
    local flags=()
    while [[ "${1:-}" =~ ^-[a-zA-Z] ]]; do
        flags+=("$1")
        shift
    done
    local pattern="$1"
    local target_path="$2"
    local msg="${3:-Pattern not found in target}"

    if [[ ! -e "${target_path}" ]]; then
        CURRENT_TEST_FAILED=1
        CURRENT_TEST_REASON="${msg} (target not found: ${target_path})"
        return 1
    fi

    local grep_cmd=("grep" "-q" "-E")
    if [[ -d "${target_path}" ]]; then
        grep_cmd+=("-r")
    fi
    if [[ ${#flags[@]} -gt 0 ]]; then
        grep_cmd+=("${flags[@]}")
    fi

    if ! "${grep_cmd[@]}" "${pattern}" "${target_path}" 2>/dev/null; then
        CURRENT_TEST_FAILED=1
        CURRENT_TEST_REASON="${msg} (pattern '${pattern}' not found in ${target_path})"
        return 1
    fi
    return 0
}

assert_not_grep() {
    local flags=()
    while [[ "${1:-}" =~ ^-[a-zA-Z] ]]; do
        flags+=("$1")
        shift
    done
    local pattern="$1"
    local target_path="$2"
    local msg="${3:-Forbidden pattern found in target}"

    if [[ ! -e "${target_path}" ]]; then
        return 0
    fi

    local grep_cmd=("grep" "-q" "-E")
    if [[ -d "${target_path}" ]]; then
        grep_cmd+=("-r")
    fi
    if [[ ${#flags[@]} -gt 0 ]]; then
        grep_cmd+=("${flags[@]}")
    fi

    if "${grep_cmd[@]}" "${pattern}" "${target_path}" 2>/dev/null; then
        CURRENT_TEST_FAILED=1
        CURRENT_TEST_REASON="${msg} (forbidden pattern '${pattern}' matched in ${target_path})"
        return 1
    fi
    return 0
}

assert_exit_code() {
    local expected_code="$1"
    shift
    local cmd=("$@")

    set +e
    "${cmd[@]}" >/dev/null 2>&1
    local actual_code=$?
    set -u

    if [[ "${actual_code}" -ne "${expected_code}" ]]; then
        CURRENT_TEST_FAILED=1
        CURRENT_TEST_REASON="Command '${cmd[*]}' exited with ${actual_code}, expected ${expected_code}"
        return 1
    fi
    return 0
}

# ------------------------------------------------------------------------------
# Mock Data Generators
# ------------------------------------------------------------------------------

generate_mock_settings() {
    local target_path="$1"
    local extra_json="${2:-{}}"
    mkdir -p "$(dirname "${target_path}")"
    cat <<EOF > "${target_path}"
{
  "reducedMotion": false,
  "barHeight": 32,
  "features": {
    "commandDeck": true,
    "systemRail": true,
    "notifications": true
  },
  "theme": {
    "accentColor": "#1BFD9C",
    "fontFamily": "JetBrainsMono Nerd Font"
  }
}
EOF
    if [[ "${extra_json}" != "{}" ]]; then
        # Merge extra json if jq is available
        if command -v jq >/dev/null 2>&1; then
            local merged
            merged=$(jq -s '.[0] * .[1]' "${target_path}" <(echo "${extra_json}"))
            echo "${merged}" > "${target_path}"
        fi
    fi
}

generate_corrupt_settings() {
    local target_path="$1"
    mkdir -p "$(dirname "${target_path}")"
    echo "{ this is: not, valid json --- missing bracket " > "${target_path}"
}

# ------------------------------------------------------------------------------
# JSON Reporting
# ------------------------------------------------------------------------------

record_json_result() {
    local test_id="$1"
    local test_name="$2"
    local status="$3"
    local reason="$4"

    if [[ -n "${JSON_REPORT_FILE}" ]]; then
        local entry
        entry=$(python3 -c "
import json, sys
data = {
    'id': sys.argv[1],
    'name': sys.argv[2],
    'status': sys.argv[3],
    'reason': sys.argv[4]
}
print(json.dumps(data))
" "${test_id}" "${test_name}" "${status}" "${reason}")
        echo "${entry}" >> "${TEST_TMP_DIR}/results.jsonl"
    fi
}

report_summary() {
    # Finalize any pending test
    if [[ -n "${CURRENT_TEST_ID}" ]]; then
        finalize_test
    fi

    echo ""
    echo -e "${COLOR_BOLD}======================================================${COLOR_RESET}"
    echo -e "${COLOR_BOLD}Test Execution Summary${COLOR_RESET}"
    echo -e "${COLOR_BOLD}======================================================${COLOR_RESET}"
    echo -e "Total Tests  : ${TEST_COUNT_TOTAL}"
    echo -e "Passed       : ${COLOR_GREEN}${TEST_COUNT_PASS}${COLOR_RESET}"
    echo -e "Failed       : ${COLOR_RED}${TEST_COUNT_FAIL}${COLOR_RESET}"
    echo -e "Skipped      : ${COLOR_YELLOW}${TEST_COUNT_SKIP}${COLOR_RESET}"
    echo -e "${COLOR_BOLD}======================================================${COLOR_RESET}"

    if [[ -n "${JSON_REPORT_FILE}" ]] && [[ -f "${TEST_TMP_DIR}/results.jsonl" ]]; then
        python3 -c "
import json, sys
results = []
with open('${TEST_TMP_DIR}/results.jsonl') as f:
    for line in f:
        if line.strip():
            results.append(json.loads(line))
summary = {
    'total': ${TEST_COUNT_TOTAL},
    'passed': ${TEST_COUNT_PASS},
    'failed': ${TEST_COUNT_FAIL},
    'skipped': ${TEST_COUNT_SKIP},
    'results': results
}
with open('${JSON_REPORT_FILE}', 'w') as out:
    json.dump(summary, out, indent=2)
"
    fi

    if [[ "${TEST_COUNT_FAIL}" -gt 0 ]]; then
        return 1
    fi
    return 0
}
