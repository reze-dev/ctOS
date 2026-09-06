#!/usr/bin/env bash
# ==============================================================================
# ctOS Desktop Shell Foundation & Ambient Bar - E2E Test Suite Runner
# Strictly adheres to TEST_INFRA.md specification
# ==============================================================================
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# ANSI formatting
COLOR_RESET="\033[0m"
COLOR_BOLD="\033[1m"
COLOR_GREEN="\033[0;32m"
COLOR_RED="\033[0;31m"
COLOR_YELLOW="\033[0;33m"
COLOR_CYAN="\033[0;36m"
COLOR_BLUE="\033[0;34m"
COLOR_GRAY="\033[0;90m"

show_help() {
    echo -e "${COLOR_BOLD}ctOS Desktop Shell Foundation & Ambient Bar E2E Test Suite Runner${COLOR_RESET}

${COLOR_BOLD}USAGE:${COLOR_RESET}
  ./tests/e2e/run_tests.sh [OPTIONS]

${COLOR_BOLD}OPTIONS:${COLOR_RESET}
  --all                 Run all 4 test tiers (default)
  --tier <1|2|3|4|all>  Run a specific test tier only:
                          1: Tier 1 - Feature Coverage (≥70 tests across 14 features)
                          2: Tier 2 - Boundary & Corner Cases (≥70 tests across 14 features)
                          3: Tier 3 - Cross-Feature Combinations (≥14 pairwise tests)
                          4: Tier 4 - Real-World Scenarios (≥7 workload scenarios)
  --filter <REGEX>      Filter tests matching a specific pattern or test ID
  --verbose, -v         Show detailed assertion steps and verbose diagnostics
  --json <PATH>         Export complete test report to JSON file
  --help, -h            Display this help message and exit

${COLOR_BOLD}EXAMPLES:${COLOR_RESET}
  ./tests/e2e/run_tests.sh
  ./tests/e2e/run_tests.sh --tier 1
  ./tests/e2e/run_tests.sh --tier 2 -v
  ./tests/e2e/run_tests.sh --filter \"T1.14\"
  ./tests/e2e/run_tests.sh --json /tmp/test-report.json"
}

TARGET_TIER="all"
FILTER_PATTERN=""
VERBOSE_FLAG=0
JSON_OUTPUT=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --help|-h)
            show_help
            exit 0
            ;;
        --all)
            TARGET_TIER="all"
            shift
            ;;
        --tier)
            if [[ -z "${2:-}" ]] || [[ ! "$2" =~ ^(1|2|3|4|all)$ ]]; then
                echo -e "${COLOR_RED}Error: --tier requires an argument of 1, 2, 3, 4, or all.${COLOR_RESET}" >&2
                exit 2
            fi
            TARGET_TIER="$2"
            shift 2
            ;;
        --filter|-f)
            if [[ -z "${2:-}" ]]; then
                echo -e "${COLOR_RED}Error: --filter requires a pattern argument.${COLOR_RESET}" >&2
                exit 2
            fi
            FILTER_PATTERN="$2"
            shift 2
            ;;
        --verbose|-v)
            VERBOSE_FLAG=1
            shift
            ;;
        --json)
            if [[ -z "${2:-}" ]]; then
                echo -e "${COLOR_RED}Error: --json requires a target file path.${COLOR_RESET}" >&2
                exit 2
            fi
            JSON_OUTPUT="$2"
            shift 2
            ;;
        *)
            echo -e "${COLOR_RED}Error: Unknown argument: $1${COLOR_RESET}" >&2
            show_help
            exit 2
            ;;
    esac
done

export PROJECT_ROOT
export VERBOSE="${VERBOSE_FLAG}"

# Temporary accumulator for test results
GLOBAL_RESULTS_TMP=$(mktemp "/tmp/ctos-test-suite-XXXXXX.log")
trap 'rm -f "${GLOBAL_RESULTS_TMP}"' EXIT INT TERM

TOTAL_COUNT=0
PASS_COUNT=0
FAIL_COUNT=0
SKIP_COUNT=0

TIER1_TOTAL=0; TIER1_PASS=0; TIER1_FAIL=0
TIER2_TOTAL=0; TIER2_PASS=0; TIER2_FAIL=0
TIER3_TOTAL=0; TIER3_PASS=0; TIER3_FAIL=0
TIER4_TOTAL=0; TIER4_PASS=0; TIER4_FAIL=0

