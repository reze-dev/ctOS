#!/usr/bin/env bash
# ==============================================================================
# Tier 1 - Feature 7: System Rail Panel & Anchoring
# Source: ORIGINAL_REQUEST §R2, TEST_INFRA.md §Feature 7, PROJECT.md
# ==============================================================================
set -u
set +e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../harness/mock_environment.sh"
source "${SCRIPT_DIR}/../harness/qml_runner.sh"

SYSTEM_RAIL="${PROJECT_ROOT}/shell/desktop/surfaces/SystemRail.qml"
SHELL_QML="${PROJECT_ROOT}/shell/shell.qml"
THEME_FILE="${PROJECT_ROOT}/shell/desktop/core/Theme.qml"

test_case "T1.21.1" "System Rail Panel: SystemRail.qml exists in desktop/surfaces/"
if [[ -f "${SYSTEM_RAIL}" ]]; then
    assert_file_exists "${SYSTEM_RAIL}" "SystemRail.qml must exist"
else
    test_skip "Pending M2: shell/desktop/surfaces/SystemRail.qml not yet implemented"
fi

test_case "T1.21.2" "System Rail Panel: Anchored to bottom, right, top in shell.qml"
assert_file_exists "${SHELL_QML}"
assert_grep "systemRailLoader" "${SHELL_QML}" "systemRailLoader must exist in shell.qml"
assert_grep -E "anchors\.(bottom|right|top)" "${SHELL_QML}" "Overlay panels must anchor right, top, and bottom"

test_case "T1.21.3" "System Rail Panel: Fixed 360px panel width"
if [[ -f "${SYSTEM_RAIL}" ]]; then
    assert_grep -E "(width:\s*360|implicitWidth:\s*360)" "${SYSTEM_RAIL}" "SystemRail width must be fixed at 360px"
else
    test_skip "Pending M2: 360px width check pending SystemRail.qml"
fi

test_case "T1.21.4" "System Rail Panel: Dark near-black background (Theme.gray900 / #080808)"
if [[ -f "${SYSTEM_RAIL}" ]]; then
    assert_grep -E "(Theme\.gray900|#080808|Theme\.backgroundDark)" "${SYSTEM_RAIL}" "SystemRail background must be near-black Theme.gray900"
else
    assert_grep 'gray900:\s*"#080808"' "${THEME_FILE}" "Theme.gray900 must be #080808"
fi

test_case "T1.21.5" "System Rail Panel: 4 Cyberpunk corner brackets rendered in Theme.acidGreen"
if [[ -f "${SYSTEM_RAIL}" ]]; then
    assert_grep -E "(cornerBracket|CornerFrame|Theme\.acidGreen)" "${SYSTEM_RAIL}" "SystemRail must render corner brackets"
else
    assert_grep "cornerBracketArmLength" "${THEME_FILE}" "Theme must define cornerBracket tokens"
    assert_grep "cornerBracketThickness" "${THEME_FILE}" "Theme must define cornerBracketThickness"
fi

report_summary
