#!/usr/bin/env bash
# ==============================================================================
# Tier 2 - Feature 7 Boundaries: System Rail Panel Geometry & Placement
# ==============================================================================
set -u
set +e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../harness/mock_environment.sh"
source "${SCRIPT_DIR}/../harness/qml_runner.sh"

SYSTEM_RAIL="${PROJECT_ROOT}/shell/desktop/surfaces/SystemRail.qml"
SHELL_QML="${PROJECT_ROOT}/shell/shell.qml"

test_case "T2.21.1" "System Rail Geometry: Fixed 360px width invariant across different display resolutions"
if [[ -f "${SYSTEM_RAIL}" ]]; then
    assert_grep -E '(width:\s*360|implicitWidth:\s*360)' "${SYSTEM_RAIL}" \
        "SystemRail must preserve fixed 360px width invariant"
else
    test_skip "Pending M2: SystemRail geometry invariant pending M2"
fi

test_case "T2.21.2" "System Rail Geometry: Right edge anchor in shell.qml"
assert_file_exists "${SHELL_QML}"
assert_grep -E "anchors\.right:\s*(parent\.)?right" "${SHELL_QML}" "Overlay panels must anchor to right"

test_case "T2.21.3" "System Rail Geometry: Top and bottom anchors fill vertical screen height"
assert_grep -E "anchors\.top:\s*(parent\.)?top" "${SHELL_QML}" "Overlay panels must anchor to top"
assert_grep -E "anchors\.bottom:\s*(parent\.)?bottom" "${SHELL_QML}" "Overlay panels must anchor to bottom"

test_case "T2.21.4" "System Rail Geometry: Internal MouseArea consumes clicks to prevent scrim dismissal"
if [[ -f "${SYSTEM_RAIL}" ]]; then
    assert_grep -E "(preventStealing|onClicked:\s*function|mouse\.accepted)" "${SYSTEM_RAIL}" \
        "Internal MouseArea must consume clicks to prevent dismissal by underlying scrim"
else
    test_skip "Pending M2: Internal MouseArea click trapping pending M2"
fi

test_case "T2.21.5" "System Rail Geometry: Overlay host uses WlrLayershell.layer WlrLayer.Overlay"
assert_grep "WlrLayer\.Overlay" "${SHELL_QML}" "Overlay host must be assigned to WlrLayer.Overlay"

report_summary