run_tier_script() {
    local tier_num="$1"
    local script_path="$2"
    local script_name
    script_name=$(basename "${script_path}")

    # Execute script and stream output
    local script_out
    script_out=$(bash "${script_path}" 2>&1)
    local exit_code=$?

    local last_matched=1
    # Parse lines from output
    while IFS= read -r line; do
        local clean_line
        clean_line=$(printf '%s' "${line}" | sed -E $'s/\x1b\\[[0-9;]*m//g')
        if [[ "${clean_line}" =~ ^\[(PASS|FAIL|SKIP)\]\ ([^:]+):\ (.*)$ ]]; then
            local status="${BASH_REMATCH[1]}"
            local test_id="${BASH_REMATCH[2]}"
            local test_desc="${BASH_REMATCH[3]}"

            # Apply filter pattern if specified
            if [[ -n "${FILTER_PATTERN}" ]]; then
                if ! [[ "${test_id}" =~ ${FILTER_PATTERN} ]] && ! [[ "${test_desc}" =~ ${FILTER_PATTERN} ]]; then
                    last_matched=0
                    continue
                fi
            fi
            last_matched=1

            TOTAL_COUNT=$((TOTAL_COUNT + 1))
            case "${status}" in
                PASS)
                    PASS_COUNT=$((PASS_COUNT + 1))
                    case "${tier_num}" in
                        1) TIER1_PASS=$((TIER1_PASS + 1)); TIER1_TOTAL=$((TIER1_TOTAL + 1)) ;;
                        2) TIER2_PASS=$((TIER2_PASS + 1)); TIER2_TOTAL=$((TIER2_TOTAL + 1)) ;;
                        3) TIER3_PASS=$((TIER3_PASS + 1)); TIER3_TOTAL=$((TIER3_TOTAL + 1)) ;;
                        4) TIER4_PASS=$((TIER4_PASS + 1)); TIER4_TOTAL=$((TIER4_TOTAL + 1)) ;;
                    esac
                    echo -e "${COLOR_GREEN}[PASS]${COLOR_RESET} ${test_id}: ${test_desc}"
                    echo "PASS|${test_id}|${test_desc}|" >> "${GLOBAL_RESULTS_TMP}"
                    ;;
                FAIL)
                    FAIL_COUNT=$((FAIL_COUNT + 1))
                    case "${tier_num}" in
                        1) TIER1_FAIL=$((TIER1_FAIL + 1)); TIER1_TOTAL=$((TIER1_TOTAL + 1)) ;;
                        2) TIER2_FAIL=$((TIER2_FAIL + 1)); TIER2_TOTAL=$((TIER2_TOTAL + 1)) ;;
                        3) TIER3_FAIL=$((TIER3_FAIL + 1)); TIER3_TOTAL=$((TIER3_TOTAL + 1)) ;;
                        4) TIER4_FAIL=$((TIER4_FAIL + 1)); TIER4_TOTAL=$((TIER4_TOTAL + 1)) ;;
                    esac
                    echo -e "${COLOR_RED}[FAIL]${COLOR_RESET} ${test_id}: ${test_desc}"
                    echo "FAIL|${test_id}|${test_desc}|" >> "${GLOBAL_RESULTS_TMP}"
                    ;;
                SKIP)
                    SKIP_COUNT=$((SKIP_COUNT + 1))
                    echo -e "${COLOR_YELLOW}[SKIP]${COLOR_RESET} ${test_id}: ${test_desc}"
                    echo "SKIP|${test_id}|${test_desc}|" >> "${GLOBAL_RESULTS_TMP}"
                    ;;
            esac
        elif [[ "${clean_line}" =~ ^[[:space:]]+Reason:\ (.*)$ ]]; then
            if [[ "${last_matched}" -eq 1 ]]; then
                local reason="${BASH_REMATCH[1]}"
                echo -e "       ${COLOR_RED}Reason: ${reason}${COLOR_RESET}"
            fi
        elif [[ "${VERBOSE_FLAG}" -eq 1 ]]; then
            # In verbose mode, echo other lines
            if [[ -n "${line}" && ! "${line}" =~ ^={10,} && ! "${line}" =~ ^Test\ Execution ]]; then
                echo -e "  ${COLOR_GRAY}${line}${COLOR_RESET}"
            fi
        fi
    done <<< "${script_out}"
}

echo -e "${COLOR_BOLD}======================================================================${COLOR_RESET}"
echo -e "${COLOR_BOLD}ctOS E2E Test Suite: Shell Foundation & Ambient Bar${COLOR_RESET}"
echo -e "${COLOR_BOLD}Target Tier: ${TARGET_TIER}${COLOR_RESET}"
if [[ -n "${FILTER_PATTERN}" ]]; then
    echo -e "${COLOR_BOLD}Filter: ${FILTER_PATTERN}${COLOR_RESET}"
fi
echo -e "${COLOR_BOLD}======================================================================${COLOR_RESET}"

# Execute selected tiers
if [[ "${TARGET_TIER}" == "1" || "${TARGET_TIER}" == "all" ]]; then
    echo -e "\n${COLOR_CYAN}${COLOR_BOLD}>>> Running Tier 1: Feature Coverage (≥70 tests)${COLOR_RESET}"
    for script in $(find "${SCRIPT_DIR}/tier1_features" -name "*.sh" | sort); do
        run_tier_script 1 "${script}"
    done
fi

if [[ "${TARGET_TIER}" == "2" || "${TARGET_TIER}" == "all" ]]; then
    echo -e "\n${COLOR_CYAN}${COLOR_BOLD}>>> Running Tier 2: Boundary & Corner Cases (≥70 tests)${COLOR_RESET}"
    for script in $(find "${SCRIPT_DIR}/tier2_boundaries" -name "*.sh" | sort); do
        run_tier_script 2 "${script}"
    done
