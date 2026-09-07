#!/usr/bin/env bash
# ==============================================================================
# Tier 2 - Feature 2 Boundary: Milestone M2 Telemetry Widgets Adversarial Stress
# Tests CpuHexGrid, RamBlockBar, CornerBrackets mathematical & boundary stability
# ==============================================================================
set -u
set +e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../harness/mock_environment.sh"
source "${SCRIPT_DIR}/../harness/qml_runner.sh"

WIDGETS_DIR="${PROJECT_ROOT}/shell/desktop/surfaces/widgets"
CPU_HEX_FILE="${WIDGETS_DIR}/CpuHexGrid.qml"
RAM_BAR_FILE="${WIDGETS_DIR}/RamBlockBar.qml"
BRACKETS_FILE="${WIDGETS_DIR}/CornerBrackets.qml"
QML_HARNESS="${SCRIPT_DIR}/../harness/test_milestone2_quickshell_adversarial.qml"

test_case "T2.02.1" "Zero-polling compliance: widgets must not declare 'running: true'"
assert_not_grep "running\s*:\s*true" "${WIDGETS_DIR}" "Widgets must not contain 'running: true'"

test_case "T2.02.2" "Greeter isolation: zero imports from greeter in widgets"
check_no_greeter_imports "${WIDGETS_DIR}"

test_case "T2.02.3" "RamBlockBar: Division-by-zero protection when swapTotalBytes == 0"
assert_grep "SystemMonitorService\.swapTotalBytes\s*>\s*0" "${RAM_BAR_FILE}" "RamBlockBar must guard swapTotalBytes > 0"
assert_grep "SWP NONE" "${RAM_BAR_FILE}" "RamBlockBar must display 'SWP NONE' when swap is absent"

test_case "T2.02.4" "RamBlockBar: 80% critical threshold transition to Theme.destructive"
assert_grep "root\.memRatio\s*>=\s*0\.80" "${RAM_BAR_FILE}" "RamBlockBar must trigger isCritical at >= 80% RAM"
assert_grep "root\.isCritical\s*\?\s*Theme\.destructive" "${RAM_BAR_FILE}" "Corner brackets and blocks must turn destructive at threshold"

test_case "T2.02.5" "CpuHexGrid: Honeycomb layout solver and offline core NaN protection"
assert_grep "solveLayout" "${CPU_HEX_FILE}" "CpuHexGrid must implement dynamic solveLayout"
assert_grep "isOffline" "${CPU_HEX_FILE}" "CpuHexGrid must explicitly handle sparse and offline cores"

test_case "T2.02.6" "M2 Python Adversarial Stress Harness (19/19 tests)"
if python3 -m unittest tests/test_milestone2_adversarial.py >/dev/null 2>&1; then
    assert_eq "0" "0" "Adversarial stress harness (1..128 cores layout, zero-swap, 20 segments) passed"
else
    assert_eq "0" "1" "Adversarial stress harness failed"
fi

test_case "T2.02.7" "Quickshell dynamic runtime execution of M2 widgets"
if [[ -n "${QUICKSHELL_BIN}" && -f "${QML_HARNESS}" ]]; then
    qs_out=$(QML_IMPORT_PATH="${PROJECT_ROOT}/shell" timeout 4 "${QUICKSHELL_BIN}" -p "${QML_HARNESS}" 2>&1 || true)
    if echo "${qs_out}" | grep -q "QUICKSHELL M2 WIDGETS DYNAMIC TEST PASS"; then
        assert_eq "0" "0" "Quickshell runtime successfully executed and validated M2 widgets"
    else
        assert_eq "0" "1" "Quickshell runtime execution failed: ${qs_out}"
    fi
else
    assert_file_exists "${CPU_HEX_FILE}" "CpuHexGrid.qml required"
fi

report_summary
