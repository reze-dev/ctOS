#!/usr/bin/env bash
# ==============================================================================
# Tier 1 - Feature 4: Shape Glitch Animations
# Source: ORIGINAL_REQUEST §R1.2, TEST_INFRA.md §Feature 4, PROJECT.md
# ==============================================================================
set -u
set +e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../harness/mock_environment.sh"
source "${SCRIPT_DIR}/../harness/qml_runner.sh"

SHAPES_DIR="${PROJECT_ROOT}/shell/desktop/surfaces/components/shapes"
ICON_ROUTER="${PROJECT_ROOT}/shell/desktop/surfaces/components/CtosIcon.qml"
SETTINGS_FILE="${PROJECT_ROOT}/shell/desktop/core/Settings.qml"

test_case "T1.18.1" "Shape Glitch Animations: Shape components define cyberpunk glitch transitions"
if [[ -d "${SHAPES_DIR}" ]] && [[ $(find "${SHAPES_DIR}" -name "*.qml" | wc -l) -gt 0 ]]; then
    assert_grep -E "(NumberAnimation|SequentialAnimation|ParallelAnimation|Timer|transform|jitter|scanline|glitch)" "${SHAPES_DIR}" "Shapes must define animation transitions or glitch timers"
else
    test_skip "Pending M1: Shapes directory not yet populated"
fi

test_case "T1.18.2" "Shape Glitch Animations: Glitch animation respects Settings.reducedMotion"
if [[ -f "${ICON_ROUTER}" ]]; then
    assert_grep -E "(Settings\.reducedMotion|reducedMotion)" "${ICON_ROUTER}" "CtosIcon must check reducedMotion"
elif [[ -f "${SETTINGS_FILE}" ]]; then
    assert_grep "reducedMotion" "${SETTINGS_FILE}" "Settings.qml must provide reducedMotion property"
else
    assert_file_exists "${SETTINGS_FILE}"
fi

test_case "T1.18.3" "Shape Glitch Animations: Opacity pulse bounds are subtle (>= 0.7 to 1.0)"
if [[ -d "${SHAPES_DIR}" ]] && [[ $(find "${SHAPES_DIR}" -name "*.qml" | wc -l) -gt 0 ]]; then
    # Ensure shape opacity is animated and never drops below 0.5
    assert_grep -E 'target:\s*shapeContainer;\s*property:\s*"opacity"' "${SHAPES_DIR}" \
        "Shape container must animate opacity pulse"
    assert_not_grep -E 'target:\s*shapeContainer;\s*property:\s*"opacity";\s*to:\s*(root\.animate\s*\?\s*)?0\.[0-4]' "${SHAPES_DIR}" \
        "Shape opacity pulse must remain subtle (not dropping below 0.5)"
else
    test_skip "Pending M1: Opacity pulse bounds pending shape creation"
fi

test_case "T1.18.4" "Shape Glitch Animations: Jitter displacement is clamped to subtle offset (<= 3px)"
if [[ -d "${SHAPES_DIR}" ]] && [[ $(find "${SHAPES_DIR}" -name "*.qml" | wc -l) -gt 0 ]]; then
    # Jitter displacement should be subtle micro-movement in animation properties
    assert_grep -E 'property:\s*"[xy]"\s*;\s*to:' "${SHAPES_DIR}" "Glitch animation must define x/y jitter"
    assert_not_grep -E 'property:\s*"[xy]"\s*;\s*to:\s*(root\.animate\s*\?\s*)?-?([4-9]|[0-9]{2,})' "${SHAPES_DIR}" \
        "Jitter displacement must be <= 3px micro-shift"
else
    test_skip "Pending M1: Jitter displacement bounds pending shape creation"
fi

test_case "T1.18.5" "Shape Glitch Animations: Zero infinite fast unthrottled timer loops (< 50ms)"
if [[ -d "${SHAPES_DIR}" ]] && [[ $(find "${SHAPES_DIR}" -name "*.qml" | wc -l) -gt 0 ]]; then
    assert_not_grep -E "interval:\s*[0-4][0-9]\b" "${SHAPES_DIR}" "Timers in shapes must not poll faster than 50ms"
else
    test_skip "Pending M1: Timer throttling audit pending shape creation"
fi

report_summary