fi

if [[ "${TARGET_TIER}" == "3" || "${TARGET_TIER}" == "all" ]]; then
    echo -e "\n${COLOR_CYAN}${COLOR_BOLD}>>> Running Tier 3: Cross-Feature Pairwise (≥14 tests)${COLOR_RESET}"
    for script in $(find "${SCRIPT_DIR}/tier3_pairwise" -name "*.sh" | sort); do
        run_tier_script 3 "${script}"
    done
fi

if [[ "${TARGET_TIER}" == "4" || "${TARGET_TIER}" == "all" ]]; then
    echo -e "\n${COLOR_CYAN}${COLOR_BOLD}>>> Running Tier 4: Real-World Scenarios (≥7 tests)${COLOR_RESET}"
    for script in $(find "${SCRIPT_DIR}/tier4_real_world" -name "*.sh" | sort); do
        run_tier_script 4 "${script}"
    done
fi

# Print Aggregated Summary Table
echo -e "\n${COLOR_BOLD}======================================================================${COLOR_RESET}"
echo -e "${COLOR_BOLD}ctOS E2E Test Suite Results Summary${COLOR_RESET}"
echo -e "${COLOR_BOLD}======================================================================${COLOR_RESET}"
printf "%-30s | %8s | %8s | %8s | %8s\n" "Tier" "Total" "Passed" "Failed" "Skipped"
echo "----------------------------------------------------------------------"
if [[ "${TARGET_TIER}" == "1" || "${TARGET_TIER}" == "all" ]]; then
    printf "%-30s | %8d | %8d | %8d | %8d\n" "Tier 1 (Feature Coverage)" "${TIER1_TOTAL}" "${TIER1_PASS}" "${TIER1_FAIL}" 0
fi
if [[ "${TARGET_TIER}" == "2" || "${TARGET_TIER}" == "all" ]]; then
    printf "%-30s | %8d | %8d | %8d | %8d\n" "Tier 2 (Boundaries & Edge)" "${TIER2_TOTAL}" "${TIER2_PASS}" "${TIER2_FAIL}" 0
fi
if [[ "${TARGET_TIER}" == "3" || "${TARGET_TIER}" == "all" ]]; then
    printf "%-30s | %8d | %8d | %8d | %8d\n" "Tier 3 (Pairwise Interactions)" "${TIER3_TOTAL}" "${TIER3_PASS}" "${TIER3_FAIL}" 0
fi
if [[ "${TARGET_TIER}" == "4" || "${TARGET_TIER}" == "all" ]]; then
    printf "%-30s | %8d | %8d | %8d | %8d\n" "Tier 4 (Real-World Scenarios)" "${TIER4_TOTAL}" "${TIER4_PASS}" "${TIER4_FAIL}" 0
fi
echo "----------------------------------------------------------------------"
printf "%-30s | %8d | %8d | %8d | %8d\n" "TOTAL" "${TOTAL_COUNT}" "${PASS_COUNT}" "${FAIL_COUNT}" "${SKIP_COUNT}"
echo -e "${COLOR_BOLD}======================================================================${COLOR_RESET}"

# Export JSON if requested
if [[ -n "${JSON_OUTPUT}" ]]; then
    python3 -c "
import json, sys
results = []
try:
    with open('${GLOBAL_RESULTS_TMP}') as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            parts = line.split('|')
            if len(parts) >= 3:
                results.append({
                    'status': parts[0],
                    'id': parts[1],
                    'description': parts[2]
                })
except Exception:
    pass

report = {
    'total': ${TOTAL_COUNT},
    'passed': ${PASS_COUNT},
    'failed': ${FAIL_COUNT},
    'skipped': ${SKIP_COUNT},
    'tier1': {'total': ${TIER1_TOTAL}, 'passed': ${TIER1_PASS}, 'failed': ${TIER1_FAIL}},
    'tier2': {'total': ${TIER2_TOTAL}, 'passed': ${TIER2_PASS}, 'failed': ${TIER2_FAIL}},
    'tier3': {'total': ${TIER3_TOTAL}, 'passed': ${TIER3_PASS}, 'failed': ${TIER3_FAIL}},
    'tier4': {'total': ${TIER4_TOTAL}, 'passed': ${TIER4_PASS}, 'failed': ${TIER4_FAIL}},
    'results': results
}
with open('${JSON_OUTPUT}', 'w') as f:
    json.dump(report, f, indent=2)
"
    echo -e "Exported test report to ${COLOR_CYAN}${JSON_OUTPUT}${COLOR_RESET}"
fi

if [[ "${FAIL_COUNT}" -gt 0 ]]; then
    echo -e "\n${COLOR_RED}${COLOR_BOLD}FAILED: ${FAIL_COUNT} test(s) failed out of ${TOTAL_COUNT}.${COLOR_RESET}"
    exit 1
else
    echo -e "\n${COLOR_GREEN}${COLOR_BOLD}SUCCESS: All ${TOTAL_COUNT} test(s) passed!${COLOR_RESET}"
    exit 0
fi
