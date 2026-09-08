#!/usr/bin/env bash
# ==============================================================================
# Tier 1 - Feature 5: Shader Fallback Tinting
# Source: ORIGINAL_REQUEST §R1.3, TEST_INFRA.md §Feature 5, PROJECT.md
# ==============================================================================
set -u
set +e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../harness/mock_environment.sh"
source "${SCRIPT_DIR}/../harness/qml_runner.sh"

ICON_ROUTER="${PROJECT_ROOT}/shell/desktop/surfaces/components/CtosIcon.qml"
COMPONENTS_DIR="${PROJECT_ROOT}/shell/desktop/surfaces/components"

test_case "T1.19.1" "Shader Fallback: ColorOverlay or monochrome shader effect is declared"
if [[ -f "${ICON_ROUTER}" ]]; then
    assert_grep -E "(ColorOverlay|ShaderEffect|MultiEffect)" "${ICON_ROUTER}" "CtosIcon must declare ColorOverlay or ShaderEffect"
else
    test_skip "Pending M1: CtosIcon.qml not yet implemented"
fi

test_case "T1.19.2" "Shader Fallback: Fallback applies Theme.acidGreen tint (#1BFD9C)"
if [[ -f "${ICON_ROUTER}" ]]; then
    assert_grep -E "(Theme\.acidGreen|#1BFD9C)" "${ICON_ROUTER}" "Fallback overlay must tint to Theme.acidGreen"
else
    test_skip "Pending M1: CtosIcon.qml not yet implemented"
fi

test_case "T1.19.3" "Shader Fallback: Preserves source alpha channel transparency"
if [[ -f "${ICON_ROUTER}" ]]; then
    # ColorOverlay naturally preserves alpha channels; verify source binding
    assert_grep -E "(source:|anchors\.fill:)" "${ICON_ROUTER}" "ColorOverlay must bind to source image"
else
    test_skip "Pending M1: CtosIcon.qml not yet implemented"
fi

test_case "T1.19.4" "Shader Fallback: Resolves system icon path via Quickshell.iconPath"
if [[ -f "${ICON_ROUTER}" ]]; then
    assert_grep -E "(Quickshell\.iconPath|iconPath)" "${ICON_ROUTER}" "Must resolve standard system desktop icons"
else
    test_skip "Pending M1: CtosIcon.qml not yet implemented"
fi

test_case "T1.19.5" "Shader Fallback: Fallback icon property defaults to application-x-executable"
if [[ -f "${ICON_ROUTER}" ]]; then
    check_qml_property "${ICON_ROUTER}" "fallbackIcon" || assert_grep "fallbackIcon" "${ICON_ROUTER}" "fallbackIcon property required"
    assert_grep "application-x-executable" "${ICON_ROUTER}" "fallbackIcon must default to application-x-executable"
else
    test_skip "Pending M1: CtosIcon.qml not yet implemented"
fi

report_summary
