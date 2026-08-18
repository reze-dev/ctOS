#!/usr/bin/env bash
# ==============================================================================
# Northstar E2E Test Suite Runner
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

show_help() {
  cat << EOF
${BOLD}Northstar E2E Test Suite Runner${NC}

${BOLD}USAGE:${NC}
  ./tests/e2e/run_tests.sh [OPTIONS]

${BOLD}OPTIONS:${NC}
  --all             Run all 4 test tiers (T1, T2, T3, T4) [Default]
  --tier <1|2|3|4>  Run a specific test tier only:
                      1: Tier 1 - Feature Coverage (60 tests)
                      2: Tier 2 - Boundary & Fault Injection (60 tests)
                      3: Tier 3 - Cross-Feature Interactions (6 tests)
                      4: Tier 4 - Real-World & Flake Eval (5 tests)
  --filter <REGEX>  Filter tests matching a specific regex pattern
  --verbose, -v     Show verbose test execution and individual test names
  --json <PATH>     Export test summary report to JSON file
  --help, -h        Display this help message and exit

${BOLD}EXAMPLES:${NC}
  ./tests/e2e/run_tests.sh
  ./tests/e2e/run_tests.sh --tier 1 -v
  ./tests/e2e/run_tests.sh --tier 4
  ./tests/e2e/run_tests.sh --filter "nvidia"
  ./tests/e2e/run_tests.sh --json /tmp/test-report.json

EOF
}

# Forward arguments to Python test suite runner
PASSED_ARGS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --help|-h)
      show_help
      exit 0
      ;;
    --tier)
      if [[ -z "${2:-}" ]] || [[ ! "$2" =~ ^[1-4]$ ]]; then
        echo -e "${RED}Error: --tier requires an argument of 1, 2, 3, or 4.${NC}" >&2
        exit 2
      fi
      PASSED_ARGS+=("--tier" "$2")
      shift 2
      ;;
    --all)
      PASSED_ARGS+=("--all")
      shift
      ;;
    --filter|-f)
      if [[ -z "${2:-}" ]]; then
        echo -e "${RED}Error: --filter requires a pattern argument.${NC}" >&2
        exit 2
      fi
      PASSED_ARGS+=("--filter" "$2")
      shift 2
      ;;
    --verbose|-v)
      PASSED_ARGS+=("--verbose")
      shift
      ;;
    --json)
      if [[ -z "${2:-}" ]]; then
        echo -e "${RED}Error: --json requires a file path argument.${NC}" >&2
        exit 2
      fi
      PASSED_ARGS+=("--json" "$2")
      shift 2
      ;;
    *)
      echo -e "${RED}Unknown argument: $1${NC}" >&2
      show_help
      exit 2
      ;;
  esac
done

export PYTHONPATH="${PROJECT_ROOT}:${PYTHONPATH:-}"

python3 "${SCRIPT_DIR}/test_suite.py" "${PASSED_ARGS[@]}"


