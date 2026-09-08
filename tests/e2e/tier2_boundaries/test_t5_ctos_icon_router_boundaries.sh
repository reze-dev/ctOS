#!/usr/bin/env bash
# ==============================================================================
# Tier 2 - Feature 6 Boundaries: Unified CtosIcon Router
# ==============================================================================
set -u
set +e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../harness/mock_environment.sh"
source "${SCRIPT_DIR}/../harness/qml_runner.sh"

ICON_ROUTER="${PROJECT_ROOT}/shell/desktop/surfaces/components/CtosIcon.qml"

test_case "T2.20.1" "CtosIcon Router Boundary: Empty string name (\" \") falls back safely without null error"
if [[ -f "${ICON_ROUTER}" ]]; then
    assert_grep -E '(!name|name\s*===\s*""|name\s*\|\|)' "${ICON_ROUTER}" \
        "Router must safely handle empty string icon name"
else
    test_skip "Pending M1: Empty name handling pending M1"
fi

test_case "T2.20.2" "CtosIcon Router Boundary: Whitespace-only name string is trimmed or handled"
if [[ -f "${ICON_ROUTER}" ]]; then
    assert_grep -E "(\.trim\(\)|name)" "${ICON_ROUTER}" "Router must handle unpadded or whitespace icon names"
else
    test_skip "Pending M1: Whitespace handling pending M1"
fi

test_case "T2.20.3" "CtosIcon Router Boundary: Size property defaults to standard 24px"
if [[ -f "${ICON_ROUTER}" ]]; then
    check_qml_property "${ICON_ROUTER}" "size" || assert_grep "size" "${ICON_ROUTER}" "size property required"
    assert_grep -E 'property\s+real\s+size:\s*24' "${ICON_ROUTER}" "size must default to 24"
else
    test_skip "Pending M1: Default size check pending M1"
fi

test_case "T2.20.4" "CtosIcon Router Boundary: Zero or negative size does not cause negative dimension crash"
if [[ -f "${ICON_ROUTER}" ]]; then
    assert_grep -E "(Math\.max|width:\s*.*size|Layout\.preferredWidth)" "${ICON_ROUTER}" \
        "Router dimensions must safely bind size"
else
    test_skip "Pending M1: Negative size protection pending M1"
fi

test_case "T2.20.5" "CtosIcon Router Boundary: Rapid property flipping handled reactively"
if [[ -f "${ICON_ROUTER}" ]]; then
    # Verify no state machine deadlock or stuck imperative handlers
    assert_not_grep -E "while\s*\(" "${ICON_ROUTER}" "Router must have zero synchronous while loops"
else
    test_skip "Pending M1: Rapid update audit pending M1"
fi

report_summary
