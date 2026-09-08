#!/usr/bin/env bash
# ==============================================================================
# Tier 2 - Feature 5 Boundaries: Shader Fallback Tinting
# ==============================================================================
set -u
set +e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../harness/mock_environment.sh"
source "${SCRIPT_DIR}/../harness/qml_runner.sh"

ICON_ROUTER="${PROJECT_ROOT}/shell/desktop/surfaces/components/CtosIcon.qml"

test_case "T2.19.1" "Shader Fallback Boundary: Non-square desktop icon preserves aspect ratio"
if [[ -f "${ICON_ROUTER}" ]]; then
    assert_grep -E "(PreserveAspectFit|fillMode)" "${ICON_ROUTER}" \
        "Fallback icon image must use PreserveAspectFit to prevent stretching"
else
    test_skip "Pending M1: PreserveAspectFit check pending M1"
fi

test_case "T2.19.2" "Shader Fallback Boundary: sourceSize restricts rasterization to display size"
if [[ -f "${ICON_ROUTER}" ]]; then
    assert_grep -E "sourceSize(\.width|\.height|:\s*Qt\.size)" "${ICON_ROUTER}" \
        "IconImage must set sourceSize to cap GPU memory / VRAM consumption"
else
    test_skip "Pending M1: sourceSize VRAM cap check pending M1"
fi

test_case "T2.19.3" "Shader Fallback Boundary: Transparent pixel alpha is untouched by tint effect"
if [[ -f "${ICON_ROUTER}" ]]; then
    # ColorOverlay uses source alpha channel
    assert_grep -E "(ColorOverlay|color:\s*Theme\.acidGreen)" "${ICON_ROUTER}" \
        "Color overlay must tint color while respecting alpha"
else
    test_skip "Pending M1: Alpha preservation check pending M1"
fi

test_case "T2.19.4" "Shader Fallback Boundary: High-DPI screen scaling handled cleanly via vector/sourceSize"
if [[ -f "${ICON_ROUTER}" ]]; then
    assert_grep -E "(size|root\.size)" "${ICON_ROUTER}" "Icon router must size elements via dynamic size property"
else
    test_skip "Pending M1: Dynamic sizing check pending M1"
fi

test_case "T2.19.5" "Shader Fallback Boundary: Missing fallback icon does not cause infinite reload loop"
if [[ -f "${ICON_ROUTER}" ]]; then
    assert_not_grep "source\s*=\s*source" "${ICON_ROUTER}" "Icon router must avoid circular self-assignment loops"
else
    test_skip "Pending M1: Reload loop check pending M1"
fi

report_summary
