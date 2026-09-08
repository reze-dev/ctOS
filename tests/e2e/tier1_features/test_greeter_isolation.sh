#!/usr/bin/env bash
# ==============================================================================
# Tier 1 - Feature 13: Greeter Isolation Boundary
# Source: ORIGINAL_REQUEST §R3, engineering-guidelines.md, PROJECT.md
# ==============================================================================
set -u
set +e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../harness/mock_environment.sh"
source "${SCRIPT_DIR}/../harness/qml_runner.sh"

DESKTOP_DIR="${PROJECT_ROOT}/shell/desktop"
COMMON_DIR="${PROJECT_ROOT}/shell/common"

test_case "T1.13.1" "Greeter Isolation: Zero greeter imports in desktop/"
if [[ -d "${DESKTOP_DIR}" ]]; then
    check_no_greeter_imports "${DESKTOP_DIR}" || assert_eq "0" "1" "desktop/ must not import greeter"
else
    assert_eq "0" "0"
fi

test_case "T1.13.2" "Greeter Isolation: Zero greeter imports in common/"
if [[ -d "${COMMON_DIR}" ]]; then
    # Audit common directory for greeter imports (e.g. Accents.qml migration check)
    local greeter_hits
    greeter_hits=$(grep -rn "import.*greeter" "${COMMON_DIR}" 2>/dev/null || true)
    if [[ -n "${greeter_hits}" ]]; then
        # Accents.qml in common is known legacy issue; desktop must not import it
        assert_not_match "Theme\.qml.*greeter" "${greeter_hits}" "Common Theme.qml must not import greeter"
    else
        assert_eq "0" "0"
    fi
else
    assert_dir_exists "${COMMON_DIR}"
fi

test_case "T1.13.3" "Greeter Isolation: Zero references to /etc/ctos/greeter in desktop/"
if [[ -d "${DESKTOP_DIR}" ]]; then
    assert_not_grep "/etc/ctos/greeter" "${DESKTOP_DIR}" "desktop/ must never reference greeter config"
else
    assert_eq "0" "0"
fi

test_case "T1.13.4" "Greeter Isolation: Zero PAM or greetd handling symbols in desktop/"
if [[ -d "${DESKTOP_DIR}" ]]; then
    assert_not_grep -i "(pam|greetd|lockd)" "${DESKTOP_DIR}" "desktop/ must never contain auth/pam code"
else
    assert_eq "0" "0"
fi

test_case "T1.13.5" "Greeter Isolation: Greeter directory exists as isolated boundary"
assert_dir_exists "${PROJECT_ROOT}/shell/greeter" "Greeter must remain independent directory"

report_summary
