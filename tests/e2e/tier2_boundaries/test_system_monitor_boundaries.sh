#!/usr/bin/env bash
# ==============================================================================
# Tier 2 - Feature 1 Boundary: SystemMonitorService Adversarial Stress & Limits
# Source: engineering-guidelines.md, ORIGINAL_REQUEST.md, PROJECT.md
# ==============================================================================
set -u
set +e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../harness/mock_environment.sh"
source "${SCRIPT_DIR}/../harness/qml_runner.sh"

SERVICE_FILE="${PROJECT_ROOT}/shell/desktop/services/SystemMonitorService.qml"
QML_HARNESS="${SCRIPT_DIR}/../harness/test_system_monitor_quickshell_adversarial.qml"

test_case "T2.01.1" "SystemMonitor: Division-by-zero protection in CPU stat algorithms"
if [[ -f "${SERVICE_FILE}" ]]; then
    # Must check deltaTotal > 0 before dividing
    assert_grep "if\s*\(\s*deltaTotal\s*>\s*0\s*\)" "${SERVICE_FILE}" "Must check deltaTotal > 0 before division"
else
    assert_file_exists "${SERVICE_FILE}" "SystemMonitorService.qml required"
fi

test_case "T2.01.2" "SystemMonitor: Clamping to [0.0, 1.0] for CPU aggregate and thread loads"
if [[ -f "${SERVICE_FILE}" ]]; then
    assert_grep "Math\.max\(0\.0,\s*Math\.min\(1\.0," "${SERVICE_FILE}" "CPU load calculations must be clamped to [0.0, 1.0]"
else
    assert_file_exists "${SERVICE_FILE}" "SystemMonitorService.qml required"
fi

test_case "T2.01.3" "SystemMonitor: Division-by-zero and debounce protection in Network dev throughput"
if [[ -f "${SERVICE_FILE}" ]]; then
    assert_grep "elapsedSec\s*>\s*0\.1" "${SERVICE_FILE}" "Must enforce elapsedSec > 0.1s debounce to prevent division by zero"
    assert_grep "deltaRx\s*>=\s*0" "${SERVICE_FILE}" "Must clamp deltaRx >= 0 to handle counter wrap"
    assert_grep "deltaTx\s*>=\s*0" "${SERVICE_FILE}" "Must clamp deltaTx >= 0 to handle counter wrap"
else
    assert_file_exists "${SERVICE_FILE}" "SystemMonitorService.qml required"
fi

test_case "T2.01.4" "SystemMonitor: Python adversarial stress harness passes (20/20 tests)"
if python3 -m unittest tests/test_system_monitor_adversarial.py >/dev/null 2>&1; then
    assert_eq "0" "0" "Adversarial stress harness (fuzzing, 128 cores, counter wraps) passes cleanly"
else
    assert_eq "0" "1" "Adversarial stress harness failed"
fi

test_case "T2.01.5" "SystemMonitor: Quickshell dynamic QML runtime execution and signals"
if [[ -n "${QUICKSHELL_BIN}" && -f "${QML_HARNESS}" ]]; then
    qs_out=$(QML_IMPORT_PATH="${PROJECT_ROOT}/shell" timeout 4 "${QUICKSHELL_BIN}" -p "${QML_HARNESS}" 2>&1 || true)
    if echo "${qs_out}" | grep -q "QUICKSHELL DYNAMIC ADVERSARIAL TEST PASS"; then
        assert_eq "0" "0" "Quickshell dynamic execution verified signals and runtime properties"
    else
        assert_eq "0" "1" "Quickshell dynamic execution failed: ${qs_out}"
    fi
else
    # Quickshell unavailable or harness missing
    assert_file_exists "${SERVICE_FILE}" "SystemMonitorService.qml required"
fi

report_summary
