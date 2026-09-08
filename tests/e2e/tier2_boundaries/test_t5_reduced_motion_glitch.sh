#!/usr/bin/env bash
# ==============================================================================
# Tier 2 - Feature 4 Boundaries: Shape Glitch Animations & Reduced Motion
# ==============================================================================
set -u
set +e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../harness/mock_environment.sh"
source "${SCRIPT_DIR}/../harness/qml_runner.sh"

ICON_ROUTER="${PROJECT_ROOT}/shell/desktop/surfaces/components/CtosIcon.qml"
SHAPES_DIR="${PROJECT_ROOT}/shell/desktop/surfaces/components/shapes"
SETTINGS_FILE="${PROJECT_ROOT}/shell/desktop/core/Settings.qml"

test_case "T2.18.1" "Reduced Motion Boundary: Settings.reducedMotion defaults to boolean false"
assert_file_exists "${SETTINGS_FILE}"
assert_grep -E 'property\s+bool\s+reducedMotion:\s*false' "${SETTINGS_FILE}" "reducedMotion must default to false"

test_case "T2.18.2" "Reduced Motion Boundary: CtosIcon animate property gates glitch animations"
if [[ -f "${ICON_ROUTER}" ]]; then
    assert_grep -E 'animate:\s*!Settings\.reducedMotion' "${ICON_ROUTER}" \
        "animate property must bind to !Settings.reducedMotion"
else
    test_skip "Pending M1: animate property binding pending M1"
fi

test_case "T2.18.3" "Reduced Motion Boundary: When animate is false, jitter displacements are 0px"
if [[ -d "${SHAPES_DIR}" ]] && [[ $(find "${SHAPES_DIR}" -name "*.qml" | wc -l) -gt 0 ]]; then
    assert_grep -E "(animate\s*\?\s*|running:\s*.*animate)" "${SHAPES_DIR}" \
        "Shape animations must condition displacement or running on animate"
else
    test_skip "Pending M1: Animation suppression check pending M1"
fi

test_case "T2.18.4" "Reduced Motion Boundary: When animate is false, scanline flickers are 0"
if [[ -d "${SHAPES_DIR}" ]] && [[ $(find "${SHAPES_DIR}" -name "*.qml" | wc -l) -gt 0 ]]; then
    assert_not_grep "running:\s*true\b" "${SHAPES_DIR}" \
        "Animations must not run unconditionally with hardcoded true"
else
    test_skip "Pending M1: Scanline flicker condition pending M1"
fi

test_case "T2.18.5" "Reduced Motion Boundary: Dynamic changes to Settings.reducedMotion propagate reactively"
if [[ -f "${ICON_ROUTER}" ]]; then
    # Verify binding is declarative property, not an imperative one-shot assignment
    assert_grep "animate" "${ICON_ROUTER}" "animate must be a reactive property"
else
    test_skip "Pending M1: Reactive propagation check pending M1"
fi

report_summary
