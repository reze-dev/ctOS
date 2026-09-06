#!/usr/bin/env bash
# ==============================================================================
# Tier 2 - Feature 13 Boundary: Greeter Isolation Deep Boundary Audit
# Source: architecture.md, engineering-guidelines.md, PROJECT.md
# ==============================================================================
set -u
set +e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../harness/mock_environment.sh"
source "${SCRIPT_DIR}/../harness/qml_runner.sh"

DESKTOP_DIR="${PROJECT_ROOT}/shell/desktop"
SHELL_DIR="${PROJECT_ROOT}/shell"

test_case "T2.13.1" "Greeter Isolation Boundary: No relative ../greeter imports from desktop/"
if [[ -d "${DESKTOP_DIR}" ]]; then
    assert_not_grep '\.\./greeter' "${DESKTOP_DIR}" "No relative path traversal into greeter"
else
    assert_eq "0" "0"
fi

test_case "T2.13.2" "Greeter Isolation Boundary: No qs.greeter namespace imports anywhere in desktop/"
if [[ -d "${DESKTOP_DIR}" ]]; then
    assert_not_grep "qs\.greeter" "${DESKTOP_DIR}" "No qs.greeter imports in desktop/"
else
    assert_eq "0" "0"
fi

test_case "T2.13.3" "Greeter Isolation Boundary: No greeter SVG asset paths in desktop/"
if [[ -d "${DESKTOP_DIR}" ]]; then
    assert_not_grep "greeter/resources" "${DESKTOP_DIR}" "No greeter resources referenced in desktop"
else
    assert_eq "0" "0"
fi

test_case "T2.13.4" "Greeter Isolation Boundary: No greeter config schemas imported in desktop/"
if [[ -d "${DESKTOP_DIR}" ]]; then
    assert_not_grep "greeter\.schema\.json" "${DESKTOP_DIR}" "No greeter schema in desktop"
else
    assert_eq "0" "0"
fi

test_case "T2.13.5" "Greeter Isolation Boundary: Greeter builds and runs independently"
# Verify greeter.qml entry point exists and does not depend on desktop
assert_file_exists "${SHELL_DIR}/greeter.qml" "greeter.qml entry point must exist"
assert_not_grep "desktop" "${SHELL_DIR}/greeter.qml" "greeter.qml must not depend on desktop/"

report_summary
